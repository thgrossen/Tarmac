/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "PriceHistoryChart" )
struct PriceHistoryChartTests
{
    @Test( "chartRuns reverses to chronological order, keeping runs with no fares" )
    func chartRunsReversesKeepingNoFareRuns()
    {
        let newest = SearchRun( requestCount: 1 )
        newest.itineraries = [ PriceSnapshot( amount: 300, currency: "CHF" ) ]
        let noFares = SearchRun( requestCount: 1 )
        let oldest = SearchRun( requestCount: 1 )
        oldest.itineraries = [ PriceSnapshot( amount: 500, currency: "CHF" ) ]

        let result = PriceHistoryChart.chartRuns( for: [ newest, noFares, oldest ] )

        #expect( result.map( \.id ) == [ oldest.id, noFares.id, newest.id ] )
    }

    @Test( "chartRuns on an empty list returns nothing" )
    func chartRunsEmpty()
    {
        #expect( PriceHistoryChart.chartRuns( for: [] ).isEmpty )
    }

    @Test( "yDomain spans the padded low/high range across every plotted run" )
    func yDomainSpansRunsWithPadding()
    {
        let low = SearchRun( requestCount: 1 )
        low.itineraries = [ PriceSnapshot( amount: 300, currency: "CHF" ) ]
        let high = SearchRun( requestCount: 1 )
        high.itineraries = [
            PriceSnapshot( amount: 500, currency: "CHF" ),
            PriceSnapshot( amount: 700, currency: "CHF" ),
        ]

        let domain = PriceHistoryChart.yDomain( for: [ low, high ] )

        #expect( domain.lowerBound == 260 )
        #expect( domain.upperBound == 740 )
    }

    @Test( "yDomain falls back to a flat $1 padding when every run has the same price" )
    func yDomainFlatPricesUsesMinimumPadding()
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [ PriceSnapshot( amount: 400, currency: "CHF" ) ]

        let domain = PriceHistoryChart.yDomain( for: [ run ] )

        #expect( domain.lowerBound == 399 )
        #expect( domain.upperBound == 401 )
    }

    @Test( "yDomain on an empty list returns 0...1" )
    func yDomainEmpty()
    {
        #expect( PriceHistoryChart.yDomain( for: [] ) == 0...1 )
    }

    @Test( "paddedDomainValues fills unused width with placeholder categories" )
    func paddedDomainValuesFillsUnusedWidth()
    {
        let runs = ( 0..<2 ).map { _ in SearchRun( requestCount: 1 ) }

        let domain = PriceHistoryChart.paddedDomainValues( chartRuns: runs, availableWidth: 320, slotWidth: 32 )

        #expect( domain.count == 10 )
        #expect( Array( domain.prefix( 2 ) ) == runs.map( \.id.uuidString ) )
    }

    @Test( "paddedDomainValues adds no padding when the runs already fill the available width" )
    func paddedDomainValuesNoPaddingWhenFull()
    {
        let runs = ( 0..<5 ).map { _ in SearchRun( requestCount: 1 ) }

        let domain = PriceHistoryChart.paddedDomainValues( chartRuns: runs, availableWidth: 96, slotWidth: 32 )

        #expect( domain == runs.map( \.id.uuidString ) )
    }

    @Test( "paddedDomainValues returns the runs' IDs unchanged when slotWidth is zero" )
    func paddedDomainValuesZeroSlotWidth()
    {
        let runs = ( 0..<3 ).map { _ in SearchRun( requestCount: 1 ) }

        let domain = PriceHistoryChart.paddedDomainValues( chartRuns: runs, availableWidth: 600, slotWidth: 0 )

        #expect( domain == runs.map( \.id.uuidString ) )
    }

    @Test( "barExtent uses the run's own cheapest/max fare when it has one" )
    func barExtentUsesRealFareRange()
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [
            PriceSnapshot( amount: 300, currency: "CHF" ),
            PriceSnapshot( amount: 500, currency: "CHF" ),
        ]

        let extent = PriceHistoryChart.barExtent( for: run, yDomain: 0...1000 )

        #expect( extent.low == 300 )
        #expect( extent.high == 500 )
    }

    @Test( "barExtent draws a thin marker at the domain floor for a run with no fares" )
    func barExtentMarksRunsWithNoFares()
    {
        let run = SearchRun( requestCount: 1 )

        let extent = PriceHistoryChart.barExtent( for: run, yDomain: 200...800 )

        #expect( extent.low == 200 )
        #expect( extent.high == 200 + ( 800 - 200 ) * 0.03 )
    }

    // MARK: - Filtered plotting

    private static func filters( maxPrice: Double ) -> OneWayFilters
    {
        var filters = OneWayFilters()
        filters.maxPrice = maxPrice
        return filters
    }

    @Test( "yDomain spans only the fares that match the filters" )
    func yDomainRespectsFilters()
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [
            PriceSnapshot( amount: 300, currency: "CHF" ),
            PriceSnapshot( amount: 500, currency: "CHF" ),
            PriceSnapshot( amount: 900, currency: "CHF" ),
        ]

        let domain = PriceHistoryChart.yDomain( for: [ run ], filters: Self.filters( maxPrice: 500 ) )

        #expect( domain.lowerBound == 280 )
        #expect( domain.upperBound == 520 )
    }

    @Test( "barExtent covers only the fares that match the filters" )
    func barExtentRespectsFilters()
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [
            PriceSnapshot( amount: 300, currency: "CHF" ),
            PriceSnapshot( amount: 500, currency: "CHF" ),
            PriceSnapshot( amount: 900, currency: "CHF" ),
        ]

        let extent = PriceHistoryChart.barExtent( for: run, yDomain: 0...1000, filters: Self.filters( maxPrice: 500 ) )

        #expect( extent.low == 300 )
        #expect( extent.high == 500 )
    }

    @Test( "a run whose fares are all filtered out falls back to the thin marker" )
    func barExtentMarksFullyFilteredRuns()
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [ PriceSnapshot( amount: 900, currency: "CHF" ) ]

        let extent = PriceHistoryChart.barExtent( for: run, yDomain: 200...800, filters: Self.filters( maxPrice: 500 ) )

        #expect( extent.low == 200 )
        #expect( extent.high == 200 + ( 800 - 200 ) * 0.03 )
    }

}

@Suite( "Filtered results" )
struct FilteredResultsTests
{
    @Test( "the table's empty state distinguishes an empty run from a fully filtered one" )
    func emptyStateDistinguishesFiltering()
    {
        #expect( RunHistoryView.emptyState( isFiltered: false ).title == "No fares found" )
        #expect( RunHistoryView.emptyState( isFiltered: true ).title == "No fares match these filters" )
    }

    @Test( "the fare count reads as a fraction of the run's results" )
    func fareCountLabel()
    {
        #expect( FilterChipBar.fareCountLabel( matching: 12, total: 47 ) == "12 of 47 fares" )
        #expect( FilterChipBar.fareCountLabel( matching: 0, total: 1 ) == "0 of 1 fare" )
    }

    @Test( "max stops reads as a plain-English limit" )
    func maxStopsLabel()
    {
        #expect( OneWayFiltersPopover.maxStopsLabel( for: 0, isUnrestricted: false ) == "Direct only" )
        #expect( OneWayFiltersPopover.maxStopsLabel( for: 1, isUnrestricted: false ) == "Up to 1 stop" )
        #expect( OneWayFiltersPopover.maxStopsLabel( for: 3, isUnrestricted: false ) == "Up to 3 stops" )
    }

    @Test( "the entry that excludes nothing reads as no limit at all" )
    func maxStopsUnrestrictedLabel()
    {
        #expect( OneWayFiltersPopover.maxStopsLabel( for: 2, isUnrestricted: true ) == "Any" )
    }

    @Test( "filters are only applied to a one-way search that actually has some set" )
    func appliedFilters()
    {
        var active = OneWayFilters()
        active.maxPrice = 400

        #expect( SearchDetailView.appliedFilters( active, isFilterable: true ) == active )
        #expect( SearchDetailView.appliedFilters( active, isFilterable: false ) == nil )
        #expect( SearchDetailView.appliedFilters( OneWayFilters(), isFilterable: true ) == nil )
    }

    @Test( "chips wrap onto a new row once one runs out of width" )
    func chipsWrap()
    {
        let sizes = Array( repeating: CGSize( width: 100, height: 20 ), count: 4 )

        let layout = FlowLayout.arrange( sizes: sizes, width: 220, spacing: 6 )

        #expect( layout.origins.map( \.y ) == [ 0, 0, 26, 26 ] )
        #expect( layout.origins.map( \.x ) == [ 0, 106, 0, 106 ] )
        #expect( layout.size.height == 46 )
    }

    @Test( "chips that all fit stay on one row" )
    func chipsOnOneRow()
    {
        let sizes = [ CGSize( width: 80, height: 20 ), CGSize( width: 60, height: 24 ) ]

        let layout = FlowLayout.arrange( sizes: sizes, width: 400, spacing: 6 )

        #expect( layout.origins.map( \.x ) == [ 0, 86 ] )
        #expect( layout.size == CGSize( width: 146, height: 24 ) )
    }
}
