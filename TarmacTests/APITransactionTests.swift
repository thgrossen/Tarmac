/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "APITransaction" )
struct APITransactionTests
{
    // MARK: - Labels

    @Test( "A one-way request is labelled with its route and departure date" )
    func labelsOneWayRequest()
    {
        let body = """
        { "origin": "LHR", "destination": "JFK", "departure_date": "2026-10-05" }
        """

        #expect( APITransaction.label( endpoint: "one-way", requestBody: body ) == "LHR → JFK · 2026-10-05" )
    }

    @Test( "A round-trip request is labelled with both of its dates" )
    func labelsRoundTripRequest()
    {
        let body = """
        {
            "origin": "LHR",
            "destination": "JFK",
            "departure_date": "2026-10-05",
            "return_date": "2026-10-12"
        }
        """

        #expect( APITransaction.label( endpoint: "round-trip", requestBody: body ) == "LHR ↔ JFK · 2026-10-05 → 2026-10-12" )
    }

    @Test( "A booking-links request is labelled with the tail of its handoff token" )
    func labelsBookingLinksRequest()
    {
        let body = #"{ "ignav_id": "abc123a3f9" }"#

        #expect( APITransaction.label( endpoint: "booking-links", requestBody: body ) == "ignav_id …a3f9" )
    }

    @Test( "A body that isn't JSON, or lacks the fields to describe, produces no label" )
    func labelsNothingForUnusableBodies()
    {
        #expect( APITransaction.label( endpoint: "one-way", requestBody: "not json at all" ) == nil )
        #expect( APITransaction.label( endpoint: "one-way", requestBody: #"{ "origin": "LHR" }"# ) == nil )
        #expect( APITransaction.label( endpoint: "one-way", requestBody: "" ) == nil )
    }

    // MARK: - Outcomes

    @Test( "A decoded 2xx response is the only outcome that counts as a success" )
    func classifiesOutcomes()
    {
        let ok = Self.transaction( outcome: .ok( status: 200 ) )
        #expect( ok.isFailure == false )
        #expect( ok.statusCode == 200 )
        #expect( ok.statusLabel == "200" )
        #expect( ok.failureDetail == nil )

        let httpError = Self.transaction( outcome: .httpError( status: 429 ) )
        #expect( httpError.isFailure )
        #expect( httpError.statusCode == 429 )
        #expect( httpError.statusLabel == "429" )

        let decodeError = Self.transaction( outcome: .decodeError( status: 200, message: "keyNotFound" ) )
        #expect( decodeError.isFailure )
        #expect( decodeError.statusCode == 200 )
        #expect( decodeError.failureDetail?.contains( "keyNotFound" ) == true )
    }

    @Test( "A request that never reached the server has no status code" )
    func classifiesTransportFailure()
    {
        let transaction = Self.transaction( outcome: .transportError( message: "The request timed out." ) )

        #expect( transaction.isFailure )
        #expect( transaction.statusCode == nil )
        #expect( transaction.statusLabel == "Failed" )
        #expect( transaction.failureDetail == "The request timed out." )
    }

    // MARK: - curl

    @Test( "Copying as curl without a key substitutes the placeholder and leaks nothing" )
    func buildsCurlWithPlaceholder()
    {
        let command = Self.transaction( outcome: .ok( status: 200 ) ).curlCommand( apiKey: nil )

        #expect( command.contains( "curl -X POST 'https://ignav.com/api/fares/one-way'" ) )
        #expect( command.contains( "-H 'X-Api-Key: $IGNAV_API_KEY'" ) )
        #expect( command.contains( "-H 'Content-Type: application/json'" ) )
        #expect( command.contains( "secret-key" ) == false )
        #expect( command.contains( APITransaction.redactedValue ) == false )
    }

    @Test( "Copying as curl with a key sends the real value" )
    func buildsCurlWithKey()
    {
        let command = Self.transaction( outcome: .ok( status: 200 ) ).curlCommand( apiKey: "secret-key" )

        #expect( command.contains( "-H 'X-Api-Key: secret-key'" ) )
        #expect( command.contains( APITransaction.apiKeyPlaceholder ) == false )
    }

    @Test( "A body containing single quotes stays inside its shell quoting" )
    func escapesQuotesInCurlBody()
    {
        var transaction = Self.transaction( outcome: .ok( status: 200 ) )
        transaction.requestBody = #"{ "note": "it's fine" }"#

        #expect( transaction.curlCommand( apiKey: nil ).contains( #"it'\''s fine"# ) )
    }

    // MARK: - Export

    @Test( "The export form carries the outcome, the bodies and the run it belonged to" )
    func exportsEveryField() throws
    {
        let runID = UUID()
        var transaction = Self.transaction( outcome: .httpError( status: 429 ) )
        transaction.runID = runID

        let exported = transaction.exportRepresentation

        #expect( exported[ "endpoint" ] as? String == "one-way" )
        #expect( exported[ "method" ] as? String == "POST" )
        #expect( exported[ "status" ] as? String == "429" )
        #expect( exported[ "failed" ] as? Bool == true )
        #expect( exported[ "runID" ] as? String == runID.uuidString )
        #expect( exported[ "responseByteCount" ] as? Int == 12 )
        #expect( try #require( exported[ "responseBody" ] as? String ).contains( "itineraries" ) )
    }

    @Test( "The export form redacts the API key, matching what the transaction stored" )
    func exportsRedactedHeaders() throws
    {
        let headers = try #require( Self.transaction( outcome: .ok( status: 200 ) ).exportRepresentation[ "headers" ] as? [ String: String ] )

        #expect( headers[ "X-Api-Key" ] == APITransaction.redactedValue )
    }

    // MARK: - Helpers

    private static func transaction( outcome: APITransaction.Outcome ) -> APITransaction
    {
        APITransaction(
            startedAt:         Date( timeIntervalSince1970: 1_800_000_000 ),
            duration:          0.412,
            endpoint:          "one-way",
            url:               URL( string: "https://ignav.com/api/fares/one-way" )!,
            method:            "POST",
            headers:           [ "X-Api-Key": APITransaction.redactedValue, "Content-Type": "application/json" ],
            requestBody:       #"{ "origin": "LHR", "destination": "JFK", "departure_date": "2026-10-05" }"#,
            responseBody:      #"{ "itineraries": [] }"#,
            responseByteCount: 12,
            outcome:           outcome
        )
    }
}

@Suite( "APIInspectorFormat" )
struct APIInspectorFormatTests
{
    @Test( "Short calls are timed in milliseconds and long ones in seconds" )
    func formatsDuration()
    {
        #expect( APIInspectorFormat.duration( 0.412 ) == "412 ms" )
        #expect( APIInspectorFormat.duration( 0 ) == "0 ms" )
        #expect( APIInspectorFormat.duration( 9.9994 ) == "9999 ms" )
        #expect( APIInspectorFormat.duration( 12.44 ) == "12.4 s" )
    }

    @Test( "A row's summary reads as status, duration and size" )
    func formatsSummary()
    {
        let transaction = APITransaction(
            startedAt:         .now,
            duration:          0.412,
            endpoint:          "one-way",
            url:               URL( string: "https://ignav.com/api/fares/one-way" )!,
            method:            "POST",
            headers:           [:],
            requestBody:       "{}",
            responseBody:      "{}",
            responseByteCount: 0,
            outcome:           .ok( status: 200 )
        )

        let summary = APIInspectorFormat.summary( for: transaction )

        #expect( summary.hasPrefix( "200 · 412 ms · " ) )
    }
}
