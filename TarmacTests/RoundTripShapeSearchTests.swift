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
        mustIncludeWeekend: Bool = false,
        origin: String = "GVA",
        destination: String = "LIS",
        cabinClass: String = "business",
        directOnly: Bool = true,
        carryOnIncluded: Bool = false,
        checkedBagIncluded: Bool = false
    ) -> SavedSearch
    {
        SavedSearch(
            kind: .roundTrip,
            origin: origin,
            destination: destination,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            cabinClass: cabinClass,
            directOnly: directOnly,
            carryOnIncluded: carryOnIncluded,
            checkedBagIncluded: checkedBagIncluded,
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

    @Test( "Flexibility widens the trip duration, never the departure range" )
    func candidatesKeepDeparturesInsideTheRange()
    {
        let rangeStart = Self.utcDate( 2026, 10, 5 )
        let rangeEnd   = Self.utcDate( 2026, 10, 12 )
        let search     = Self.makeSearch(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            tripDurationDays: 3,
            flexibilityDays: 10
        )
        let candidates = RoundTripShapeSearch.candidates( for: search )

        // 8 departure days × 13 durations (3 nights, ±10 clamped to 1…13).
        #expect( candidates.count == 104 )
        #expect( Set( candidates.map( \.departure ) ).count == 8 )
        #expect( candidates.allSatisfy { ( rangeStart ... rangeEnd ).contains( $0.departure ) } )
        #expect( candidates.map( \.departure ).min() == rangeStart )
        #expect( candidates.map( \.departure ).max() == rangeEnd )

        // Flexibility of 10 against a 3-night trip stretches the return well past the departure
        // range, which is the point: only the departure side is bounded.
        #expect( candidates.map( \.returnDate ).max() == Self.utcDate( 2026, 10, 25 ) )
    }

    @Test( "Every departure × duration combination appears exactly once" )
    func candidatesCoverEveryPairExactlyOnce()
    {
        // 7 departure days (5–11 October) × 5 durations (4 nights, ±2 → 2…6).
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 11 ),
            tripDurationDays: 4,
            flexibilityDays: 2
        )
        let candidates = RoundTripShapeSearch.candidates( for: search )
        let expected   = Set( ( 5 ... 11 ).flatMap
        { day in
            ( 2 ... 6 ).map { [ Self.utcDate( 2026, 10, day ), Self.utcDate( 2026, 10, day + $0 ) ] }
        } )

        // Counted as well as compared, so a duplicate pair can't hide inside a matching set.
        #expect( candidates.count == 35 )
        #expect( Set( candidates.map { candidate in [ candidate.departure, candidate.returnDate ] } ) == expected )

        // Departure-major, duration-minor. The order is load-bearing: sample( _:cap: ) keeps evenly
        // spaced entries, so swapping the two loops would change which pairs a capped sweep bills for.
        #expect( candidates.map( \.departure ) == ( 5 ... 11 ).flatMap
        { day in
            Array( repeating: Self.utcDate( 2026, 10, day ), count: 5 )
        } )
        #expect( candidates.map( \.returnDate ) == ( 5 ... 11 ).flatMap
        { day in
            ( 2 ... 6 ).map { Self.utcDate( 2026, 10, day + $0 ) }
        } )
    }

    @Test( "The weekend rule keeps exactly Fri→Sat, Sat→Sun and Sun→Mon over a full week" )
    func candidatesWeekendWorkedExample()
    {
        // Mon 5 → Sun 11 October 2026, one night, no flexibility. Counting the return day, only
        // Fri→Sat, Sat→Sun and Sun→Mon touch a weekend.
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 11 ),
            tripDurationDays: 1,
            flexibilityDays: 0,
            mustIncludeWeekend: true
        )
        let candidates = RoundTripShapeSearch.candidates( for: search )

        #expect( candidates == [
            RoundTripShapeSearch.Candidate( departure: Self.utcDate( 2026, 10,  9 ), returnDate: Self.utcDate( 2026, 10, 10 ) ),
            RoundTripShapeSearch.Candidate( departure: Self.utcDate( 2026, 10, 10 ), returnDate: Self.utcDate( 2026, 10, 11 ) ),
            RoundTripShapeSearch.Candidate( departure: Self.utcDate( 2026, 10, 11 ), returnDate: Self.utcDate( 2026, 10, 12 ) )
        ] )

        // Mon→Tue and Tue→Wed never reach a weekend day.
        #expect( candidates.contains( .init( departure: Self.utcDate( 2026, 10, 5 ), returnDate: Self.utcDate( 2026, 10, 6 ) ) ) == false )
        #expect( candidates.contains( .init( departure: Self.utcDate( 2026, 10, 6 ), returnDate: Self.utcDate( 2026, 10, 7 ) ) ) == false )
    }

    @Test( "A multi-night trip qualifies whenever its span reaches a weekend day" )
    func candidatesWeekendMultiNight()
    {
        // Mon 5 → Fri 9 October 2026, three nights: Wed→Sat, Thu→Sun and Fri→Mon reach the
        // weekend, while Mon→Thu and Tue→Fri stay inside the working week.
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 9 ),
            tripDurationDays: 3,
            flexibilityDays: 0,
            mustIncludeWeekend: true
        )
        let candidates = RoundTripShapeSearch.candidates( for: search )

        #expect( candidates == [
            RoundTripShapeSearch.Candidate( departure: Self.utcDate( 2026, 10, 7 ), returnDate: Self.utcDate( 2026, 10, 10 ) ),
            RoundTripShapeSearch.Candidate( departure: Self.utcDate( 2026, 10, 8 ), returnDate: Self.utcDate( 2026, 10, 11 ) ),
            RoundTripShapeSearch.Candidate( departure: Self.utcDate( 2026, 10, 9 ), returnDate: Self.utcDate( 2026, 10, 12 ) )
        ] )
    }

    @Test( "The weekend rule is applied per pair, keeping only the durations that reach a weekend" )
    func candidatesWeekendFiltersWithinOneDeparture()
    {
        // One departure, Mon 5 October 2026, with durations 1…5 (3 nights, ±2): the returns land on
        // Tue, Wed, Thu, Fri and Sat, so only the longest pair touches a weekend.
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            tripDurationDays: 3,
            flexibilityDays: 2,
            mustIncludeWeekend: true
        )
        let candidates = RoundTripShapeSearch.candidates( for: search )

        #expect( candidates == [
            RoundTripShapeSearch.Candidate( departure: Self.utcDate( 2026, 10, 5 ), returnDate: Self.utcDate( 2026, 10, 10 ) )
        ] )
    }

    @Test( "A range where no pair reaches a weekend yields nothing at all" )
    func candidatesWeekendYieldsNothing()
    {
        // Mon 5 → Tue 6 October 2026, one night: Mon→Tue and Tue→Wed, neither touching a weekend.
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 6 ),
            tripDurationDays: 1,
            flexibilityDays: 0,
            mustIncludeWeekend: true
        )

        #expect( RoundTripShapeSearch.candidates( for: search ).isEmpty )
    }

    @Test( "Flexibility wider than the duration clamps at one night instead of going negative" )
    func candidatesClampFlexibilityAtOneNight()
    {
        // 2 nights ±5 would span −3…7; the clamp makes it 1…7.
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            tripDurationDays: 2,
            flexibilityDays: 5
        )
        let candidates = RoundTripShapeSearch.candidates( for: search )

        #expect( candidates.count == 7 )
        #expect( candidates.map( \.returnDate ) == ( 6 ... 12 ).map { Self.utcDate( 2026, 10, $0 ) } )
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

    @Test( "Reports the full matrix as the candidate count while capping the request count" )
    func runCountsCandidatesBeforeCapping() async throws
    {
        // 10 departure days × 5 durations (3 days, ±2) = 50 candidates, capped to 2 requests.
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 1 ),
            rangeEnd: Self.utcDate( 2026, 10, 10 ),
            tripDurationDays: 3,
            flexibilityDays: 2
        )

        let result = await RoundTripShapeSearch.run( for: search, apiKey: "key", cap: 2 )
        { _ in
            try Self.fares( [ ( id: "X", amount: 100 ) ] )
        }

        #expect( result.candidateCount == 50 )
        #expect( result.requestCount == 2 )
    }

    @Test( "Reports equal candidate and request counts when the cap doesn't bite" )
    func runCountsMatchWhenUncapped() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 7 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )

        let result = await RoundTripShapeSearch.run( for: search, apiKey: "key", cap: 25 )
        { _ in
            try Self.fares( [ ( id: "X", amount: 100 ) ] )
        }

        #expect( result.candidateCount == 3 )
        #expect( result.requestCount == 3 )
    }

    @Test( "Counts the candidates that survive the weekend requirement, not the raw matrix" )
    func runCountsCandidatesAfterWeekendFiltering() async throws
    {
        // Mon 5 → Sun 11 October 2026, one night, no flexibility: 7 departure days, of which only
        // Fri→Sat, Sat→Sun and Sun→Mon cover a weekend day.
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 11 ),
            tripDurationDays: 1,
            flexibilityDays: 0,
            mustIncludeWeekend: true
        )

        let result = await RoundTripShapeSearch.run( for: search, apiKey: "key", cap: 2 )
        { _ in
            try Self.fares( [ ( id: "X", amount: 100 ) ] )
        }

        #expect( result.candidateCount == 3 )
        #expect( result.requestCount == 2 )
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

    // MARK: - Request body

    @Test( "Direct flights only sends max_stops 0 on every request" )
    func runDirectOnlySendsZeroMaxStops() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 7 ),
            tripDurationDays: 3,
            flexibilityDays: 1,
            directOnly: true
        )
        let log = FetchLog()

        _ = await RoundTripShapeSearch.run( for: search, apiKey: "key" )
        { request in
            log.record( request )
            return try Self.fares( [ ( id: "X", amount: 100 ) ] )
        }

        #expect( log.requests.count == 9 )
        #expect( log.requests.allSatisfy { $0.max_stops == 0 } )
    }

    @Test( "Clearing direct flights only sends max_stops 2 on every request" )
    func runIndirectSendsTwoMaxStops() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 7 ),
            tripDurationDays: 3,
            flexibilityDays: 1,
            directOnly: false
        )
        let log = FetchLog()

        _ = await RoundTripShapeSearch.run( for: search, apiKey: "key" )
        { request in
            log.record( request )
            return try Self.fares( [ ( id: "X", amount: 100 ) ] )
        }

        #expect( log.requests.count == 9 )
        #expect( log.requests.allSatisfy { $0.max_stops == 2 } )
    }

    @Test( "Every request carries the form's route, cabin and baggage requirements" )
    func runForwardsTheFormsFields() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 6 ),
            tripDurationDays: 2,
            flexibilityDays: 0,
            origin: "gva",
            destination: "lis",
            cabinClass: "first",
            directOnly: false,
            carryOnIncluded: true,
            checkedBagIncluded: false
        )
        let log = FetchLog()

        _ = await RoundTripShapeSearch.run( for: search, apiKey: "key" )
        { request in
            log.record( request )
            return try Self.fares( [ ( id: "X", amount: 100 ) ] )
        }

        #expect( log.requests.count == 2 )
        #expect( log.requests.allSatisfy { $0.max_stops == 2 } )
        #expect( log.requests.allSatisfy { $0.origin == "GVA" } )
        #expect( log.requests.allSatisfy { $0.destination == "LIS" } )
        #expect( log.requests.allSatisfy { $0.cabin_class == "first" } )
        // Asymmetric on purpose: with both flags sharing a value, a swapped mapping would pass.
        #expect( log.requests.allSatisfy { $0.min_carry_on_bags == 1 } )
        #expect( log.requests.allSatisfy { $0.min_checked_bags == nil } )
        #expect( log.requests.map( \.departure_date ) == [ "2026-10-05", "2026-10-06" ] )
        #expect( log.requests.map( \.return_date ) == [ "2026-10-07", "2026-10-08" ] )
    }

    @Test( "Baggage requirements are omitted rather than sent as zero when not required" )
    func runOmitsBaggageWhenNotRequired() async throws
    {
        let search = Self.makeSearch(
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            tripDurationDays: 2,
            flexibilityDays: 0,
            carryOnIncluded: false,
            checkedBagIncluded: false
        )
        let log = FetchLog()

        _ = await RoundTripShapeSearch.run( for: search, apiKey: "key" )
        { request in
            log.record( request )
            return try Self.fares( [ ( id: "X", amount: 100 ) ] )
        }

        #expect( log.requests.count == 1 )
        #expect( log.requests.first?.min_carry_on_bags == nil )
        #expect( log.requests.first?.min_checked_bags == nil )
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
