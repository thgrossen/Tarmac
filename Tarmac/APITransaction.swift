/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

/**
 * One Ignav HTTP call, captured in full: what was sent, what came back, how long it took and how
 * it ended. Recorded for every call the app makes, including the ones whose payloads the search
 * code discards.
 *
 * The API key is never stored here — `headers` keeps `X-Api-Key` redacted, and anything that
 * needs the real key reads it from user preferences at the moment it is needed.
 */
struct APITransaction: Identifiable, Sendable
{
    enum Outcome: Sendable, Equatable
    {
        /// A 2xx response that decoded into the expected model.
        case ok( status: Int )

        /// A non-2xx response.
        case httpError( status: Int )

        /// A 2xx response whose body didn't match the expected model.
        case decodeError( status: Int, message: String )

        /// The request never produced a response — offline, timed out, cancelled.
        case transportError( message: String )
    }

    /// Placeholder the copy-as-curl action substitutes for the key when it isn't asked to include it.
    static let apiKeyPlaceholder = "$IGNAV_API_KEY"

    /// Value `X-Api-Key` is recorded as, so a captured transaction never carries the key.
    static let redactedValue = "<redacted>"

    var id = UUID()
    var startedAt: Date
    var duration: TimeInterval
    var endpoint: String
    var url: URL
    var method: String
    var headers: [ String: String ]
    var requestBody: String
    var responseBody: String?
    var responseByteCount: Int
    var outcome: Outcome
    var runID: UUID?

    /**
     * HTTP status the call ended with, or nil when it never reached the server.
     */
    var statusCode: Int?
    {
        switch self.outcome
        {
            case .ok( let status ):              return status
            case .httpError( let status ):       return status
            case .decodeError( let status, _ ):  return status
            case .transportError:                return nil
        }
    }

    /**
     * Whether this call ended in anything other than a decoded 2xx response.
     */
    var isFailure: Bool
    {
        switch self.outcome
        {
            case .ok: return false
            default:  return true
        }
    }

    /**
     * Short status for the row and the detail header, e.g. "200", "429" or "Failed".
     */
    var statusLabel: String
    {
        guard let statusCode = self.statusCode
        else
        {
            return "Failed"
        }
        return "\( statusCode )"
    }

    /**
     * Why the call failed, for the detail header — nil when it succeeded.
     */
    var failureDetail: String?
    {
        switch self.outcome
        {
            case .ok:                              return nil
            case .httpError:                       return "HTTP error"
            case .decodeError( _, let message ):   return "Response didn't decode: \( message )"
            case .transportError( let message ):   return message
        }
    }

    /**
     * The row's subtitle, describing what this call asked for. Derived from the request body so
     * nothing has to be threaded down the call chain to label a request.
     */
    var label: String?
    {
        Self.label( endpoint: self.endpoint, requestBody: self.requestBody )
    }

    /**
     * Describes an Ignav request in one line, e.g. "LHR → JFK · 2026-10-05" for a one-way,
     * "LHR ↔ JFK · 2026-10-05 → 2026-10-12" for a round trip, and "ignav_id …a3f9" for a booking
     * link lookup.
     *
     * @param endpoint Endpoint path the request was sent to.
     * @param requestBody JSON body that was posted.
     * @return A display label, or nil when the body doesn't carry the fields to build one.
     */
    static func label( endpoint: String, requestBody: String ) -> String?
    {
        guard let data = requestBody.data( using: .utf8 ),
              let json = try? JSONSerialization.jsonObject( with: data ) as? [ String: Any ]
        else
        {
            return nil
        }

        if let ignavID = json[ "ignav_id" ] as? String
        {
            return "ignav_id …\( ignavID.suffix( 4 ) )"
        }

        guard let origin      = json[ "origin" ] as? String,
              let destination = json[ "destination" ] as? String,
              let departure   = json[ "departure_date" ] as? String
        else
        {
            return nil
        }

        guard let returnDate = json[ "return_date" ] as? String
        else
        {
            return "\( origin ) → \( destination ) · \( departure )"
        }
        return "\( origin ) ↔ \( destination ) · \( departure ) → \( returnDate )"
    }

    /**
     * Reproduces this call as a runnable curl command.
     *
     * @param apiKey Key to send, or nil to emit `APITransaction.apiKeyPlaceholder` instead so the
     *               command can be shared without leaking it.
     * @return The curl command, ready to paste into a shell.
     */
    func curlCommand( apiKey: String? ) -> String
    {
        var lines = [ "curl -X \( self.method ) '\( self.url.absoluteString )'" ]

        for name in self.headers.keys.sorted()
        {
            let value = name.lowercased() == "x-api-key"
                ? ( apiKey ?? Self.apiKeyPlaceholder )
                : ( self.headers[ name ] ?? "" )

            lines.append( "  -H '\( name ): \( value )'" )
        }

        if self.requestBody.isEmpty == false
        {
            lines.append( "  -d '\( Self.shellEscaped( self.requestBody ) )'" )
        }

        return lines.joined( separator: " \\\n" )
    }

    /**
     * A JSON-encodable form of this transaction, used by the log's export action.
     */
    var exportRepresentation: [ String: Any ]
    {
        var result: [ String: Any ] = [
            "startedAt":         ISO8601DateFormatter().string( from: self.startedAt ),
            "durationSeconds":   self.duration,
            "endpoint":          self.endpoint,
            "url":               self.url.absoluteString,
            "method":            self.method,
            "headers":           self.headers,
            "requestBody":       self.requestBody,
            "responseByteCount": self.responseByteCount,
            "status":            self.statusLabel,
            "failed":            self.isFailure
        ]

        result[ "responseBody" ]  = self.responseBody
        result[ "failureDetail" ] = self.failureDetail
        result[ "runID" ]         = self.runID?.uuidString

        return result
    }

    /**
     * Escapes a string for use inside single quotes in a shell command.
     *
     * @param text Text to escape.
     * @return The text with every single quote closed, escaped and reopened.
     */
    private static func shellEscaped( _ text: String ) -> String
    {
        text.replacingOccurrences( of: "'", with: "'\\''" )
    }
}
