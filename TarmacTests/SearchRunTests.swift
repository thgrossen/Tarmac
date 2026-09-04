/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData
@testable import Tarmac
import Testing

@Suite( "SearchRun" )
struct SearchRunTests
{
    private static func makeSearch() -> SavedSearch
    {
        SavedSearch(
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: .now,
            rangeEnd: .now,
            cabinClass: "business"
        )
    }

    @Test( "Defaults" )
    func defaults()
    {
        let run = SearchRun( requestCount: 1 )

        #expect( run.rawJSON == nil )
        #expect( run.errorMessage == nil )
        #expect( run.savedSearch == nil )
        #expect( run.itineraries.isEmpty )
    }

    @Test( "Stores required fields" )
    func storesFields()
    {
        let run = SearchRun( rawJSON: "{}", errorMessage: "boom", requestCount: 12 )

        #expect( run.rawJSON == "{}" )
        #expect( run.errorMessage == "boom" )
        #expect( run.requestCount == 12 )
    }

    @Test( "SavedSearch.runs cascades on delete" )
    func savedSearchRunsCascade() throws
    {
        let context = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )
        let search  = Self.makeSearch()
        let run     = SearchRun( requestCount: 1 )
        run.savedSearch = search
        search.runs.append( run )
        context.insert( search )
        try context.save()

        let fetchedRuns = try context.fetch( FetchDescriptor< SearchRun >() )
        #expect( fetchedRuns.count == 1 )
        #expect( fetchedRuns.first?.savedSearch?.id == search.id )

        context.delete( search )
        try context.save()

        let remainingRuns = try context.fetch( FetchDescriptor< SearchRun >() )
        #expect( remainingRuns.isEmpty )
    }

    @Test( "cheapestFare is nil when there are no itineraries" )
    func cheapestFareEmpty()
    {
        let run = SearchRun( requestCount: 1 )
        #expect( run.cheapestFare == nil )
    }

    @Test( "cheapestFare is the itinerary with the lowest amount" )
    func cheapestFarePicksLowest()
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [
            PriceSnapshot( amount: 600, currency: "CHF" ),
            PriceSnapshot( amount: 300, currency: "CHF" ),
            PriceSnapshot( amount: 450, currency: "CHF" ),
        ]

        #expect( run.cheapestFare?.amount == 300 )
    }

    @Test( "maxFare is nil when there are no itineraries" )
    func maxFareEmpty()
    {
        let run = SearchRun( requestCount: 1 )
        #expect( run.maxFare == nil )
    }

    @Test( "maxFare is the itinerary with the highest amount" )
    func maxFarePicksHighest()
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [
            PriceSnapshot( amount: 600, currency: "CHF" ),
            PriceSnapshot( amount: 300, currency: "CHF" ),
            PriceSnapshot( amount: 450, currency: "CHF" ),
        ]

        #expect( run.maxFare?.amount == 600 )
    }

    @Test( "the fare range covers only the matching itineraries" )
    func filteredFareRange() throws
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [
            PriceSnapshot( amount: 600, currency: "CHF" ),
            PriceSnapshot( amount: 300, currency: "CHF" ),
            PriceSnapshot( amount: 450, currency: "CHF" ),
        ]

        var filters = OneWayFilters()
        filters.minPrice = 400

        #expect( run.fares( matching: filters ).count == 2 )

        let range = try #require( run.fareRange( matching: filters ) )
        #expect( range.low == 450 )
        #expect( range.high == 600 )
    }

    @Test( "a run whose itineraries are all filtered out has no fare range" )
    func fullyFilteredRunHasNoFares()
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [ PriceSnapshot( amount: 600, currency: "CHF" ) ]

        var filters = OneWayFilters()
        filters.maxPrice = 400

        #expect( run.fares( matching: filters ).isEmpty )
        #expect( run.fareRange( matching: filters ) == nil )
    }

    @Test( "passing no filters leaves every itinerary in place" )
    func unfilteredFareRange() throws
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [
            PriceSnapshot( amount: 600, currency: "CHF" ),
            PriceSnapshot( amount: 300, currency: "CHF" ),
        ]

        #expect( run.fares( matching: nil ).count == 2 )

        let range = try #require( run.fareRange( matching: nil ) )
        #expect( range.low == 300 )
        #expect( range.high == 600 )
    }

    @Test( "an unparseable price is left out of the fare range" )
    func fareRangeSkipsNonFinitePrices() throws
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [
            PriceSnapshot( amount: .nan, currency: "CHF" ),
            PriceSnapshot( amount: 300, currency: "CHF" ),
        ]

        let range = try #require( run.fareRange( matching: nil ) )
        #expect( range.low == 300 )
        #expect( range.high == 300 )
    }

    @Test( "SearchRun.itineraries cascades on delete" )
    func searchRunItinerariesCascade() throws
    {
        let context  = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )
        let run      = SearchRun( requestCount: 1 )
        let snapshot = PriceSnapshot( amount: 542.0, currency: "CHF" )
        snapshot.run = run
        run.itineraries.append( snapshot )
        context.insert( run )
        try context.save()

        let fetchedSnapshots = try context.fetch( FetchDescriptor< PriceSnapshot >() )
        #expect( fetchedSnapshots.count == 1 )
        #expect( fetchedSnapshots.first?.run?.id == run.id )

        context.delete( run )
        try context.save()

        let remainingSnapshots = try context.fetch( FetchDescriptor< PriceSnapshot >() )
        #expect( remainingSnapshots.isEmpty )
    }
}
