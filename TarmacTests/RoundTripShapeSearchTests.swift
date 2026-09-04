/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "RoundTripShapeSearch" )
struct RoundTripShapeSearchTests
{
    private static func utcDate( _ year: Int, _ month: Int, _ day: Int ) -> Date
    {
        var calendar      = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        let components    = DateComponents( year: year, month: month, day: day )
        return calendar.date( from: components )!
    }

    private static func makeSearch(
        rangeStart: Date,
        rangeEnd: Date,
        tripDurationDays: Int,
        flexibilityDays: Int,
        mustIncludeWeekend: Bool = false
    ) -> SavedSearch
    {
        SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            cabinClass: "business",
            tripDurationDays: tripDurationDays,
            flexibilityDays: flexibilityDays,
            mustIncludeWeekend: mustIncludeWeekend
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
        private( set ) var requests: [ RoundTripRequest ] = []
        func record( _ request: RoundTripRequest )
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

    // MARK: - candidates(for:)

    @Test( "Zero flexibility, single-day range yields exactly one candidate" )
    func candidatesZeroFlexibility()
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )
        let candidates = RoundTripShapeSearch.candidates( for: search )

        #expect( candidates.count == 1 )
        #expect( candidates.first?.departure == Self.utcDate( 2026, 10, 5 ) )
        #expect( candidates.first?.returnDate == Self.utcDate( 2026, 10, 8 ) )
    }

    @Test( "Range and flexibility enumerate every date × duration combination" )
    func candidatesRangeAndFlexibility()
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 7 ),
            tripDurationDays: 3,
            flexibilityDays: 1
        )
        let candidates = RoundTripShapeSearch.candidates( for: search )

        #expect( candidates.count == 9 )
        #expect( candidates.contains( .init( departure: Self.utcDate( 2026, 10, 5 ), returnDate: Self.utcDate( 2026, 10, 7 ) ) ) )
        #expect( candidates.contains( .init( departure: Self.utcDate( 2026, 10, 7 ), returnDate: Self.utcDate( 2026, 10, 11 ) ) ) )
    }

    @Test( "Duration is clamped to a minimum of 1 night" )
    func candidatesMinimumOneNight()
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            tripDurationDays: 0,
            flexibilityDays: 0
        )
        let candidates = RoundTripShapeSearch.candidates( for: search )

        #expect( candidates.count == 1 )
        #expect( candidates.first?.returnDate == Self.utcDate( 2026, 10, 6 ) )
    }

    @Test( "mustIncludeWeekend drops candidates whose span has no Saturday/Sunday" )
    func candidatesMustIncludeWeekend()
    {
        // Oct 5-9 2026 are Mon-Fri; only a 1-night trip departing Fri Oct 9 reaches Sat Oct 10.
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 9 ),
            tripDurationDays: 1,
            flexibilityDays: 0,
            mustIncludeWeekend: true
        )
        let candidates = RoundTripShapeSearch.candidates( for: search )

        #expect( candidates.count == 1 )
        #expect( candidates.first?.departure == Self.utcDate( 2026, 10, 9 ) )
        #expect( candidates.first?.returnDate == Self.utcDate( 2026, 10, 10 ) )
    }

    @Test( "A reversed date range is normalized" )
    func candidatesReversedRange()
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 7 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )
        let candidates = RoundTripShapeSearch.candidates( for: search )

        #expect( candidates.count == 3 )
    }

    // MARK: - sample(_:cap:)

    @Test( "Returns everything when under the cap" )
    func sampleUnderCap()
    {
        let candidates = ( 0 ..< 5 ).map { RoundTripShapeSearch.Candidate( departure: Self.utcDate( 2026, 10, 1 + $0 ), returnDate: Self.utcDate( 2026, 10, 4 + $0 ) ) }
        #expect( RoundTripShapeSearch.sample( candidates, cap: 10 ) == candidates )
    }

    @Test( "Samples evenly across the range, keeping the first and last" )
    func sampleOverCap()
    {
        let candidates = ( 0 ..< 10 ).map { RoundTripShapeSearch.Candidate( departure: Self.utcDate( 2026, 10, 1 + $0 ), returnDate: Self.utcDate( 2026, 10, 4 + $0 ) ) }
        let sampled = RoundTripShapeSearch.sample( candidates, cap: 4 )

        #expect( sampled == [ candidates[ 0 ], candidates[ 3 ], candidates[ 6 ], candidates[ 9 ] ] )
    }

    @Test( "A cap of 1 returns just the first candidate" )
    func sampleCapOfOne()
    {
        let candidates = ( 0 ..< 5 ).map { RoundTripShapeSearch.Candidate( departure: Self.utcDate( 2026, 10, 1 + $0 ), returnDate: Self.utcDate( 2026, 10, 4 + $0 ) ) }
        #expect( RoundTripShapeSearch.sample( candidates, cap: 1 ) == [ candidates[ 0 ] ] )
    }

    @Test( "A cap of zero, or an empty list, returns nothing" )
    func sampleEmpty()
    {
        let candidates = [ RoundTripShapeSearch.Candidate( departure: Self.utcDate( 2026, 10, 1 ), returnDate: Self.utcDate( 2026, 10, 4 ) ) ]
        #expect( RoundTripShapeSearch.sample( candidates, cap: 0 ) == [] )
        #expect( RoundTripShapeSearch.sample( [], cap: 5 ) == [] )
    }

    // MARK: - run(for:apiKey:...)

    @Test( "A single candidate produces one itinerary and one call" )
    func runSingleCandidate() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )
        let log = FetchLog()
        let ( mockResponse, mockRaw ) = try Self.fares( [ ( id: "AB1", amount: 500 ) ] )

        let result = await RoundTripShapeSearch.run( for: search, apiKey: "key" )
        { request in
            log.record( request )
            return ( mockResponse, mockRaw )
        }

        #expect( result.requestCount == 1 )
        #expect( result.itineraries.count == 1 )
        #expect( result.itineraries.first?.ignav_id == "AB1" )
        #expect( result.rawJSON == mockRaw )
        #expect( result.errorMessage == nil )
        #expect( log.requests.count == 1 )
        #expect( log.requests.first?.origin == "GVA" )
        #expect( log.requests.first?.destination == "LIS" )
    }

    @Test( "Aggregates, sorts by price, and keeps the raw JSON of the cheapest response" )
    func runSortsAndTracksCheapest() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 7 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )
        let prices: [ Double ] = [ 700, 500, 600 ]
        var callIndex = 0

        let result = await RoundTripShapeSearch.run( for: search, apiKey: "key" )
        { _ in
            let ( response, raw ) = try Self.fares( [ ( id: "id\( callIndex )", amount: prices[ callIndex ] ) ] )
            callIndex += 1
            return ( response, raw )
        }

        #expect( result.requestCount == 3 )
        #expect( result.itineraries.map( \.price.amount ) == [ 500, 600, 700 ] )
        #expect( result.rawJSON?.contains( "500" ) == true )
    }

    @Test( "Deduplicates itineraries sharing the same ignav_id" )
    func runDeduplicates() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 6 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )

        let result = await RoundTripShapeSearch.run( for: search, apiKey: "key" )
        { _ in
            try Self.fares( [ ( id: "DUP1", amount: 400 ) ] )
        }

        #expect( result.requestCount == 2 )
        #expect( result.itineraries.count == 1 )
    }

    @Test( "Never fires more calls than the cap, even with many candidates" )
    func runRespectsCap() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 1 ),
            rangeEnd: Self.utcDate( 2026, 10, 10 ),
            tripDurationDays: 3,
            flexibilityDays: 2
        )
        let log = FetchLog()

        let result = await RoundTripShapeSearch.run( for: search, apiKey: "key", cap: 2 )
        { request in
            log.record( request )
            return try Self.fares( [ ( id: "X", amount: 100 ) ] )
        }

        #expect( result.requestCount == 2 )
        #expect( log.requests.count == 2 )
    }

    @Test( "A failed candidate call doesn't prevent aggregating the rest" )
    func runToleratesPartialFailure() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 6 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )
        var callIndex = 0

        let result = await RoundTripShapeSearch.run( for: search, apiKey: "key" )
        { _ in
            defer { callIndex += 1 }
            if callIndex == 0
            {
                throw StubError()
            }
            return try Self.fares( [ ( id: "OK1", amount: 400 ) ] )
        }

        #expect( result.requestCount == 2 )
        #expect( result.itineraries.count == 1 )
        #expect( result.errorMessage == nil )
    }

    @Test( "Surfaces an error message when every candidate call fails" )
    func runSurfacesErrorWhenAllFail() async
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )

        let result = await RoundTripShapeSearch.run( for: search, apiKey: "key" )
        { _ in
            throw StubError()
        }

        #expect( result.itineraries.isEmpty )
        #expect( result.errorMessage == "stub network failure" )
        #expect( result.requestCount == 1 )
    }

    // MARK: - Progress reporting

    @Test( "Progress is reported up front, then once per candidate" )
    func runReportsProgress() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 7 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )
        let progress = ProgressLog()

        // Recorded as each request starts, so the emissions are pinned as interleaved with the
        // requests rather than merely arriving in the right order once the search is over.
        var emissionCountsAtRequest: [ Int ] = []

        let result = await RoundTripShapeSearch.run(
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

    @Test( "A failed candidate still advances progress" )
    func runReportsProgressForFailedCandidates() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 6 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )
        let progress  = ProgressLog()
        var callIndex = 0

        let result = await RoundTripShapeSearch.run(
            for: search,
            apiKey: "key",
            fetch: { _ in
                defer { callIndex += 1 }
                if callIndex == 0
                {
                    throw StubError()
                }
                return try Self.fares( [ ( id: "OK\( callIndex )", amount: 100 ) ] )
            },
            onProgress: { progress.record( $0 ) }
        )

        #expect( result.requestCount == 2 )
        // Each call returns its own ignav_id, so a lone itinerary witnesses that the first threw —
        // had it succeeded, both would have survived deduplication.
        #expect( result.itineraries.count == 1 )
        #expect( result.itineraries.first?.ignav_id == "OK1" )
        #expect( progress.emissions.map( \.completed ) == [ 0, 1, 2 ] )
    }

    @Test( "Progress counts the sampled candidates, not every combination" )
    func runReportsProgressAgainstTheCap() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 1 ),
            rangeEnd: Self.utcDate( 2026, 10, 10 ),
            tripDurationDays: 3,
            flexibilityDays: 2
        )
        let progress = ProgressLog()

        let result = await RoundTripShapeSearch.run(
            for: search,
            apiKey: "key",
            cap: 2,
            fetch: { _ in try Self.fares( [ ( id: "X", amount: 100 ) ] ) },
            onProgress: { progress.record( $0 ) }
        )

        #expect( result.requestCount == 2 )
        #expect( progress.emissions.map( \.completed ) == [ 0, 1, 2 ] )
        #expect( progress.emissions.allSatisfy { $0.total == 2 } )
    }

    @Test( "A search with nothing to do reports nothing planned" )
    func runReportsEmptyProgress() async
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 8 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )
        let progress = ProgressLog()

        let result = await RoundTripShapeSearch.run(
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
