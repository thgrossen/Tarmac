/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "OneWayFilters" )
struct OneWayFiltersTests
{
    private static var calendar: Calendar
    {
        var c = Calendar( identifier: .gregorian )
        c.timeZone = TimeZone( identifier: "UTC" )!
        return c
    }

    private static func date( _ day: Int, hour: Int = 8 ) -> Date
    {
        Self.calendar.date( from: DateComponents( year: 2026, month: 10, day: day, hour: hour ) )!
    }

    private static func fare(
        amount: Double = 300,
        carrier: String? = "LX",
        departureTime: String? = "08:00",
        arrivalTime: String? = "10:30",
        duration: String? = "2h30",
        departureDate: Date? = Self.date( 5 ),
        stops: Int? = 0,
        flightNumbers: [ String ] = [ "LX 1234" ]
    ) -> PriceSnapshot
    {
        PriceSnapshot(
            amount: amount,
            currency: "CHF",
            outboundDuration: duration,
            carrier: carrier,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            departureDate: departureDate,
            outboundStopCount: stops,
            outboundFlightNumbers: flightNumbers
        )
    }

    // MARK: - State

    @Test( "a freshly created filter set is inactive" )
    func emptyFiltersAreInactive()
    {
        let filters = OneWayFilters()

        #expect( filters.isActive == false )
        #expect( filters.activeCount == 0 )
    }

    @Test( "a range filter counts once however many of its ends are set" )
    func rangeFilterCountsOnce()
    {
        var filters = OneWayFilters()
        filters.maxPrice = 400
        #expect( filters.activeCount == 1 )

        filters.minPrice = 100
        #expect( filters.activeCount == 1 )

        filters.carriers = [ "LX" ]
        #expect( filters.activeCount == 2 )
        #expect( filters.isActive )
    }

    @Test( "an empty selection is still an active filter" )
    func emptySelectionIsActive()
    {
        var filters = OneWayFilters()
        filters.carriers = []

        #expect( filters.isActive )
        #expect( filters.apply( to: [ Self.fare() ] ).isEmpty )
    }

    // MARK: - Matching

    @Test( "an inactive filter set keeps every fare" )
    func inactiveFiltersKeepEverything()
    {
        let fares = [ Self.fare( amount: 100 ), Self.fare( amount: 900 ) ]

        #expect( OneWayFilters().apply( to: fares ).count == 2 )
    }

    @Test( "the price filter keeps fares inside its bounds, inclusively" )
    func priceFilter()
    {
        var filters = OneWayFilters()
        filters.minPrice = 200
        filters.maxPrice = 400

        #expect( filters.matches( Self.fare( amount: 200 ) ) )
        #expect( filters.matches( Self.fare( amount: 400 ) ) )
        #expect( filters.matches( Self.fare( amount: 199 ) ) == false )
        #expect( filters.matches( Self.fare( amount: 401 ) ) == false )
    }

    @Test( "an unparseable price never satisfies an active price filter" )
    func priceFilterExcludesNaN()
    {
        var filters = OneWayFilters()
        filters.maxPrice = 400

        #expect( filters.matches( Self.fare( amount: .nan ) ) == false )
    }

    @Test( "the date filter keeps fares departing inside its bounds" )
    func dateFilter()
    {
        var filters = OneWayFilters()
        filters.startDate = Self.date( 5, hour: 0 )
        filters.endDate   = Self.date( 7, hour: 23 )

        #expect( filters.matches( Self.fare( departureDate: Self.date( 6 ) ) ) )
        #expect( filters.matches( Self.fare( departureDate: Self.date( 4 ) ) ) == false )
        #expect( filters.matches( Self.fare( departureDate: Self.date( 8 ) ) ) == false )
        #expect( filters.matches( Self.fare( departureDate: nil ) ) == false )
    }

    @Test( "the carrier filter keeps only the selected carriers" )
    func carrierFilter()
    {
        var filters = OneWayFilters()
        filters.carriers = [ "LX", "TP" ]

        #expect( filters.matches( Self.fare( carrier: "LX" ) ) )
        #expect( filters.matches( Self.fare( carrier: "AF" ) ) == false )
        #expect( filters.matches( Self.fare( carrier: nil ) ) == false )
    }

    @Test( "the departure time filter compares minutes since midnight" )
    func departureTimeFilter()
    {
        var filters = OneWayFilters()
        filters.departureStartMinute = 6 * 60
        filters.departureEndMinute   = 14 * 60

        #expect( filters.matches( Self.fare( departureTime: "06:00" ) ) )
        #expect( filters.matches( Self.fare( departureTime: "14:00" ) ) )
        #expect( filters.matches( Self.fare( departureTime: "05:59" ) ) == false )
        #expect( filters.matches( Self.fare( departureTime: "14:01" ) ) == false )
        #expect( filters.matches( Self.fare( departureTime: nil ) ) == false )
    }

    @Test( "the arrival time filter compares minutes since midnight" )
    func arrivalTimeFilter()
    {
        var filters = OneWayFilters()
        filters.arrivalEndMinute = 12 * 60

        #expect( filters.matches( Self.fare( arrivalTime: "11:45" ) ) )
        #expect( filters.matches( Self.fare( arrivalTime: "12:30" ) ) == false )
    }

    @Test( "the duration filter compares total minutes" )
    func durationFilter()
    {
        var filters = OneWayFilters()
        filters.maxDurationMinutes = 3 * 60

        #expect( filters.matches( Self.fare( duration: "2h55" ) ) )
        #expect( filters.matches( Self.fare( duration: "3h00" ) ) )
        #expect( filters.matches( Self.fare( duration: "10h30" ) ) == false )
        #expect( filters.matches( Self.fare( duration: nil ) ) == false )
    }

    @Test( "the max stops filter is an upper bound" )
    func maxStopsFilter()
    {
        var filters = OneWayFilters()
        filters.maxStops = 1

        #expect( filters.matches( Self.fare( stops: 0 ) ) )
        #expect( filters.matches( Self.fare( stops: 1 ) ) )
        #expect( filters.matches( Self.fare( stops: 2 ) ) == false )
        #expect( filters.matches( Self.fare( stops: nil ) ) == false )
    }

    @Test( "a fare matches the flight number filter when any of its segments is selected" )
    func flightNumberFilter()
    {
        var filters = OneWayFilters()
        filters.flightNumbers = [ "LX 1234" ]

        #expect( filters.matches( Self.fare( flightNumbers: [ "LX 1234" ] ) ) )
        #expect( filters.matches( Self.fare( flightNumbers: [ "TP 5678", "LX 1234" ] ) ) )
        #expect( filters.matches( Self.fare( flightNumbers: [ "TP 5678" ] ) ) == false )
        #expect( filters.matches( Self.fare( flightNumbers: [] ) ) == false )
    }

    @Test( "filters combine with AND" )
    func filtersCombine()
    {
        var filters = OneWayFilters()
        filters.maxPrice = 400
        filters.carriers = [ "LX" ]

        let fares = [
            Self.fare( amount: 300, carrier: "LX" ),
            Self.fare( amount: 300, carrier: "TP" ),
            Self.fare( amount: 900, carrier: "LX" ),
        ]

        #expect( filters.apply( to: fares ).count == 1 )
    }

    // MARK: - Parsing

    @Test( "clock times parse into minutes since midnight" )
    func clockTimeParsing()
    {
        #expect( OneWayFilters.minutes( fromClockTime: "00:00" ) == 0 )
        #expect( OneWayFilters.minutes( fromClockTime: "06:35" ) == 395 )
        #expect( OneWayFilters.minutes( fromClockTime: "23:59" ) == 1439 )
    }

    @Test( "malformed clock times parse to nothing" )
    func malformedClockTimeParsing()
    {
        #expect( OneWayFilters.minutes( fromClockTime: nil ) == nil )
        #expect( OneWayFilters.minutes( fromClockTime: "" ) == nil )
        #expect( OneWayFilters.minutes( fromClockTime: "0900" ) == nil )
        #expect( OneWayFilters.minutes( fromClockTime: "ab:cd" ) == nil )
        #expect( OneWayFilters.minutes( fromClockTime: "25:00" ) == nil )
        #expect( OneWayFilters.minutes( fromClockTime: "09:60" ) == nil )
    }

    @Test( "durations parse into total minutes" )
    func durationParsing()
    {
        #expect( OneWayFilters.minutes( fromDuration: "2h05" ) == 125 )
        #expect( OneWayFilters.minutes( fromDuration: "10h30" ) == 630 )
        #expect( OneWayFilters.minutes( fromDuration: "0h45" ) == 45 )
    }

    @Test( "malformed durations parse to nothing" )
    func malformedDurationParsing()
    {
        #expect( OneWayFilters.minutes( fromDuration: nil ) == nil )
        #expect( OneWayFilters.minutes( fromDuration: "" ) == nil )
        #expect( OneWayFilters.minutes( fromDuration: "150" ) == nil )
        #expect( OneWayFilters.minutes( fromDuration: "xhy" ) == nil )
    }

    // MARK: - Days

    @Test( "day offsets count whole UTC days in both directions" )
    func dayIndexes()
    {
        let start = Self.date( 5, hour: 22 )

        #expect( OneWayFilters.dayIndex( for: Self.date( 5, hour: 1 ), from: start ) == 0 )
        #expect( OneWayFilters.dayIndex( for: Self.date( 8 ), from: start ) == 3 )
        #expect( OneWayFilters.dayIndex( for: Self.date( 3 ), from: start ) == -3 )
    }

    @Test( "a day offset resolves to that day's first or last instant" )
    func dayIndexResolution()
    {
        let start = Self.date( 5 )

        let startOfDay = OneWayFilters.date( atDayIndex: 2, from: start, isEndOfDay: false )
        let endOfDay   = OneWayFilters.date( atDayIndex: 2, from: start, isEndOfDay: true )

        #expect( startOfDay == Self.date( 7, hour: 0 ) )
        #expect( endOfDay > startOfDay )
        #expect( endOfDay < Self.date( 8, hour: 0 ) )
        #expect( OneWayFilters.dayIndex( for: endOfDay, from: start ) == 2 )
    }

    @Test( "an end-of-day bound includes a fare departing late that day" )
    func endOfDayBoundIncludesLateDepartures()
    {
        let start = Self.date( 5 )

        var filters = OneWayFilters()
        filters.endDate = OneWayFilters.date( atDayIndex: 0, from: start, isEndOfDay: true )

        #expect( filters.matches( Self.fare( departureDate: Self.date( 5, hour: 23 ) ) ) )
        #expect( filters.matches( Self.fare( departureDate: Self.date( 6, hour: 1 ) ) ) == false )
    }

    // MARK: - Chips

    @Test( "chips describe every active filter, in presentation order" )
    func chipsCoverActiveFilters()
    {
        var filters = OneWayFilters()
        filters.maxPrice             = 320
        filters.carriers             = [ "LX", "TP" ]
        filters.departureStartMinute = 6 * 60
        filters.maxStops             = 0

        let chips = filters.chips()

        #expect( chips.map( \.id ) == [ "price", "carriers", "departure", "stops" ] )
        #expect( chips.count == filters.activeCount )
    }

    @Test( "clearing one chip leaves the other filters alone" )
    func chipClearsOnlyItsOwnFilter() throws
    {
        var filters = OneWayFilters()
        filters.maxPrice = 320
        filters.carriers = [ "LX" ]

        let priceChip = try #require( filters.chips().first { $0.id == "price" } )
        let cleared   = priceChip.cleared

        #expect( cleared.maxPrice == nil )
        #expect( cleared.carriers == [ "LX" ] )
        #expect( cleared.activeCount == 1 )
    }

    @Test( "chip labels summarize one-sided and two-sided ranges" )
    func chipLabels()
    {
        var maxOnly = OneWayFilters()
        maxOnly.maxPrice = 320
        #expect( maxOnly.chips().first?.label == "Price ≤ 320" )

        var both = OneWayFilters()
        both.departureStartMinute = 6 * 60
        both.departureEndMinute   = 14 * 60
        #expect( both.chips().first?.label == "Departs 06:00–14:00" )

        var direct = OneWayFilters()
        direct.maxStops = 0
        #expect( direct.chips().first?.label == "Direct only" )

        var oneStop = OneWayFilters()
        oneStop.maxStops = 1
        #expect( oneStop.chips().first?.label == "≤ 1 stop" )
    }

    @Test( "a selection label spells values out until there are too many to read" )
    func listLabels()
    {
        #expect( OneWayFilters.listLabel( [ "LX", "TP" ], noun: "carriers" ) == "LX, TP" )
        #expect( OneWayFilters.listLabel( [ "A", "B", "C", "D" ], noun: "flights" ) == "4 flights" )
        #expect( OneWayFilters.listLabel( [], noun: "carriers" ) == "No carriers" )
    }

    @Test( "a filter set survives a round trip through its persisted form" )
    func codableRoundTrip() throws
    {
        var filters = OneWayFilters()
        filters.minPrice           = 120
        filters.maxPrice           = 480
        filters.carriers           = [ "LX", "TP" ]
        filters.maxStops           = 1
        filters.flightNumbers      = [ "LX 1234" ]
        filters.minDurationMinutes = 90

        let encoded = try JSONEncoder().encode( filters )
        let decoded = try JSONDecoder().decode( OneWayFilters.self, from: encoded )

        #expect( decoded == filters )
    }
}
