/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "APILog" )
struct APILogTests
{
    // MARK: - Eviction

    @Test( "The log keeps only its newest transactions once the count cap is passed" )
    func evictsPastTheCountCap()
    {
        let transactions = ( 0 ..< ( APILog.maxTransactions + 20 ) ).map
        {
            Self.transaction( endpoint: "call-\( $0 )" )
        }

        let kept = APILog.evicted( transactions )

        #expect( kept.count == APILog.maxTransactions )
        #expect( kept.first?.endpoint == "call-0" )
        #expect( kept.last?.endpoint == "call-\( APILog.maxTransactions - 1 )" )
    }

    @Test( "The log stops accumulating once its transactions weigh too much" )
    func evictsPastTheByteCap()
    {
        let half = APILog.maxResponseBytes / 2 + 1
        let transactions = [
            Self.transaction( endpoint: "newest", byteCount: half ),
            Self.transaction( endpoint: "middle", byteCount: half ),
            Self.transaction( endpoint: "oldest", byteCount: half )
        ]

        let kept = APILog.evicted( transactions )

        #expect( kept.map( \.endpoint ) == [ "newest" ] )
    }

    @Test( "A single response larger than the whole budget is still kept" )
    func keepsOneOversizedTransaction()
    {
        let kept = APILog.evicted( [ Self.transaction( endpoint: "huge", byteCount: APILog.maxResponseBytes * 2 ) ] )

        #expect( kept.count == 1 )
    }

    // MARK: - Recording

    @Test( "Recording puts the newest call at the front of the log" )
    @MainActor
    func recordsNewestFirst()
    {
        let log = APILog()
        log.record( Self.transaction( endpoint: "first" ) )
        log.record( Self.transaction( endpoint: "second" ) )

        #expect( log.transactions.map( \.endpoint ) == [ "second", "first" ] )

        log.clear()
        #expect( log.transactions.isEmpty )
    }

    // MARK: - Filtering

    @Test( "Scoping to a run drops every other run's calls" )
    func filtersByRun()
    {
        let runID = UUID()
        let transactions = [
            Self.transaction( endpoint: "mine", runID: runID ),
            Self.transaction( endpoint: "theirs", runID: UUID() ),
            Self.transaction( endpoint: "unattributed" )
        ]

        #expect( APILog.filtered( transactions, runID: runID ).map( \.endpoint ) == [ "mine" ] )
        #expect( APILog.filtered( transactions ).count == 3 )
    }

    @Test( "The failures-only toggle keeps everything that didn't decode a 2xx response" )
    func filtersFailures()
    {
        let transactions = [
            Self.transaction( endpoint: "ok", outcome: .ok( status: 200 ) ),
            Self.transaction( endpoint: "http", outcome: .httpError( status: 429 ) ),
            Self.transaction( endpoint: "decode", outcome: .decodeError( status: 200, message: "bad" ) ),
            Self.transaction( endpoint: "transport", outcome: .transportError( message: "offline" ) )
        ]

        let kept = APILog.filtered( transactions, failuresOnly: true ).map( \.endpoint )

        #expect( kept == [ "http", "decode", "transport" ] )
    }

    @Test( "The filter field matches the endpoint, the request label, the status and both bodies" )
    func filtersByQuery()
    {
        let transactions = [
            Self.transaction( endpoint: "one-way", requestBody: #"{ "origin": "LHR", "destination": "JFK", "departure_date": "2026-10-05" }"# ),
            Self.transaction( endpoint: "booking-links", requestBody: #"{ "ignav_id": "xyza3f9" }"# ),
            Self.transaction( endpoint: "round-trip", responseBody: #"{ "itineraries": [ { "carrier": "SWISS" } ] }"# )
        ]

        #expect( APILog.filtered( transactions, query: "booking" ).map( \.endpoint ) == [ "booking-links" ] )
        #expect( APILog.filtered( transactions, query: "2026-10-05" ).map( \.endpoint ) == [ "one-way" ] )
        #expect( APILog.filtered( transactions, query: "swiss" ).map( \.endpoint ) == [ "round-trip" ] )
        #expect( APILog.filtered( transactions, query: "  " ).count == 3 )
        #expect( APILog.filtered( transactions, query: "nothing here" ).isEmpty )
    }

    @Test( "Filters combine, so a scoped failures-only query narrows on all three at once" )
    func combinesFilters()
    {
        let runID = UUID()
        let transactions = [
            Self.transaction( endpoint: "one-way", outcome: .httpError( status: 500 ), runID: runID ),
            Self.transaction( endpoint: "one-way", outcome: .ok( status: 200 ), runID: runID ),
            Self.transaction( endpoint: "one-way", outcome: .httpError( status: 500 ) )
        ]

        let kept = APILog.filtered( transactions, runID: runID, query: "one-way", failuresOnly: true )

        #expect( kept.count == 1 )
        #expect( kept.first?.statusLabel == "500" )
    }

    // MARK: - Export

    @Test( "Exporting produces a JSON array with one object per listed call" )
    func exportsJSONArray() throws
    {
        let data = try APILog.exportData( [ Self.transaction( endpoint: "one-way" ), Self.transaction( endpoint: "booking-links" ) ] )
        let decoded = try #require( JSONSerialization.jsonObject( with: data ) as? [ [ String: Any ] ] )

        #expect( decoded.count == 2 )
        #expect( decoded.first?[ "endpoint" ] as? String == "one-way" )
    }

    @Test( "Exporting an empty list produces an empty array rather than failing" )
    func exportsEmptyList() throws
    {
        let decoded = try JSONSerialization.jsonObject( with: try APILog.exportData( [] ) ) as? [ Any ]

        #expect( decoded?.isEmpty == true )
    }

    // MARK: - Helpers

    private static func transaction(
        endpoint: String,
        outcome: APITransaction.Outcome = .ok( status: 200 ),
        byteCount: Int = 0,
        runID: UUID? = nil,
        requestBody: String = "{}",
        responseBody: String? = "{}"
    ) -> APITransaction
    {
        APITransaction(
            startedAt:         Date( timeIntervalSince1970: 1_800_000_000 ),
            duration:          0.1,
            endpoint:          endpoint,
            url:               URL( string: "https://ignav.com/api/fares/\( endpoint )" )!,
            method:            "POST",
            headers:           [:],
            requestBody:       requestBody,
            responseBody:      responseBody,
            responseByteCount: byteCount,
            outcome:           outcome,
            runID:             runID
        )
    }
}
