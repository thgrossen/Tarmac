/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

extension ContinuousClock.Instant
{
    /**
     * How long ago this instant was, for timing a network call.
     *
     * @return Seconds elapsed since this instant.
     */
    func elapsedSeconds() -> TimeInterval
    {
        let elapsed = ContinuousClock.now - self
        let ( seconds, attoseconds ) = elapsed.components

        return TimeInterval( seconds ) + TimeInterval( attoseconds ) / 1e18
    }
}

enum IgnavError: LocalizedError
{
    case badStatus( Int, String )
    case api( status: Int, code: String, message: String )

    var errorDescription: String?
    {
        switch self
        {
            case .badStatus( let code, let body ): return "HTTP \( code )\n\( body )"
            case .api( _, _, let message ): return message
        }
    }

    /**
     * Machine-readable error code from the API's error envelope, e.g. "ignav_id_not_found".
     *
     * @return The code, or nil when the failure didn't carry a structured envelope.
     */
    var apiCode: String?
    {
        switch self
        {
            case .badStatus: return nil
            case .api( _, let code, _ ): return code
        }
    }
}

/**
 * The error envelope every Ignav failure returns, e.g.
 * `{ "error": { "type": "not_found", "code": "ignav_id_not_found", "message": "…" } }`.
 */
struct IgnavErrorEnvelope: Decodable
{
    struct Payload: Decodable
    {
        let type: String?
        let code: String
        let message: String
        let field: String?
    }

    let error: Payload
}

struct IgnavClient
{
    /// Root every fares endpoint hangs off.
    static let baseURL = URL( string: "https://ignav.com/api/fares" )!

    var apiKey: String

    /// Returns (decoded result, pretty-printed raw JSON)
    func roundTrip( _ body: RoundTripRequest ) async throws -> ( FaresResponse, String )
    {
        try await self.post( body, to: "round-trip" )
    }

    /// Returns (decoded result, pretty-printed raw JSON)
    func oneWay( _ body: OneWayRequest ) async throws -> ( FaresResponse, String )
    {
        try await self.post( body, to: "one-way" )
    }

    /// Returns (decoded result, pretty-printed raw JSON)
    func bookingLinks( _ body: BookingLinksRequest ) async throws -> ( BookingLinksResponse, String )
    {
        try await self.post( body, to: "booking-links" )
    }

    private func post< Body: Encodable, Response: Decodable >( _ body: Body, to path: String ) async throws -> ( Response, String )
    {
        let req       = try Self.makeRequest( apiKey: self.apiKey, body: body, path: path )
        let startedAt = Date()
        let started   = ContinuousClock.now

        // Every exit from here on is recorded, so the inspector sees the failures the search code
        // discards as well as the responses it keeps.
        func record( _ data: Data?, _ outcome: APITransaction.Outcome )
        {
            APIRecording.record(
                Self.transaction(
                    request:   req,
                    endpoint:  path,
                    startedAt: startedAt,
                    duration:  started.elapsedSeconds(),
                    data:      data,
                    outcome:   outcome
                )
            )
        }

        let data: Data
        let response: URLResponse

        do
        {
            ( data, response ) = try await URLSession.shared.data( for: req )
        }
        catch
        {
            record( nil, .transportError( message: error.localizedDescription ) )
            throw error
        }

        let raw    = Self.pretty( data )
        let status = ( response as? HTTPURLResponse )?.statusCode ?? 0

        if Self.isSuccess( status: status ) == false
        {
            record( data, .httpError( status: status ) )
            throw Self.error( status: status, data: data, raw: raw )
        }

        do
        {
            let decoded = try JSONDecoder().decode( Response.self, from: data )
            record( data, .ok( status: status ) )
            return ( decoded, raw )
        }
        catch
        {
            record( data, .decodeError( status: status, message: "\( error )" ) )
            throw error
        }
    }

    /**
     * Captures one call for the API inspector, redacting the API key and pretty-printing both
     * bodies. Attributed to whatever run `APICallContext` names, when the call was made inside one.
     *
     * @param request Request that was sent.
     * @param endpoint Endpoint path it was sent to.
     * @param startedAt When the call was made.
     * @param duration How long it took, in seconds.
     * @param data Response body, or nil when no response came back.
     * @param outcome How the call ended.
     * @return The transaction to record.
     */
    static func transaction(
        request: URLRequest,
        endpoint: String,
        startedAt: Date,
        duration: TimeInterval,
        data: Data?,
        outcome: APITransaction.Outcome
    ) -> APITransaction
    {
        var headers = request.allHTTPHeaderFields ?? [:]
        for name in headers.keys where name.lowercased() == "x-api-key"
        {
            headers[ name ] = APITransaction.redactedValue
        }

        return APITransaction(
            startedAt:         startedAt,
            duration:          duration,
            endpoint:          endpoint,
            url:               request.url ?? Self.baseURL,
            method:            request.httpMethod ?? "POST",
            headers:           headers,
            requestBody:       request.httpBody.map { Self.pretty( $0 ) } ?? "",
            responseBody:      data.map { Self.pretty( $0 ) },
            responseByteCount: data?.count ?? 0,
            outcome:           outcome,
            runID:             APICallContext.current.runID
        )
    }

    /**
     * Turns a failed response into the most specific error its body supports: a typed `.api`
     * failure when the body is the documented error envelope, and the raw status/body otherwise.
     *
     * @param status HTTP status code of the response.
     * @param data Raw response body.
     * @param raw Pretty-printed form of the same body, used as the fallback message.
     * @return The error to throw.
     */
    static func error( status: Int, data: Data, raw: String ) -> IgnavError
    {
        guard let envelope = try? JSONDecoder().decode( IgnavErrorEnvelope.self, from: data )
        else
        {
            return .badStatus( status, raw )
        }
        return .api( status: status, code: envelope.error.code, message: envelope.error.message )
    }

    /**
     * Builds the POST request for an Ignav fares endpoint.
     *
     * @param apiKey Ignav API key, sent as the X-Api-Key header.
     * @param body Request payload to encode as the JSON body.
     * @param path Endpoint path under https://ignav.com/api/fares/.
     * @return The configured URLRequest, ready to send.
     */
    static func makeRequest< Body: Encodable >( apiKey: String, body: Body, path: String ) throws -> URLRequest
    {
        var req = URLRequest( url: self.baseURL.appendingPathComponent( path ) )
        req.httpMethod = "POST"
        req.setValue( apiKey, forHTTPHeaderField: "X-Api-Key" )
        req.setValue( "application/json", forHTTPHeaderField: "Content-Type" )
        req.httpBody = try JSONEncoder().encode( body )
        req.timeoutInterval = 60
        return req
    }

    /**
     * Whether a status code counts as a success.
     *
     * @param status HTTP status code.
     * @return True for 2xx.
     */
    static func isSuccess( status: Int ) -> Bool
    {
        ( 200 ..< 300 ).contains( status )
    }

    static func pretty( _ data: Data ) -> String
    {
        guard let obj = try? JSONSerialization.jsonObject( with: data ),
              let d = try? JSONSerialization.data(
                  withJSONObject: obj,
                  options: [ .prettyPrinted, .sortedKeys ]
              ),
              let s = String( data: d, encoding: .utf8 )
        else { return String( data: data, encoding: .utf8 ) ?? "<binary>" }
        return s
    }
}
