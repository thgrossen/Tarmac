/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "ResultFilterBounds" )
struct ResultFilterBoundsTests
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

        let bounds = ResultFilterBounds.bounds( for: [ first, second ] )

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

        let bounds = ResultFilterBounds.bounds( for: [ run ] )

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

        let bounds = ResultFilterBounds.bounds( for: [ run ] )

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

        let bounds = ResultFilterBounds.bounds( for: [ run ] )

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

        let bounds = ResultFilterBounds.bounds( for: [ run ] )

        #expect( bounds.flightNumbers == [ "LX 1234", "TP 5678" ] )
    }

    @Test( "a round trip's fares are bounded by their outbound leg, exactly as a one-way search's are" )
    func roundTripFaresYieldOutboundBounds()
    {
        let run = Self.run( [
            PriceSnapshot(
                amount: 300,
                currency: "CHF",
                outboundSummary: "LX 1234",
                inboundSummary: "LX 5678",
                outboundDuration: "2h30",
                carrier: "LX",
                departureTime: "06:00",
                arrivalTime: "08:30",
                departureDate: Self.date( 5 ),
                inboundDepartureTime: "21:15",
                inboundDepartureDate: Self.date( 8 ),
                outboundStopCount: 0,
                outboundFlightNumbers: [ "LX 1234" ]
            ),
            PriceSnapshot(
                amount: 900,
                currency: "CHF",
                outboundSummary: "TP 4321",
                inboundSummary: "TP 8765",
                outboundDuration: "10h05",
                carrier: "TP",
                departureTime: "18:45",
                arrivalTime: "23:50",
                departureDate: Self.date( 12 ),
                inboundDepartureTime: "07:30",
                inboundDepartureDate: Self.date( 19 ),
                outboundStopCount: 2,
                outboundFlightNumbers: [ "TP 4321" ]
            ),
        ] )

        let bounds = ResultFilterBounds.bounds( for: [ run ] )

        #expect( bounds.isEmpty == false )
        #expect( bounds.priceRange == 300 ... 900 )
        #expect( bounds.carriers == [ "LX", "TP" ] )
        #expect( bounds.durationRange == 150 ... 605 )
        #expect( bounds.stopsRange == 0 ... 2 )
        #expect( bounds.flightNumbers == [ "LX 1234", "TP 4321" ] )

        // The inbound leg departs on the 8th and the 19th, at 21:15 and 07:30. Were any of it to
        // reach these bounds, the date range would run to the 19th and the departure range to 21:15.
        #expect( bounds.dateRange == Self.date( 5 ) ... Self.date( 12 ) )
        #expect( bounds.departureMinuteRange == 360 ... 1125 )
        #expect( bounds.arrivalMinuteRange == 510 ... 1430 )
    }

    @Test( "a round trip's fares supply the trip-duration and inbound extents" )
    func roundTripExtents()
    {
        let run = Self.run( [
            PriceSnapshot(
                amount: 300,
                currency: "CHF",
                departureDate: Self.date( 5 ),
                inboundDepartureTime: "07:30",
                inboundDepartureDate: Self.date( 8 )
            ),
            PriceSnapshot(
                amount: 900,
                currency: "CHF",
                departureDate: Self.date( 5 ),
                inboundDepartureTime: "21:15",
                inboundDepartureDate: Self.date( 12 )
            ),
        ] )

        let bounds = ResultFilterBounds.bounds( for: [ run ] )

        // Both fares depart on the 5th, returning on the 8th and the 12th: 3 and 7 nights.
        #expect( bounds.tripDurationRange == 3 ... 7 )
        #expect( bounds.inboundDateRange == Self.date( 8 ) ... Self.date( 12 ) )
        #expect( bounds.inboundDepartureMinuteRange == 450 ... 1275 )
    }

    @Test( "a one-way search is offered none of the round-trip filters" )
    func oneWayFaresSupplyNoRoundTripExtents()
    {
        let run = Self.run( [
            PriceSnapshot( amount: 300, currency: "CHF", carrier: "LX", departureTime: "06:00", departureDate: Self.date( 5 ) ),
            PriceSnapshot( amount: 900, currency: "CHF", carrier: "TP", departureTime: "18:45", departureDate: Self.date( 12 ) ),
        ] )

        let bounds = ResultFilterBounds.bounds( for: [ run ] )

        // The fares carry no inbound leg, so these three stay nil and their rows never appear —
        // without the popover having to know what kind of search it belongs to.
        #expect( bounds.tripDurationRange == nil )
        #expect( bounds.inboundDateRange == nil )
        #expect( bounds.inboundDepartureMinuteRange == nil )
        #expect( bounds.isEmpty == false )
    }

    @Test( "a search varying only on its round-trip axes is still filterable" )
    func roundTripAxesAloneMakeASearchFilterable()
    {
        let run = Self.run( [
            PriceSnapshot( amount: 300, currency: "CHF", departureTime: "08:00", departureDate: Self.date( 5 ), inboundDepartureTime: "18:00", inboundDepartureDate: Self.date( 8 ) ),
            PriceSnapshot( amount: 300, currency: "CHF", departureTime: "08:00", departureDate: Self.date( 5 ), inboundDepartureTime: "18:00", inboundDepartureDate: Self.date( 12 ) ),
        ] )

        let bounds = ResultFilterBounds.bounds( for: [ run ] )

        // Every outbound value is shared, so none of them can narrow anything.
        #expect( bounds.priceRange == nil )
        #expect( bounds.dateRange == nil )
        #expect( bounds.departureMinuteRange == nil )

        // The return date is the only axis that varies, and it is enough on its own — without which
        // the search would offer a permanently disabled Filters button over two usable rows.
        #expect( bounds.tripDurationRange == 3 ... 7 )
        #expect( bounds.inboundDateRange == Self.date( 8 ) ... Self.date( 12 ) )
        #expect( bounds.isEmpty == false )
        #expect( SearchDetailView.isFilterable( bounds: bounds ) )
    }

    @Test( "a round trip whose fares all share one shape offers none of its filters either" )
    func degenerateRoundTripExtents()
    {
        let run = Self.run( [
            PriceSnapshot( amount: 300, currency: "CHF", departureDate: Self.date( 5 ), inboundDepartureTime: "18:00", inboundDepartureDate: Self.date( 8 ) ),
            PriceSnapshot( amount: 300, currency: "CHF", departureDate: Self.date( 5 ), inboundDepartureTime: "18:00", inboundDepartureDate: Self.date( 8 ) ),
        ] )

        let bounds = ResultFilterBounds.bounds( for: [ run ] )

        #expect( bounds.tripDurationRange == nil )
        #expect( bounds.inboundDateRange == nil )
        #expect( bounds.inboundDepartureMinuteRange == nil )
        #expect( bounds.isEmpty )
    }

    @Test( "a search with no fares has nothing to filter on" )
    func noFaresMeansNoBounds()
    {
        #expect( ResultFilterBounds.bounds( for: [] ).isEmpty )
        #expect( ResultFilterBounds.bounds( for: [ SearchRun( requestCount: 1 ) ] ).isEmpty )
    }
}
