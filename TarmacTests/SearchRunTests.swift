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

    @Test( "priceDelta is nil when this run has no fares" )
    func priceDeltaNilWhenNoFares()
    {
        let run      = SearchRun( requestCount: 1 )
        let previous = SearchRun( requestCount: 1 )
        previous.itineraries = [ PriceSnapshot( amount: 400, currency: "CHF" ) ]

        #expect( run.priceDelta( previous: previous ) == nil )
    }

    @Test( "priceDelta is nil when there is no previous run" )
    func priceDeltaNilWhenNoPrevious()
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [ PriceSnapshot( amount: 400, currency: "CHF" ) ]

        #expect( run.priceDelta( previous: nil ) == nil )
    }

    @Test( "priceDelta is nil when the previous run has no fares" )
    func priceDeltaNilWhenPreviousHasNoFares()
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [ PriceSnapshot( amount: 400, currency: "CHF" ) ]
        let previous = SearchRun( requestCount: 1 )

        #expect( run.priceDelta( previous: previous ) == nil )
    }

    @Test( "priceDelta is the cheapest-fare difference between this run and the previous one" )
    func priceDeltaComputesDifference()
    {
        let previous = SearchRun( requestCount: 1 )
        previous.itineraries = [ PriceSnapshot( amount: 500, currency: "CHF" ) ]
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [ PriceSnapshot( amount: 420, currency: "CHF" ) ]

        #expect( run.priceDelta( previous: previous ) == -80 )
    }

    @Test( "pairedWithPrevious pairs each run with its chronological predecessor" )
    func pairedWithPreviousPairsCorrectly()
    {
        let newest = SearchRun( requestCount: 1 )
        let middle = SearchRun( requestCount: 1 )
        let oldest = SearchRun( requestCount: 1 )
        let runs   = [ newest, middle, oldest ]     // newest first

        let pairs = runs.pairedWithPrevious()

        #expect( pairs.count == 3 )
        #expect( pairs[ 0 ].run.id == newest.id )
        #expect( pairs[ 0 ].previous?.id == middle.id )
        #expect( pairs[ 1 ].run.id == middle.id )
        #expect( pairs[ 1 ].previous?.id == oldest.id )
        #expect( pairs[ 2 ].run.id == oldest.id )
        #expect( pairs[ 2 ].previous == nil )
    }

    @Test( "pairedWithPrevious on an empty list returns nothing" )
    func pairedWithPreviousEmpty()
    {
        let runs: [ SearchRun ] = []
        #expect( runs.pairedWithPrevious().isEmpty )
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
