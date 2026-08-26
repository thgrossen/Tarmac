/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "IgnavClient" )
struct IgnavClientTests
{
    private static func decodedBody( _ request: URLRequest ) -> [ String: Any ]
    {
        let data = request.httpBody!
        return ( try? JSONSerialization.jsonObject( with: data ) as? [ String: Any ] ) ?? [ : ]
    }

    @Test( "Builds the one-way request correctly" )
    func makeRequestOneWay() throws
    {
        let body = OneWayRequest(
            origin: "GVA",
            destination: "LIS",
            departure_date: "2026-10-05",
            cabin_class: "business",
            max_stops: 0,
            airlines_include: [ "LX", "TP" ],
            market: "CH"
        )
        let req = try IgnavClient.makeRequest( apiKey: "s3cr3t", body: body, path: "one-way" )

        #expect( req.url?.absoluteString == "https://ignav.com/api/fares/one-way" )
        #expect( req.httpMethod == "POST" )
        #expect( req.value( forHTTPHeaderField: "X-Api-Key" ) == "s3cr3t" )
        #expect( req.value( forHTTPHeaderField: "Content-Type" ) == "application/json" )
        #expect( req.timeoutInterval == 60 )

        let json = Self.decodedBody( req )
        #expect( json[ "origin" ] as? String == "GVA" )
        #expect( json[ "destination" ] as? String == "LIS" )
        #expect( json[ "departure_date" ] as? String == "2026-10-05" )
        #expect( json[ "cabin_class" ] as? String == "business" )
        #expect( json[ "max_stops" ] as? Int == 0 )
        #expect( json[ "airlines_include" ] as? [ String ] == [ "LX", "TP" ] )
        #expect( json[ "market" ] as? String == "CH" )
        #expect( json[ "return_date" ] == nil )
    }

    @Test( "Builds the round-trip request correctly (unchanged by the shared request-builder refactor)" )
    func makeRequestRoundTrip() throws
    {
        let body = RoundTripRequest(
            origin: "GVA",
            destination: "LIS",
            departure_date: "2026-10-05",
            return_date: "2026-10-08",
            cabin_class: "business",
            max_stops: 0,
            airlines_include: nil,
            market: "CH"
        )
        let req = try IgnavClient.makeRequest( apiKey: "s3cr3t", body: body, path: "round-trip" )

        #expect( req.url?.absoluteString == "https://ignav.com/api/fares/round-trip" )
        #expect( req.httpMethod == "POST" )

        let json = Self.decodedBody( req )
        #expect( json[ "return_date" ] as? String == "2026-10-08" )
        #expect( json[ "airlines_include" ] == nil )
    }

    @Test( "Decodes a one-way response (no inbound leg)" )
    func decodesOneWayResponse() throws
    {
        let json = """
            {
                "itineraries": [
                    {
                        "ignav_id": "abc123",
                        "price": { "amount": 542.0, "currency": "CHF" },
                        "outbound": {
                            "carrier": "SWISS",
                            "duration_minutes": 145,
                            "segments": [
                                {
                                    "carrier_code": "LX",
                                    "marketing_carrier_code": "LX",
                                    "flight_number": "1234",
                                    "departure_time_local": "2026-08-26T14:30:00",
                                    "arrival_time_local": "2026-08-26T17:55:00"
                                }
                            ]
                        }
                    }
                ]
            }
            """.data( using: .utf8 )!

        let decoded = try JSONDecoder().decode( FaresResponse.self, from: json )
        #expect( decoded.itineraries.count == 1 )

        let itinerary = try #require( decoded.itineraries.first )
        #expect( itinerary.ignav_id == "abc123" )
        #expect( itinerary.price.amount == 542.0 )
        #expect( itinerary.outbound?.carrier == "SWISS" )
        #expect( itinerary.outbound?.duration == "2h25" )
        #expect( itinerary.outbound?.segments?.first?.carrier_code == "LX" )
        #expect( itinerary.outbound?.segments?.first?.marketing_carrier_code == "LX" )
        #expect( itinerary.outbound?.segments?.first?.departure_time == "14:30" )
        #expect( itinerary.outbound?.segments?.first?.arrival_time == "17:55" )
        #expect( itinerary.inbound == nil )
    }

    @Test( "A malformed segment time string decodes to nil, not the raw value" )
    func decodesMalformedSegmentTimeAsNil() throws
    {
        let json = """
            {
                "itineraries": [
                    {
                        "price": { "amount": 100, "currency": "CHF" },
                        "outbound": {
                            "segments": [
                                { "departure_time_local": "not-a-date", "arrival_time_local": "17:55" }
                            ]
                        }
                    }
                ]
            }
            """.data( using: .utf8 )!

        let decoded = try JSONDecoder().decode( FaresResponse.self, from: json )
        let segment = try #require( decoded.itineraries.first?.outbound?.segments?.first )

        #expect( segment.departure_time == nil )
        #expect( segment.arrival_time == nil )
    }
}
