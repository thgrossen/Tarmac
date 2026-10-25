/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "SearchPrefill" )
struct SearchPrefillTests
{
    private static func utcDate( _ year: Int, _ month: Int, _ day: Int ) -> Date
    {
        var calendar = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        return calendar.date( from: DateComponents( year: year, month: month, day: day ) )!
    }

    private static func makeSearch(
        kind: SearchKind = .oneWay,
        isSeeded: Bool = false,
        origin: String = "GVA",
        destination: String = "LIS",
        rangeStart: Date = .now,
        rangeEnd: Date = .now,
        cabinClass: String = "economy",
        directOnly: Bool = false,
        carryOnIncluded: Bool = true,
        checkedBagIncluded: Bool = true,
        passengers: Int = 2,
        tripDurationDays: Int = 7,
        flexibilityDays: Int = 2,
        mustIncludeWeekend: Bool = true
    ) -> SavedSearch
    {
        SavedSearch(
            isSeeded: isSeeded,
            kind: kind,
            origin: origin,
            destination: destination,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            cabinClass: cabinClass,
            directOnly: directOnly,
            carryOnIncluded: carryOnIncluded,
            checkedBagIncluded: checkedBagIncluded,
            passengers: passengers,
            tripDurationDays: tripDurationDays,
            flexibilityDays: flexibilityDays,
            mustIncludeWeekend: mustIncludeWeekend
        )
    }

    @Test( "Shared fields are empty/default with no previous search" )
    func sharedFieldsWithNoPreviousSearch()
    {
        let fields = SearchPrefill.sharedFields( from: nil )

        #expect( fields.origin == "" )
        #expect( fields.destination == "" )
        #expect( fields.cabinClass == SearchPrefill.defaultCabinClass )
        #expect( fields.directOnly == SearchPrefill.defaultDirectOnly )
        #expect( fields.carryOnIncluded == SearchPrefill.defaultCarryOnIncluded )
        #expect( fields.checkedBagIncluded == SearchPrefill.defaultCheckedBagIncluded )
        #expect( fields.passengers == SearchPrefill.defaultPassengers )
    }

    @Test( "Shared fields copy the most recent search's values" )
    func sharedFieldsFromMostRecentSearch()
    {
        let fields = SearchPrefill.sharedFields( from: Self.makeSearch() )

        #expect( fields.origin == "GVA" )
        #expect( fields.destination == "LIS" )
        #expect( fields.cabinClass == "economy" )
        #expect( fields.directOnly == false )
        #expect( fields.carryOnIncluded == true )
        #expect( fields.checkedBagIncluded == true )
        #expect( fields.passengers == 2 )
    }

    @Test( "Direct flights only prefills in both directions, not just when it is off" )
    func sharedFieldsCarryDirectOnlyBothWays()
    {
        let restricted = Self.makeSearch( kind: .roundTrip, directOnly: true )
        let open       = Self.makeSearch( kind: .roundTrip, directOnly: false )

        #expect( restricted.directOnly == true )
        #expect( SearchPrefill.sharedFields( from: restricted ).directOnly == true )
        #expect( open.directOnly == false )
        #expect( SearchPrefill.sharedFields( from: open ).directOnly == false )
    }

    @Test( "Round-trip fields fall back to hardcoded defaults with no previous round-trip search" )
    func roundTripFieldsWithNoPreviousRoundTrip()
    {
        let fields = SearchPrefill.roundTripFields( from: nil )

        #expect( fields.tripDurationDays == SearchPrefill.defaultTripDurationDays )
        #expect( fields.flexibilityDays == SearchPrefill.defaultFlexibilityDays )
        #expect( fields.mustIncludeWeekend == SearchPrefill.defaultMustIncludeWeekend )
    }

    @Test( "Round-trip fields copy the most recent round-trip search's values" )
    func roundTripFieldsFromMostRecentRoundTrip()
    {
        let fields = SearchPrefill.roundTripFields( from: Self.makeSearch( kind: .roundTrip ) )

        #expect( fields.tripDurationDays == 7 )
        #expect( fields.flexibilityDays == 2 )
        #expect( fields.mustIncludeWeekend == true )
    }

    @Test( "Most recent round trip skips a newer one-way search" )
    func mostRecentRoundTripSkipsNewerOneWay()
    {
        let olderRoundTrip = Self.makeSearch( kind: .roundTrip, tripDurationDays: 5 )
        let newerOneWay    = Self.makeSearch( kind: .oneWay )
        let searches       = [ newerOneWay, olderRoundTrip ]

        let result = SearchPrefill.mostRecentRoundTrip( in: searches )
        #expect( result === olderRoundTrip )
    }

    @Test( "Most recent round trip is nil when none exists" )
    func mostRecentRoundTripWithNoRoundTrip()
    {
        let searches = [ Self.makeSearch( kind: .oneWay ), Self.makeSearch( kind: .oneWay ) ]

        #expect( SearchPrefill.mostRecentRoundTrip( in: searches ) == nil )
    }

    @Test( "Most recent round trip is nil for an empty array" )
    func mostRecentRoundTripWithEmptyArray()
    {
        #expect( SearchPrefill.mostRecentRoundTrip( in: [] ) == nil )
    }

    @Test( "Most recent round trip picks the newest of several round-trip candidates" )
    func mostRecentRoundTripPicksNewestAmongSeveral()
    {
        let newerRoundTrip = Self.makeSearch( kind: .roundTrip, tripDurationDays: 9 )
        let olderRoundTrip = Self.makeSearch( kind: .roundTrip, tripDurationDays: 5 )
        let someOneWay     = Self.makeSearch( kind: .oneWay )
        let searches       = [ newerRoundTrip, olderRoundTrip, someOneWay ]

        let result = SearchPrefill.mostRecentRoundTrip( in: searches )
        #expect( result === newerRoundTrip )
    }

    @Test( "Most recent round trip skips a seeded round-trip search" )
    func mostRecentRoundTripSkipsSeeded()
    {
        let seededRoundTrip = Self.makeSearch( kind: .roundTrip, isSeeded: true )
        let realRoundTrip   = Self.makeSearch( kind: .roundTrip, isSeeded: false, tripDurationDays: 4 )
        let searches        = [ seededRoundTrip, realRoundTrip ]

        let result = SearchPrefill.mostRecentRoundTrip( in: searches )
        #expect( result === realRoundTrip )
    }

    @Test( "Most recent round trip is nil when only a seeded round trip exists" )
    func mostRecentRoundTripWithOnlySeeded()
    {
        let searches = [ Self.makeSearch( kind: .roundTrip, isSeeded: true ) ]

        #expect( SearchPrefill.mostRecentRoundTrip( in: searches ) == nil )
    }

    @Test( "Most recent one-way skips a newer round trip and a seeded one-way" )
    func mostRecentOneWaySkipsRoundTripsAndSeeded()
    {
        let newerRoundTrip = Self.makeSearch( kind: .roundTrip )
        let seededOneWay   = Self.makeSearch( kind: .oneWay, isSeeded: true )
        let realOneWay     = Self.makeSearch( kind: .oneWay, origin: "ZRH" )
        let searches       = [ newerRoundTrip, seededOneWay, realOneWay ]

        let result = SearchPrefill.mostRecentOneWay( in: searches )
        #expect( result === realOneWay )
    }

    @Test( "Most recent one-way is nil when only round trips exist" )
    func mostRecentOneWayWithNoOneWay()
    {
        let searches = [ Self.makeSearch( kind: .roundTrip ) ]

        #expect( SearchPrefill.mostRecentOneWay( in: searches ) == nil )
    }

    @Test( "Dates fall back to the default window with no previous search" )
    func dateRangeWithNoPreviousSearch()
    {
        let reference = Self.utcDate( 2026, 10, 25 )

        #expect( SearchPrefill.dateRange( from: nil, referenceDate: reference ) == DepartureDateDefaults.defaultRange( referenceDate: reference ) )
    }

    @Test( "Dates copy the previous search's earliest and latest departure" )
    func dateRangeFromPreviousSearch()
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 27 ), rangeEnd: Self.utcDate( 2026, 12, 26 ) )
        let range  = SearchPrefill.dateRange( from: search, referenceDate: Self.utcDate( 2026, 10, 25 ) )

        #expect( range.start == Self.utcDate( 2026, 10, 27 ) )
        #expect( range.end == Self.utcDate( 2026, 12, 26 ) )
    }

    @Test( "Copied dates that have gone by start tomorrow instead" )
    func dateRangeFromPastSearchStartsTomorrow()
    {
        let search = Self.makeSearch( rangeStart: Self.utcDate( 2026, 10, 20 ), rangeEnd: Self.utcDate( 2026, 11, 10 ) )
        let range  = SearchPrefill.dateRange( from: search, referenceDate: Self.utcDate( 2026, 10, 25 ) )

        #expect( range.start == Self.utcDate( 2026, 10, 26 ) )
        #expect( range.end == Self.utcDate( 2026, 11, 10 ) )
    }

    @Test( "Most recent real search skips a seeded search" )
    func mostRecentRealSkipsSeeded()
    {
        let seeded = Self.makeSearch( isSeeded: true )
        let real   = Self.makeSearch( isSeeded: false, origin: "ZRH" )
        let searches = [ seeded, real ]

        let result = SearchPrefill.mostRecentReal( in: searches )
        #expect( result === real )
    }

    @Test( "Most recent real search is nil when only a seeded search exists" )
    func mostRecentRealWithOnlySeeded()
    {
        let searches = [ Self.makeSearch( isSeeded: true ) ]

        #expect( SearchPrefill.mostRecentReal( in: searches ) == nil )
    }

    @Test( "Most recent real search is nil for an empty array" )
    func mostRecentRealWithEmptyArray()
    {
        #expect( SearchPrefill.mostRecentReal( in: [] ) == nil )
    }
}
