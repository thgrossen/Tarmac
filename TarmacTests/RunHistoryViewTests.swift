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
    @Test( "chartRuns reverses to chronological order and drops runs with no fares" )
    func chartRunsFiltersAndReverses()
    {
        let newest = SearchRun( requestCount: 1 )
        newest.itineraries = [ PriceSnapshot( amount: 300, currency: "CHF" ) ]
        let noFares = SearchRun( requestCount: 1 )
        let oldest = SearchRun( requestCount: 1 )
        oldest.itineraries = [ PriceSnapshot( amount: 500, currency: "CHF" ) ]

        let result = PriceHistoryChart.chartRuns( for: [ newest, noFares, oldest ] )

        #expect( result.map( \.id ) == [ oldest.id, newest.id ] )
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
}
