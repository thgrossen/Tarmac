/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "SearchRunner" )
struct SearchRunnerTests
{
    private static func utcDate( _ year: Int, _ month: Int, _ day: Int ) -> Date
    {
        var calendar      = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        let components    = DateComponents( year: year, month: month, day: day )
        return calendar.date( from: components )!
    }

    private static func makeOneWaySearch( directOnly: Bool = true ) -> SavedSearch
    {
        SavedSearch(
            kind: .oneWay,
            origin: "gva",
            destination: "lis",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "business",
            directOnly: directOnly
        )
    }

    private static func makeRoundTripSearch(
        rangeStart: Date = Self.utcDate( 2026, 10, 5 ),
        rangeEnd: Date = Self.utcDate( 2026, 10, 5 ),
        tripDurationDays: Int = 3,
        flexibilityDays: Int = 0
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
            flexibilityDays: flexibilityDays
        )
    }

    private static func fares( itineraries json: String ) throws -> ( FaresResponse, String )
    {
        let data     = "{ \"itineraries\": [ \( json ) ] }".data( using: .utf8 )!
        let response = try JSONDecoder().decode( FaresResponse.self, from: data )
        return ( response, String( data: data, encoding: .utf8 )! )
    }

    private static func freshDefaults() -> UserDefaults
    {
        UserDefaults( suiteName: "SearchRunnerTests.\( UUID().uuidString )" )!
    }

    private struct StubError: LocalizedError
    {
        var errorDescription: String? { "stub network failure" }
    }

    private final class FetchLog< Body >
    {
        private( set ) var requests: [ Body ] = []
        func record( _ request: Body )
        {
            self.requests.append( request )
        }
    }

    // MARK: - One-way dispatch

    @Test( "Dispatches a one-way search to a single call, using the range's earliest date" )
    func oneWayDispatchesSingleCall() async throws
    {
        let search   = Self.makeOneWaySearch( directOnly: true )
        let log      = FetchLog< OneWayRequest >()
        let defaults = Self.freshDefaults()
        let ( response, raw ) = try Self.fares( itineraries: """
            { "ignav_id": "AB1", "price": { "amount": 350, "currency": "CHF" },
              "outbound": { "carrier": "SWISS", "duration_minutes": 155,
                "segments": [ { "carrier_code": "LX", "marketing_carrier_code": "LX", "flight_number": "123",
                  "departure_time_local": "2026-10-05T08:00:00", "arrival_time_local": "2026-10-05T10:35:00" } ] } }
            """ )

        let run = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: defaults,
            oneWayFetch: { request in
                log.record( request )
                return ( response, raw )
            }
        )

        #expect( log.requests.count == 1 )
        #expect( log.requests.first?.origin == "GVA" )
        #expect( log.requests.first?.destination == "LIS" )
        #expect( log.requests.first?.departure_date == "2026-10-05" )
        #expect( log.requests.first?.cabin_class == "business" )
        #expect( log.requests.first?.max_stops == 0 )
        #expect( log.requests.first?.market == "CH" )

        #expect( run.requestCount == 1 )
        #expect( run.rawJSON == raw )
        #expect( run.errorMessage == nil )
        #expect( run.savedSearch === search )
        #expect( search.runs.count == 1 )
        #expect( search.runs.first === run )

        #expect( run.itineraries.count == 1 )
        #expect( run.itineraries.first?.amount == 350 )
        #expect( run.itineraries.first?.currency == "CHF" )
        #expect( run.itineraries.first?.ignavID == "AB1" )
        #expect( run.itineraries.first?.outboundSummary == "LX 123" )
        #expect( run.itineraries.first?.outboundDuration == "2h35" )
        #expect( run.itineraries.first?.carrier == "SWISS" )
        #expect( run.itineraries.first?.departureTime == "08:00" )
        #expect( run.itineraries.first?.arrivalTime == "10:35" )
        #expect( run.itineraries.first?.inboundSummary == nil )
        #expect( run.itineraries.first?.run === run )
    }

    @Test( "Sorts one-way itineraries by price" )
    func oneWaySortsByPrice() async throws
    {
        let search = Self.makeOneWaySearch()
        let ( response, raw ) = try Self.fares( itineraries: """
            { "ignav_id": "EXP", "price": { "amount": 900, "currency": "CHF" } },
            { "ignav_id": "CHP", "price": { "amount": 300, "currency": "CHF" } },
            { "ignav_id": "MID", "price": { "amount": 600, "currency": "CHF" } }
            """ )

        let run = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: Self.freshDefaults(),
            oneWayFetch: { _ in ( response, raw ) }
        )

        #expect( run.itineraries.map( \.amount ) == [ 300, 600, 900 ] )
    }

    @Test( "Uses max_stops 2 when direct-only is off" )
    func oneWayAllowsStops() async throws
    {
        let search = Self.makeOneWaySearch( directOnly: false )
        let log    = FetchLog< OneWayRequest >()
        let ( response, raw ) = try Self.fares( itineraries: "" )

        _ = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: Self.freshDefaults(),
            oneWayFetch: { request in
                log.record( request )
                return ( response, raw )
            }
        )

        #expect( log.requests.first?.max_stops == 2 )
    }

    @Test( "Reads the airline restriction from the injected UserDefaults suite" )
    func oneWayReadsAirlinePreference() async throws
    {
        let search   = Self.makeOneWaySearch()
        let log      = FetchLog< OneWayRequest >()
        let defaults = Self.freshDefaults()
        defaults.set( false, forKey: AirlinePreference.restrictAirlinesDefaultsKey )
        let ( response, raw ) = try Self.fares( itineraries: "" )

        _ = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: defaults,
            oneWayFetch: { request in
                log.record( request )
                return ( response, raw )
            }
        )

        #expect( log.requests.first?.airlines_include == nil )
    }

    @Test( "Reads the market preference from the injected UserDefaults suite" )
    func oneWayReadsMarketPreference() async throws
    {
        let search   = Self.makeOneWaySearch()
        let log      = FetchLog< OneWayRequest >()
        let defaults = Self.freshDefaults()
        defaults.set( "US", forKey: MarketPreference.marketDefaultsKey )
        let ( response, raw ) = try Self.fares( itineraries: "" )

        _ = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: defaults,
            oneWayFetch: { request in
                log.record( request )
                return ( response, raw )
            }
        )

        #expect( log.requests.first?.market == "US" )
    }

    @Test( "An empty one-way result surfaces the no-fares message but keeps the raw JSON" )
    func oneWayEmptyResultSurfacesMessage() async throws
    {
        let search = Self.makeOneWaySearch()
        let ( response, raw ) = try Self.fares( itineraries: "" )

        let run = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: Self.freshDefaults(),
            oneWayFetch: { _ in ( response, raw ) }
        )

        #expect( run.itineraries.isEmpty )
        #expect( run.rawJSON == raw )
        #expect( run.errorMessage == "No flights for these filters (request valid… and billed)." )
        #expect( run.requestCount == 1 )
    }

    @Test( "A failed one-way call surfaces the error and stores no raw JSON" )
    func oneWayFailureSurfacesError() async
    {
        let search = Self.makeOneWaySearch()

        let run = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: Self.freshDefaults(),
            oneWayFetch: { _ in throw StubError() }
        )

        #expect( run.itineraries.isEmpty )
        #expect( run.rawJSON == nil )
        #expect( run.errorMessage == "stub network failure" )
        #expect( run.requestCount == 1 )
        #expect( search.runs.count == 1 )
    }

    // MARK: - Round-trip dispatch

    @Test( "Dispatches a round-trip search to the shape-search runner, forwarding cap and defaults" )
    func roundTripDispatchesShapeSearch() async throws
    {
        let search = Self.makeRoundTripSearch(
            rangeStart: Self.utcDate( 2026, 10, 1 ),
            rangeEnd: Self.utcDate( 2026, 10, 3 ),
            tripDurationDays: 3,
            flexibilityDays: 0
        )
        let log      = FetchLog< RoundTripRequest >()
        let defaults = Self.freshDefaults()
        defaults.set( false, forKey: AirlinePreference.restrictAirlinesDefaultsKey )
        defaults.set( "FR", forKey: MarketPreference.marketDefaultsKey )

        let run = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: defaults,
            cap: 2,
            roundTripFetch: { request in
                log.record( request )
                return try Self.fares( itineraries: """
                    { "ignav_id": "RT\( log.requests.count )", "price": { "amount": 400, "currency": "CHF" } }
                    """ )
            }
        )

        #expect( log.requests.count == 2 )
        #expect( log.requests.first?.airlines_include == nil )
        #expect( log.requests.first?.market == "FR" )
        #expect( run.requestCount == 2 )
        #expect( run.itineraries.count == 2 )
        #expect( run.savedSearch === search )
        #expect( search.runs.first === run )
    }

    @Test( "An empty round-trip result (no underlying error) surfaces the no-fares message" )
    func roundTripEmptyResultSurfacesMessage() async throws
    {
        let search = Self.makeRoundTripSearch()

        let run = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: Self.freshDefaults(),
            roundTripFetch: { _ in try Self.fares( itineraries: "" ) }
        )

        #expect( run.itineraries.isEmpty )
        #expect( run.errorMessage == "No flights for these filters (request valid… and billed)." )
    }

    @Test( "A round-trip shape-search failure is forwarded as-is, not overridden by the no-fares message" )
    func roundTripFailureForwardsUnderlyingError() async
    {
        let search = Self.makeRoundTripSearch()

        let run = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: Self.freshDefaults(),
            roundTripFetch: { _ in throw StubError() }
        )

        #expect( run.itineraries.isEmpty )
        #expect( run.errorMessage == "stub network failure" )
    }

    @Test( "Maps outbound and inbound leg segments into the stored snapshot" )
    func roundTripMapsLegSummaries() async throws
    {
        let search = Self.makeRoundTripSearch()

        let run = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: Self.freshDefaults(),
            roundTripFetch: { _ in
                try Self.fares( itineraries: """
                    { "ignav_id": "RT1", "price": { "amount": 900, "currency": "CHF" },
                      "outbound": { "carrier": "SWISS", "duration_minutes": 300,
                        "segments": [
                          { "carrier_code": "LX", "flight_number": "100",
                            "departure_time_local": "2026-10-05T06:00:00", "arrival_time_local": "2026-10-05T08:00:00" },
                          { "carrier_code": "TP", "flight_number": "200",
                            "departure_time_local": "2026-10-05T09:00:00", "arrival_time_local": "2026-10-05T11:00:00" }
                        ] },
                      "inbound": { "segments": [ { "carrier_code": "TP", "flight_number": "201" } ] } }
                    """ )
            }
        )

        let snapshot = try #require( run.itineraries.first )
        #expect( snapshot.outboundSummary == "LX 100 → TP 200" )
        #expect( snapshot.inboundSummary == "TP 201" )
        #expect( snapshot.outboundDuration == "5h00" )
        #expect( snapshot.carrier == "SWISS" )
        #expect( snapshot.departureTime == "06:00" )
        #expect( snapshot.arrivalTime == "11:00" )
        #expect( snapshot.run === run )
    }

    @Test( "Prefers marketing_carrier_code over carrier_code when both are present" )
    func legSummaryPrefersMarketingCarrierCode() async throws
    {
        let search = Self.makeOneWaySearch()

        let run = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: Self.freshDefaults(),
            oneWayFetch: { _ in
                try Self.fares( itineraries: """
                    { "ignav_id": "MK1", "price": { "amount": 250, "currency": "CHF" },
                      "outbound": { "segments": [
                        { "carrier_code": "XX", "marketing_carrier_code": "LX", "flight_number": "789" }
                      ] } }
                    """ )
            }
        )

        #expect( run.itineraries.first?.outboundSummary == "LX 789" )
    }

    @Test( "An itinerary with no leg data maps to nil summaries" )
    func mapsMissingLegDataToNil() async throws
    {
        let search = Self.makeOneWaySearch()

        let run = await SearchRunner.run(
            for: search,
            apiKey: "key",
            defaults: Self.freshDefaults(),
            oneWayFetch: { _ in
                try Self.fares( itineraries: """
                    { "ignav_id": "NL1", "price": { "amount": 200, "currency": "CHF" } }
                    """ )
            }
        )

        let snapshot = try #require( run.itineraries.first )
        #expect( snapshot.outboundSummary == nil )
        #expect( snapshot.inboundSummary == nil )
        #expect( snapshot.outboundDuration == nil )
    }
}
