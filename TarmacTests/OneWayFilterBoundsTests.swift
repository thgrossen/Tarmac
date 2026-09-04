/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "OneWayFilterBounds" )
struct OneWayFilterBoundsTests
{
    private static var calendar: Calendar
    {
        var c = Calendar( identifier: .gregorian )
        c.timeZone = TimeZone( identifier: "UTC" )!
        return c
    }

    private static func date( _ day: Int ) -> Date
    {
        Self.calendar.date( from: DateComponents( year: 2026, month: 10, day: day, hour: 8 ) )!
    }

    private static func run( _ snapshots: [ PriceSnapshot ] ) -> SearchRun
    {
        let run = SearchRun( requestCount: 1 )
        run.itineraries = snapshots
        return run
    }

    @Test( "bounds span every run of the search, not just one" )
    func boundsSpanEveryRun()
    {
        let first = Self.run( [
            PriceSnapshot( amount: 300, currency: "CHF", carrier: "LX", departureDate: Self.date( 5 ) ),
        ] )
        let second = Self.run( [
            PriceSnapshot( amount: 900, currency: "CHF", carrier: "TP", departureDate: Self.date( 12 ) ),
        ] )

        let bounds = OneWayFilterBounds.bounds( for: [ first, second ] )

        #expect( bounds.priceRange == 300 ... 900 )
        #expect( bounds.dateRange == Self.date( 5 ) ... Self.date( 12 ) )
        #expect( bounds.carriers == [ "LX", "TP" ] )
    }

    @Test( "unparseable prices are left out of the price bounds" )
    func nonFinitePricesAreSkipped()
    {
        let run = Self.run( [
            PriceSnapshot( amount: .nan, currency: "CHF" ),
            PriceSnapshot( amount: 300, currency: "CHF" ),
            PriceSnapshot( amount: 500, currency: "CHF" ),
        ] )

        let bounds = OneWayFilterBounds.bounds( for: [ run ] )

        #expect( bounds.priceRange == 300 ... 500 )
        #expect( bounds.currency == "CHF" )
    }

    @Test( "a value every fare shares can't narrow anything, so it isn't offered" )
    func degenerateBoundsAreUnsupported()
    {
        let run = Self.run( [
            PriceSnapshot( amount: 300, currency: "CHF", outboundDuration: "2h30", carrier: "LX", departureTime: "08:00", outboundStopCount: 0, outboundFlightNumbers: [ "LX 1234" ] ),
            PriceSnapshot( amount: 300, currency: "CHF", outboundDuration: "2h30", carrier: "LX", departureTime: "08:00", outboundStopCount: 0, outboundFlightNumbers: [ "LX 1234" ] ),
        ] )

        let bounds = OneWayFilterBounds.bounds( for: [ run ] )

        #expect( bounds.priceRange == nil )
        #expect( bounds.durationRange == nil )
        #expect( bounds.departureMinuteRange == nil )
        #expect( bounds.stopsRange == nil )
        #expect( bounds.carriers.isEmpty )
        #expect( bounds.flightNumbers.isEmpty )
        #expect( bounds.isEmpty )
    }

    @Test( "times, durations and stops span the values the fares carry" )
    func derivedRanges()
    {
        let run = Self.run( [
            PriceSnapshot( amount: 300, currency: "CHF", outboundDuration: "2h30", departureTime: "06:00", arrivalTime: "08:30", outboundStopCount: 0 ),
            PriceSnapshot( amount: 500, currency: "CHF", outboundDuration: "10h05", departureTime: "18:45", arrivalTime: "23:50", outboundStopCount: 2 ),
        ] )

        let bounds = OneWayFilterBounds.bounds( for: [ run ] )

        #expect( bounds.departureMinuteRange == 360 ... 1125 )
        #expect( bounds.arrivalMinuteRange == 510 ... 1430 )
        #expect( bounds.durationRange == 150 ... 605 )
        #expect( bounds.stopsRange == 0 ... 2 )
    }

    @Test( "flight numbers are collected across segments, deduplicated and sorted" )
    func flightNumbersAreCollected()
    {
        let run = Self.run( [
            PriceSnapshot( amount: 300, currency: "CHF", outboundFlightNumbers: [ "TP 5678", "LX 1234" ] ),
            PriceSnapshot( amount: 500, currency: "CHF", outboundFlightNumbers: [ "LX 1234" ] ),
        ] )

        let bounds = OneWayFilterBounds.bounds( for: [ run ] )

        #expect( bounds.flightNumbers == [ "LX 1234", "TP 5678" ] )
    }

    @Test( "a search with no fares has nothing to filter on" )
    func noFaresMeansNoBounds()
    {
        #expect( OneWayFilterBounds.bounds( for: [] ).isEmpty )
        #expect( OneWayFilterBounds.bounds( for: [ SearchRun( requestCount: 1 ) ] ).isEmpty )
    }
}
