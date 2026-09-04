/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "OneWayDateSweep" )
struct OneWayDateSweepTests
{
    private static func utcDate( _ year: Int, _ month: Int, _ day: Int ) -> Date
    {
        var calendar      = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        let components    = DateComponents( year: year, month: month, day: day )
        return calendar.date( from: components )!
    }

    private static func makeSearch( rangeStart: Date, rangeEnd: Date ) -> SavedSearch
    {
        SavedSearch(
            kind: .oneWay,
            origin: "GVA",
            destination: "LIS",
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            cabinClass: "business"
        )
    }

    private static func fares( _ items: [ ( id: String?, amount: Double ) ] ) throws -> ( FaresResponse, String )
    {
        let itineraries = items.map
        { item -> [ String: Any ] in
            var dict: [ String: Any ] = [ "price": [ "amount": item.amount, "currency": "CHF" ] ]
            if let id = item.id
            {
                dict[ "ignav_id" ] = id
            }
            return dict
        }
        let data = try JSONSerialization.data( withJSONObject: [ "itineraries": itineraries ] )
        let response = try JSONDecoder().decode( FaresResponse.self, from: data )
        let raw = String( data: data, encoding: .utf8 )!
        return ( response, raw )
    }

    private struct StubError: LocalizedError
    {
        var errorDescription: String? { "stub network failure" }
    }

    private final class FetchLog
    {
        private( set ) var requests: [ OneWayRequest ] = []
        func record( _ request: OneWayRequest )
        {
            self.requests.append( request )
        }
    }

    private final class ProgressLog
    {
        private( set ) var emissions: [ SearchProgress ] = []
        func record( _ progress: SearchProgress )
        {
            self.emissions.append( progress )
        }
    }

    // MARK: - dates(for:)

    @Test( "A single-day range yields exactly one date" )
    func datesSingleDay()
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 5 ) )
        let dates = OneWayDateSweep.dates( for: search )

        #expect( dates == [ Self.utcDate( 2026, 10, 5 ) ] )
    }

    @Test( "A multi-day range enumerates every day inclusive" )
    func datesMultiDay()
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 8 ) )
        let dates = OneWayDateSweep.dates( for: search )

        #expect( dates == [
            Self.utcDate( 2026, 10, 5 ),
            Self.utcDate( 2026, 10, 6 ),
            Self.utcDate( 2026, 10, 7 ),
            Self.utcDate( 2026, 10, 8 ),
        ] )
    }

    @Test( "A reversed date range is normalized" )
    func datesReversedRange()
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 8 ), rangeEnd: Self.utcDate( 2026, 10, 5 ) )
        let dates = OneWayDateSweep.dates( for: search )

        #expect( dates.count == 4 )
        #expect( dates.first == Self.utcDate( 2026, 10, 5 ) )
        #expect( dates.last == Self.utcDate( 2026, 10, 8 ) )
    }

    // MARK: - run(for:apiKey:...)

    @Test( "A single-day range produces one call with the correct departure_date" )
    func runSingleDay() async throws
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 5 ) )
        let log = FetchLog()
        let ( mockResponse, mockRaw ) = try Self.fares( [ ( id: "AB1", amount: 500 ) ] )

        let result = await OneWayDateSweep.run( for: search, apiKey: "key" )
        { request in
            log.record( request )
            return ( mockResponse, mockRaw )
        }

        #expect( result.requestCount == 1 )
        #expect( result.failedRequestCount == 0 )
        #expect( result.itineraries.count == 1 )
        #expect( result.itineraries.first?.ignav_id == "AB1" )
        #expect( result.rawJSON == mockRaw )
        #expect( result.errorMessage == nil )
        #expect( log.requests.count == 1 )
        #expect( log.requests.first?.departure_date == "2026-10-05" )
        #expect( log.requests.first?.origin == "GVA" )
        #expect( log.requests.first?.destination == "LIS" )
    }

    @Test( "One request per day, each with the correct departure_date" )
    func runOneRequestPerDay() async throws
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 7 ) )
        let log = FetchLog()

        let result = await OneWayDateSweep.run( for: search, apiKey: "key" )
        { request in
            log.record( request )
            return try Self.fares( [ ( id: "X\( log.requests.count )", amount: 100 ) ] )
        }

        #expect( result.requestCount == 3 )
        #expect( log.requests.map( \.departure_date ) == [ "2026-10-05", "2026-10-06", "2026-10-07" ] )
    }

    @Test( "Never fires more calls than the cap, even with a long range" )
    func runRespectsCap() async throws
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 1 ), rangeEnd: Self.utcDate( 2026, 10, 31 ) )
        let log = FetchLog()

        let result = await OneWayDateSweep.run( for: search, apiKey: "key", cap: 5 )
        { request in
            log.record( request )
            return try Self.fares( [ ( id: "X", amount: 100 ) ] )
        }

        #expect( result.requestCount == 5 )
        #expect( log.requests.count == 5 )
    }

    @Test( "Aggregates, sorts by price, and keeps the raw JSON of the cheapest response" )
    func runSortsAndTracksCheapest() async throws
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 7 ) )
        let prices: [ Double ] = [ 700, 500, 600 ]
        var callIndex = 0

        let result = await OneWayDateSweep.run( for: search, apiKey: "key" )
        { _ in
            let ( response, raw ) = try Self.fares( [ ( id: "id\( callIndex )", amount: prices[ callIndex ] ) ] )
            callIndex += 1
            return ( response, raw )
        }

        #expect( result.itineraries.map( \.price.amount ) == [ 500, 600, 700 ] )
        #expect( result.rawJSON?.contains( "500" ) == true )
    }

    @Test( "Deduplicates itineraries sharing the same ignav_id" )
    func runDeduplicates() async throws
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 6 ) )

        let result = await OneWayDateSweep.run( for: search, apiKey: "key" )
        { _ in
            try Self.fares( [ ( id: "DUP1", amount: 400 ) ] )
        }

        #expect( result.requestCount == 2 )
        #expect( result.itineraries.count == 1 )
    }

    @Test( "A failed day doesn't prevent aggregating the rest, and is counted" )
    func runTracksPartialFailure() async throws
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 6 ) )
        var callIndex = 0

        let result = await OneWayDateSweep.run( for: search, apiKey: "key" )
        { _ in
            defer { callIndex += 1 }
            if callIndex == 0
            {
                throw StubError()
            }
            return try Self.fares( [ ( id: "OK1", amount: 400 ) ] )
        }

        #expect( result.requestCount == 2 )
        #expect( result.failedRequestCount == 1 )
        #expect( result.itineraries.count == 1 )
        #expect( result.errorMessage == nil )
    }

    @Test( "Surfaces an error message when every day fails" )
    func runSurfacesErrorWhenAllFail() async
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 5 ) )

        let result = await OneWayDateSweep.run( for: search, apiKey: "key" )
        { _ in
            throw StubError()
        }

        #expect( result.itineraries.isEmpty )
        #expect( result.errorMessage == "stub network failure" )
        #expect( result.requestCount == 1 )
        #expect( result.failedRequestCount == 1 )
    }

    @Test( "No failures at all leaves failedRequestCount at zero" )
    func runNoFailures() async throws
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 6 ) )

        let result = await OneWayDateSweep.run( for: search, apiKey: "key" )
        { _ in
            try Self.fares( [ ( id: "OK", amount: 100 ) ] )
        }

        #expect( result.failedRequestCount == 0 )
        #expect( result.requestCount == 2 )
    }

    // MARK: - Progress reporting

    @Test( "Progress is reported up front, then once per day" )
    func runReportsProgress() async throws
    {
        let search   = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 7 ) )
        let progress = ProgressLog()

        // Recorded as each request starts, so the emissions are pinned as interleaved with the
        // requests rather than merely arriving in the right order once the sweep is over.
        var emissionCountsAtRequest: [ Int ] = []

        let result = await OneWayDateSweep.run(
            for: search,
            apiKey: "key",
            fetch: { _ in
                emissionCountsAtRequest.append( progress.emissions.count )
                return try Self.fares( [ ( id: "OK", amount: 100 ) ] )
            },
            onProgress: { progress.record( $0 ) }
        )

        #expect( emissionCountsAtRequest == [ 1, 2, 3 ] )
        #expect( progress.emissions.map( \.completed ) == [ 0, 1, 2, 3 ] )
        #expect( progress.emissions.allSatisfy { $0.total == 3 } )
        #expect( progress.emissions.last?.total == result.requestCount )
        #expect( progress.emissions.last?.fraction == 1 )
    }

    @Test( "A failed day still advances progress" )
    func runReportsProgressForFailedDays() async throws
    {
        let search    = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 6 ) )
        let progress  = ProgressLog()
        var callIndex = 0

        let result = await OneWayDateSweep.run(
            for: search,
            apiKey: "key",
            fetch: { _ in
                defer { callIndex += 1 }
                if callIndex == 0
                {
                    throw StubError()
                }
                return try Self.fares( [ ( id: "OK", amount: 100 ) ] )
            },
            onProgress: { progress.record( $0 ) }
        )

        #expect( result.failedRequestCount == 1 )
        #expect( progress.emissions.map( \.completed ) == [ 0, 1, 2 ] )
    }

    @Test( "Progress counts the sampled days, not the whole range" )
    func runReportsProgressAgainstTheCap() async throws
    {
        let search   = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 1 ), rangeEnd: Self.utcDate( 2026, 10, 31 ) )
        let progress = ProgressLog()

        let result = await OneWayDateSweep.run(
            for: search,
            apiKey: "key",
            cap: 5,
            fetch: { _ in try Self.fares( [ ( id: "X", amount: 100 ) ] ) },
            onProgress: { progress.record( $0 ) }
        )

        #expect( result.requestCount == 5 )
        #expect( progress.emissions.map( \.completed ) == [ 0, 1, 2, 3, 4, 5 ] )
        #expect( progress.emissions.allSatisfy { $0.total == 5 } )
    }

    @Test( "A sweep with nothing to do reports nothing planned" )
    func runReportsEmptyProgress() async
    {
        let search   = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 5 ), rangeEnd: Self.utcDate( 2026, 10, 8 ) )
        let progress = ProgressLog()

        let result = await OneWayDateSweep.run(
            for: search,
            apiKey: "key",
            cap: 0,
            fetch: { _ in try Self.fares( [ ( id: "OK", amount: 100 ) ] ) },
            onProgress: { progress.record( $0 ) }
        )

        #expect( result.requestCount == 0 )
        #expect( progress.emissions.count == 1 )
        #expect( progress.emissions.first == SearchProgress( completed: 0, total: 0 ) )
    }
}
