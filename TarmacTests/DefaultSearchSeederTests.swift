/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData
@testable import Tarmac
import Testing

@Suite( "DefaultSearchSeeder" )
struct DefaultSearchSeederTests
{
    private static func utcDate( _ year: Int, _ month: Int, _ day: Int ) -> Date
    {
        var calendar      = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        let components    = DateComponents( year: year, month: month, day: day )
        return calendar.date( from: components )!
    }

    @Test( "Inserts the default search on an empty store" )
    func seedsWhenEmpty() throws
    {
        let context = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )

        DefaultSearchSeeder.seedIfNeeded( in: context, referenceDate: Self.utcDate( 2026, 10, 1 ) )

        let searches = try context.fetch( FetchDescriptor< SavedSearch >() )
        #expect( searches.count == 1 )

        let search = try #require( searches.first )
        #expect( search.isSeeded == true )
        #expect( search.kind == .roundTrip )
        #expect( search.origin == "GVA" )
        #expect( search.destination == "LIS" )
        #expect( search.cabinClass == "business" )
        #expect( search.directOnly == true )
        #expect( search.luggageIncluded == false )
        #expect( search.tripDurationDays == 3 )
        #expect( search.flexibilityDays == 0 )
        #expect( search.mustIncludeWeekend == false )
        #expect( search.rangeStart == Self.utcDate( 2026, 11, 30 ) )
        #expect( search.rangeEnd == Self.utcDate( 2026, 11, 30 ) )
    }

    @Test( "Does not seed again when a search already exists" )
    func doesNotDuplicate() throws
    {
        let context  = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )
        let existing = SavedSearch(
            kind: .oneWay,
            origin: "ZRH",
            destination: "JFK",
            rangeStart: Self.utcDate( 2026, 12, 1 ),
            rangeEnd: Self.utcDate( 2026, 12, 1 ),
            cabinClass: "economy"
        )
        context.insert( existing )
        try context.save()

        DefaultSearchSeeder.seedIfNeeded( in: context, referenceDate: Self.utcDate( 2026, 10, 1 ) )

        let searches = try context.fetch( FetchDescriptor< SavedSearch >() )
        #expect( searches.count == 1 )
        #expect( searches.first?.origin == "ZRH" )
    }
}
