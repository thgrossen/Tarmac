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
        #expect( search.luggageIncluded == false )
        #expect( search.tripDurationDays == 3 )
        #expect( search.flexibilityDays == 0 )
        #expect( search.mustIncludeWeekend == false )
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

        #expect( search.summary == "GVA → LIS · aller-retour · 5–12 oct." )
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

        #expect( search.summary == "GVA → LIS · aller simple · 28 sept. – 3 oct." )
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

        #expect( search.summary == "GVA → LIS · aller-retour · 5–12 oct." )
    }
}
