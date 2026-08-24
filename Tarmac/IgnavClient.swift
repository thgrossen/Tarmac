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

    /// Renvoie (résultat décodé, JSON brut formaté)
    func roundTrip( _ body: RoundTripRequest ) async throws -> ( FaresResponse, String )
    {
        var req = URLRequest( url: URL( string: "https://ignav.com/api/fares/round-trip" )! )
        req.httpMethod = "POST"
        req.setValue( self.apiKey, forHTTPHeaderField: "X-Api-Key" )
        req.setValue( "application/json", forHTTPHeaderField: "Content-Type" )
        req.httpBody = try JSONEncoder().encode( body )
        req.timeoutInterval = 60

        let ( data, response ) = try await URLSession.shared.data( for: req )
        let raw = Self.pretty( data )

        if let http = response as? HTTPURLResponse, !( 200 ..< 300 ).contains( http.statusCode )
        {
            throw IgnavError.badStatus( http.statusCode, raw )
        }
        return ( try JSONDecoder().decode( FaresResponse.self, from: data ), raw )
    }

    static func pretty( _ data: Data ) -> String
    {
        guard let obj = try? JSONSerialization.jsonObject( with: data ),
              let d = try? JSONSerialization.data(
                  withJSONObject: obj,
                  options: [ .prettyPrinted, .sortedKeys ]
              ),
              let s = String( data: d, encoding: .utf8 )
        else { return String( data: data, encoding: .utf8 ) ?? "<binaire>" }
        return s
    }
}
