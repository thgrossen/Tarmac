/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData
@testable import Tarmac
import Testing

@Suite( "SavedSearch" )
struct SavedSearchTests
{
    private static func utcDate( _ year: Int, _ month: Int, _ day: Int, hour: Int = 0 ) -> Date
    {
        var calendar    = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        let components  = DateComponents( year: year, month: month, day: day, hour: hour )
        return calendar.date( from: components )!
    }

    private func makeInMemoryContext() throws -> ModelContext
    {
        let schema = Schema( [ SavedSearch.self ] )
        let config = ModelConfiguration( schema: schema, isStoredInMemoryOnly: true )
        let container = try ModelContainer( for: schema, configurations: [ config ] )
        return ModelContext( container )
    }

    private static func makeRoundTrip(
        cabinClass: String = "business",
        directOnly: Bool = false,
        carryOnIncluded: Bool = false,
        checkedBagIncluded: Bool = false,
        passengers: Int = 1,
        tripDurationDays: Int = 3,
        flexibilityDays: Int = 0,
        mustIncludeWeekend: Bool = false
    ) -> SavedSearch
    {
        SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
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

    // MARK: - nightsLabel(forNights:)

    @Test( "A one-night trip is singular" )
    func nightsLabelSingular()
    {
        #expect( SavedSearch.nightsLabel( forNights: 1 ) == "1 night" )
    }

    @Test( "Every other night count is plural" )
    func nightsLabelPlural()
    {
        #expect( SavedSearch.nightsLabel( forNights: 2 ) == "2 nights" )
        #expect( SavedSearch.nightsLabel( forNights: 30 ) == "30 nights" )
    }

    @Test( "Zero reads as plural, matching how English counts it" )
    func nightsLabelZero()
    {
        #expect( SavedSearch.nightsLabel( forNights: 0 ) == "0 nights" )
    }

    // MARK: - detailsSummary(for:)

    @Test( "A one-way search has no details summary" )
    func detailsSummaryIsRoundTripOnly()
    {
        let search = SavedSearch(
            kind: .oneWay,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "business"
        )

        #expect( SavedSearch.detailsSummary( for: search ) == nil )
    }

    @Test( "A plain round trip states its nights, cabin and passengers only" )
    func detailsSummaryOmitsEverythingUnset()
    {
        #expect( SavedSearch.detailsSummary( for: Self.makeRoundTrip() ) == "3 nights · business · 1 passenger" )
    }

    @Test( "Flexibility joins the night count rather than standing alone" )
    func detailsSummaryCarriesFlexibility()
    {
        let search = Self.makeRoundTrip( flexibilityDays: 2 )
        #expect( SavedSearch.detailsSummary( for: search ) == "3 nights ±2 · business · 1 passenger" )
    }

    @Test( "The weekend requirement appears only when it is on" )
    func detailsSummaryCarriesTheWeekendRequirement()
    {
        let search = Self.makeRoundTrip( mustIncludeWeekend: true )
        #expect( SavedSearch.detailsSummary( for: search ) == "3 nights · weekend · business · 1 passenger" )
    }

    @Test( "Direct flights appear only when the toggle is on" )
    func detailsSummaryCarriesDirectOnly()
    {
        let search = Self.makeRoundTrip( directOnly: true )
        #expect( SavedSearch.detailsSummary( for: search ) == "3 nights · direct · business · 1 passenger" )
    }

    @Test( "Each bag requirement appears independently" )
    func detailsSummaryCarriesBagRequirements()
    {
        let carryOn = Self.makeRoundTrip( carryOnIncluded: true )
        #expect( SavedSearch.detailsSummary( for: carryOn ) == "3 nights · business · carry-on · 1 passenger" )

        let checked = Self.makeRoundTrip( checkedBagIncluded: true )
        #expect( SavedSearch.detailsSummary( for: checked ) == "3 nights · business · checked bag · 1 passenger" )
    }

    @Test( "Everything on reads in the order the form presents it" )
    func detailsSummaryWithEverythingOn()
    {
        let search = Self.makeRoundTrip(
            cabinClass: "premium_economy",
            directOnly: true,
            carryOnIncluded: true,
            checkedBagIncluded: true,
            passengers: 2,
            tripDurationDays: 1,
            flexibilityDays: 7,
            mustIncludeWeekend: true
        )

        #expect( SavedSearch.detailsSummary( for: search )
                 == "1 night ±7 · weekend · direct · premium · carry-on · checked bag · 2 passengers" )
    }

    @Test( "An unrecognised cabin class is shown as stored rather than dropped" )
    func detailsSummaryKeepsAnUnknownCabinClass()
    {
        let search = Self.makeRoundTrip( cabinClass: "sleeper" )
        #expect( SavedSearch.detailsSummary( for: search ) == "3 nights · sleeper · 1 passenger" )
    }

    @Test( "Round-trip search defaults" )
    func roundTripDefaults()
    {
        let search = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "business"
        )

        #expect( search.directOnly == true )
        #expect( search.carryOnIncluded == false )
        #expect( search.checkedBagIncluded == false )
        #expect( search.tripDurationDays == 3 )
        #expect( search.flexibilityDays == 0 )
        #expect( search.mustIncludeWeekend == false )
        #expect( search.passengers == 1 )
        #expect( search.isSeeded == false )
    }

    @Test( "SearchKind is string-backed" )
    func searchKindRawValues()
    {
        #expect( SearchKind.oneWay.rawValue == "oneWay" )
        #expect( SearchKind.roundTrip.rawValue == "roundTrip" )
        #expect( SearchKind( rawValue: "oneWay" ) == .oneWay )
        #expect( SearchKind( rawValue: "roundTrip" ) == .roundTrip )
    }

    @Test( "Persists and fetches through SwiftData" )
    func persistsThroughSwiftData() throws
    {
        let context = try self.makeInMemoryContext()
        let search  = SavedSearch(
            kind: .oneWay,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "economy"
        )
        context.insert( search )
        try context.save()

        let fetched = try context.fetch( FetchDescriptor< SavedSearch >() )
        #expect( fetched.count == 1 )
        #expect( fetched.first?.id == search.id )
        #expect( fetched.first?.origin == "GVA" )
        #expect( fetched.first?.destination == "LIS" )
        #expect( fetched.first?.kind == .oneWay )
    }

    @Test( "Summary for a round trip within the same month" )
    func summaryRoundTripSameMonth()
    {
        let search = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "business"
        )

        // 3 nights, no flexibility, so the last departure on 12 October returns on the 15th.
        #expect( search.summary == "GVA ↔ LIS · round trip · 5–15 Oct" )
    }

    @Test( "Summary for a one-way search spanning two months" )
    func summaryOneWayCrossMonth()
    {
        let search = SavedSearch(
            kind: .oneWay,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 9, 28 ),
            rangeEnd: Self.utcDate( 2026, 10, 3 ),
            cabinClass: "economy"
        )

        #expect( search.summary == "GVA → LIS · one-way · 28 Sep – 3 Oct" )
    }

    @Test( "A round trip's label runs to the latest return, crossing into the next month" )
    func summaryRoundTripReturnCrossesMonth()
    {
        let search = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 9, 24 ),
            rangeEnd: Self.utcDate( 2026, 9, 28 ),
            cabinClass: "business",
            tripDurationDays: 5
        )

        // Both bounds are September departures, but the last one returns on 3 October.
        #expect( search.summary == "GVA ↔ LIS · round trip · 24 Sep – 3 Oct" )
    }

    @Test( "Flexibility extends the label to the longest trip the sweep covers" )
    func summaryRoundTripFlexibilityExtendsTheReturn()
    {
        let search = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "business",
            tripDurationDays: 3,
            flexibilityDays: 2
        )

        // 3 nights ±2 searches up to 5, so the last departure can return on the 17th.
        #expect( search.summary == "GVA ↔ LIS · round trip · 5–17 Oct" )
    }

    @Test( "A one-way label still spans its departure range alone" )
    func summaryOneWayIgnoresRoundTripFields()
    {
        let search = SavedSearch(
            kind: .oneWay,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "economy",
            tripDurationDays: 9,
            flexibilityDays: 4
        )

        #expect( search.latestReturnDate == nil )
        #expect( search.summary == "GVA → LIS · one-way · 5–12 Oct" )
    }

    @Test( "The label and the sweep agree on the longest trip searched" )
    func latestReturnMatchesTheSweepsLongestCandidate()
    {
        let search = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 8 ),
            cabinClass: "business",
            tripDurationDays: 2,
            flexibilityDays: 5
        )

        let latestCandidateReturn = RoundTripShapeSearch.candidates( for: search ).map( \.returnDate ).max()
        #expect( search.latestReturnDate == latestCandidateReturn )
    }

    @Test( "The searched duration range clamps at one night rather than going negative" )
    func searchedDurationRangeClamps()
    {
        let clamped = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            cabinClass: "business",
            tripDurationDays: 2,
            flexibilityDays: 5
        )
        #expect( clamped.searchedDurationRange == 1 ... 7 )

        let plain = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            cabinClass: "business",
            tripDurationDays: 4,
            flexibilityDays: 1
        )
        #expect( plain.searchedDurationRange == 3 ... 5 )

        // A stored search can hold a negative flexibility — FlexibilityOptions normalises one for
        // the picker without rewriting it — and an unclamped upper bound would invert the range.
        let negative = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            cabinClass: "business",
            tripDurationDays: 3,
            flexibilityDays: -2
        )
        #expect( negative.searchedDurationRange == 5 ... 5 )
    }

    @Test( "A bound carrying a time of day doesn't push the return a day late" )
    func latestReturnNormalisesTheDeparture()
    {
        let search = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12, hour: 23 ),
            cabinClass: "business",
            tripDurationDays: 3
        )

        #expect( search.latestReturnDate == Self.utcDate( 2026, 10, 15 ) )
        #expect( search.summary == "GVA ↔ LIS · round trip · 5–15 Oct" )
    }

    @Test( "The label states the span asked for, which a weekend requirement can narrow" )
    func latestReturnIgnoresTheWeekendFilter()
    {
        let search = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "business",
            tripDurationDays: 2,
            mustIncludeWeekend: true
        )

        // Mon 12 October departs and returns Wed 14th, touching no weekend, so the sweep drops it —
        // but the label still reports the range the search covers, as its start side does too.
        let latestCandidateReturn = RoundTripShapeSearch.candidates( for: search ).map( \.returnDate ).max()
        #expect( latestCandidateReturn == Self.utcDate( 2026, 10, 13 ) )
        #expect( search.latestReturnDate == Self.utcDate( 2026, 10, 14 ) )
        #expect( search.summary == "GVA ↔ LIS · round trip · 5–14 Oct" )
    }

    @Test( "The route arrow says which way the trip runs" )
    func routeLabelArrowsByKind()
    {
        let oneWay = SavedSearch(
            kind: .oneWay,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "economy"
        )
        let roundTrip = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "economy"
        )

        #expect( oneWay.routeLabel == "GVA → LIS" )
        #expect( roundTrip.routeLabel == "GVA ↔ LIS" )
    }

    @Test( "Summary normalizes a reversed date range" )
    func summaryReversedRange()
    {
        let search = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 12 ),
            rangeEnd: Self.utcDate( 2026, 10, 5 ),
            cabinClass: "business"
        )

        #expect( search.summary == "GVA ↔ LIS · round trip · 5–15 Oct" )
    }

    @Test( "Trip detail for a round trip within the same month" )
    func tripDetailRoundTripSameMonth()
    {
        let search = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "business"
        )

        #expect( search.tripDetail == "round trip · 5–15 Oct" )
    }

    @Test( "Trip detail for a one-way search spanning two months" )
    func tripDetailOneWayCrossMonth()
    {
        let search = SavedSearch(
            kind: .oneWay,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 9, 28 ),
            rangeEnd: Self.utcDate( 2026, 10, 3 ),
            cabinClass: "economy"
        )

        #expect( search.tripDetail == "one-way · 28 Sep – 3 Oct" )
    }

    @Test( "runsNewestFirst sorts runs by runAt descending" )
    func runsNewestFirst()
    {
        let search = SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "business"
        )
        let oldest = SearchRun( runAt: Self.utcDate( 2026, 10, 1 ), requestCount: 1 )
        let middle = SearchRun( runAt: Self.utcDate( 2026, 10, 2 ), requestCount: 1 )
        let newest = SearchRun( runAt: Self.utcDate( 2026, 10, 3 ), requestCount: 1 )
        search.runs = [ middle, oldest, newest ]

        #expect( search.runsNewestFirst.map( \.id ) == [ newest.id, middle.id, oldest.id ] )
    }

    @Test( "Deleting a search cascades through its runs to their itineraries" )
    func deletingSearchCascadesToItineraries() throws
    {
        let context  = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )
        let search   = SavedSearch(
            kind: .oneWay,
            origin: "GVA",
            destination: "LIS",
            rangeStart: Self.utcDate( 2026, 10, 5 ),
            rangeEnd: Self.utcDate( 2026, 10, 12 ),
            cabinClass: "economy"
        )
        let run      = SearchRun( requestCount: 1 )
        let snapshot = PriceSnapshot( amount: 300, currency: "CHF" )
        snapshot.run = run
        run.itineraries.append( snapshot )
        run.savedSearch = search
        search.runs.append( run )
        context.insert( search )
        try context.save()

        #expect( try context.fetch( FetchDescriptor< SearchRun >() ).count == 1 )
        #expect( try context.fetch( FetchDescriptor< PriceSnapshot >() ).count == 1 )

        context.delete( search )
        try context.save()

        #expect( try context.fetch( FetchDescriptor< SavedSearch >() ).isEmpty )
        #expect( try context.fetch( FetchDescriptor< SearchRun >() ).isEmpty )
        #expect( try context.fetch( FetchDescriptor< PriceSnapshot >() ).isEmpty )
    }

    @Test( "Deleting every search (clear all) leaves no searches, runs, or itineraries behind" )
    func deletingEverySearchClearsAll() throws
    {
        let context = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )
        let searches = ( 0 ..< 3 ).map
        { index in
            SavedSearch(
                kind: .oneWay,
                origin: "GVA",
                destination: "LIS",
                rangeStart: Self.utcDate( 2026, 10, 5 + index ),
                rangeEnd: Self.utcDate( 2026, 10, 12 + index ),
                cabinClass: "economy"
            )
        }
        for search in searches
        {
            let run      = SearchRun( requestCount: 1 )
            let snapshot = PriceSnapshot( amount: 300, currency: "CHF" )
            snapshot.run = run
            run.itineraries.append( snapshot )
            run.savedSearch = search
            search.runs.append( run )
            context.insert( search )
        }
        try context.save()

        #expect( try context.fetch( FetchDescriptor< SavedSearch >() ).count == 3 )

        for search in try context.fetch( FetchDescriptor< SavedSearch >() )
        {
            context.delete( search )
        }
        try context.save()

        #expect( try context.fetch( FetchDescriptor< SavedSearch >() ).isEmpty )
        #expect( try context.fetch( FetchDescriptor< SearchRun >() ).isEmpty )
        #expect( try context.fetch( FetchDescriptor< PriceSnapshot >() ).isEmpty )
    }
}
