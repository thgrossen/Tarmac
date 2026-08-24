/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

enum IgnavError: LocalizedError
{
    case badStatus( Int, String )
    var errorDescription: String?
    {
        switch self
        {
            case .badStatus( let code, let body ): return "HTTP \( code )\n\( body )"
        }
    }
}

struct IgnavClient
{
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

    private func post< Body: Encodable >( _ body: Body, to path: String ) async throws -> ( FaresResponse, String )
    {
        let req = try Self.makeRequest( apiKey: self.apiKey, body: body, path: path )
        let ( data, response ) = try await URLSession.shared.data( for: req )
        let raw = Self.pretty( data )

        if let http = response as? HTTPURLResponse, !( 200 ..< 300 ).contains( http.statusCode )
        {
            throw IgnavError.badStatus( http.statusCode, raw )
        }
        return ( try JSONDecoder().decode( FaresResponse.self, from: data ), raw )
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
        var req = URLRequest( url: URL( string: "https://ignav.com/api/fares/\( path )" )! )
        req.httpMethod = "POST"
        req.setValue( apiKey, forHTTPHeaderField: "X-Api-Key" )
        req.setValue( "application/json", forHTTPHeaderField: "Content-Type" )
        req.httpBody = try JSONEncoder().encode( body )
        req.timeoutInterval = 60
        return req
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
