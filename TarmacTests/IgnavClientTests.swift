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
        #expect( json[ "max_stops" ] as? Int == 0 )
        #expect( json[ "airlines_include" ] == nil )
    }

    @Test( "Builds the booking-links request correctly" )
    func makeRequestBookingLinks() throws
    {
        let body = BookingLinksRequest( ignav_id: "abc123" )
        let req  = try IgnavClient.makeRequest( apiKey: "s3cr3t", body: body, path: "booking-links" )

        #expect( req.url?.absoluteString == "https://ignav.com/api/fares/booking-links" )
        #expect( req.httpMethod == "POST" )
        #expect( req.value( forHTTPHeaderField: "X-Api-Key" ) == "s3cr3t" )

        let json = Self.decodedBody( req )
        #expect( json[ "ignav_id" ] as? String == "abc123" )
        #expect( json.count == 1 )
    }

    @Test( "A structured error body becomes a typed error carrying its code" )
    func mapsErrorEnvelopeToTypedError() throws
    {
        let data = """
            { "error": { "type": "not_found", "code": "ignav_id_not_found", "message": "The ignav_id was not found." } }
            """.data( using: .utf8 )!

        let error = IgnavClient.error( status: 404, data: data, raw: "raw" )

        #expect( error.apiCode == "ignav_id_not_found" )
        #expect( error.localizedDescription == "The ignav_id was not found." )
    }

    @Test( "A body that isn't the error envelope still reports the raw status and body" )
    func mapsUnstructuredErrorToBadStatus() throws
    {
        let data  = "<html>gateway timeout</html>".data( using: .utf8 )!
        let error = IgnavClient.error( status: 504, data: data, raw: "<html>gateway timeout</html>" )

        #expect( error.apiCode == nil )
        #expect( error.localizedDescription == "HTTP 504\n<html>gateway timeout</html>" )
    }

    // MARK: - Capturing calls for the inspector

    @Test( "A captured call records the request the inspector needs, with the API key redacted" )
    func capturesRequestWithRedactedKey() throws
    {
        let request = try IgnavClient.makeRequest(
            apiKey: "s3cr3t",
            body: OneWayRequest(
                origin: "GVA",
                destination: "LIS",
                departure_date: "2026-10-05",
                cabin_class: "business",
                max_stops: 0
            ),
            path: "one-way"
        )
        let data = #"{"itineraries":[]}"#.data( using: .utf8 )!

        let transaction = IgnavClient.transaction(
            request: request,
            endpoint: "one-way",
            startedAt: Date( timeIntervalSince1970: 1_800_000_000 ),
            duration: 0.412,
            data: data,
            outcome: .ok( status: 200 )
        )

        #expect( transaction.endpoint == "one-way" )
        #expect( transaction.method == "POST" )
        #expect( transaction.url.absoluteString == "https://ignav.com/api/fares/one-way" )
        #expect( transaction.headers[ "X-Api-Key" ] == APITransaction.redactedValue )
        #expect( transaction.headers[ "Content-Type" ] == "application/json" )
        #expect( transaction.duration == 0.412 )
        #expect( transaction.isFailure == false )

        // Both bodies are pretty-printed, so the inspector doesn't have to reformat them.
        #expect( transaction.requestBody.contains( "\"departure_date\" : \"2026-10-05\"" ) )
        #expect( transaction.requestBody.contains( "s3cr3t" ) == false )
        #expect( transaction.responseBody?.contains( "itineraries" ) == true )
        #expect( transaction.responseByteCount == data.count )
        #expect( transaction.label == "GVA → LIS · 2026-10-05" )
    }

    @Test( "A failed response is captured with its body, which is what the search code discards" )
    func capturesFailedResponseBody() throws
    {
        let request = try IgnavClient.makeRequest( apiKey: "s3cr3t", body: BookingLinksRequest( ignav_id: "abc" ), path: "booking-links" )
        let data    = #"{ "error": { "code": "ignav_id_not_found", "message": "gone" } }"#.data( using: .utf8 )!

        let transaction = IgnavClient.transaction(
            request: request,
            endpoint: "booking-links",
            startedAt: .now,
            duration: 0.08,
            data: data,
            outcome: .httpError( status: 404 )
        )

        #expect( transaction.isFailure )
        #expect( transaction.statusLabel == "404" )
        #expect( transaction.responseBody?.contains( "ignav_id_not_found" ) == true )
    }

    @Test( "A call that never reached the server is captured without a response" )
    func capturesTransportFailure() throws
    {
        let request = try IgnavClient.makeRequest( apiKey: "s3cr3t", body: BookingLinksRequest( ignav_id: "abc" ), path: "booking-links" )

        let transaction = IgnavClient.transaction(
            request: request,
            endpoint: "booking-links",
            startedAt: .now,
            duration: 60,
            data: nil,
            outcome: .transportError( message: "The request timed out." )
        )

        #expect( transaction.responseBody == nil )
        #expect( transaction.responseByteCount == 0 )
        #expect( transaction.statusCode == nil )
    }

    @Test( "A captured call is attributed to the run whose context it was made inside" )
    func capturesRunAttribution() async throws
    {
        let runID   = UUID()
        let request = try IgnavClient.makeRequest( apiKey: "s3cr3t", body: BookingLinksRequest( ignav_id: "abc" ), path: "booking-links" )

        let attributed = APICallContext.$current.withValue( APICallContext.Info( runID: runID ) )
        {
            IgnavClient.transaction(
                request: request,
                endpoint: "booking-links",
                startedAt: .now,
                duration: 0.1,
                data: nil,
                outcome: .ok( status: 200 )
            )
        }

        #expect( attributed.runID == runID )

        let unattributed = IgnavClient.transaction(
            request: request,
            endpoint: "booking-links",
            startedAt: .now,
            duration: 0.1,
            data: nil,
            outcome: .ok( status: 200 )
        )

        #expect( unattributed.runID == nil )
    }

    @Test( "Every endpoint path hangs off the same base URL" )
    func buildsEveryPathOffTheBaseURL() throws
    {
        for path in [ "one-way", "round-trip", "booking-links" ]
        {
            let request = try IgnavClient.makeRequest( apiKey: "k", body: BookingLinksRequest( ignav_id: "abc" ), path: path )
            #expect( request.url?.absoluteString == "https://ignav.com/api/fares/\( path )" )
        }
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

        let departureDate = try #require( itinerary.outbound?.segments?.first?.departure_date )
        let components = Calendar.current.dateComponents( [ .year, .month, .day ], from: departureDate )
        #expect( components.year == 2026 )
        #expect( components.month == 8 )
        #expect( components.day == 26 )
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
        #expect( segment.departure_date == nil )
    }
}
