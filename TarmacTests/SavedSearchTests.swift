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
    private static func utcDate( _ year: Int, _ month: Int, _ day: Int ) -> Date
    {
        var calendar    = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        let components  = DateComponents( year: year, month: month, day: day )
        return calendar.date( from: components )!
    }

    private func makeInMemoryContext() throws -> ModelContext
    {
        let schema = Schema( [ SavedSearch.self ] )
        let config = ModelConfiguration( schema: schema, isStoredInMemoryOnly: true )
        let container = try ModelContainer( for: schema, configurations: [ config ] )
        return ModelContext( container )
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

        #expect( search.summary == "GVA ↔ LIS · round trip · 5–12 Oct" )
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

        #expect( search.summary == "GVA ↔ LIS · round trip · 5–12 Oct" )
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

        #expect( search.tripDetail == "round trip · 5–12 Oct" )
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
