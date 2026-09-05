/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "ResultFilters" )
struct ResultFiltersTests
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

    private static func roundTripFare(
        amount: Double = 300,
        departureDate: Date? = Self.date( 5 ),
        inboundDepartureDate: Date? = Self.date( 8 ),
        inboundDepartureTime: String? = "18:00"
    ) -> PriceSnapshot
    {
        PriceSnapshot(
            amount: amount,
            currency: "CHF",
            outboundSummary: "LX 1234",
            inboundSummary: "LX 5678",
            outboundDuration: "2h30",
            carrier: "LX",
            departureTime: "08:00",
            arrivalTime: "10:30",
            departureDate: departureDate,
            inboundDepartureTime: inboundDepartureTime,
            inboundDepartureDate: inboundDepartureDate,
            outboundStopCount: 0,
            outboundFlightNumbers: [ "LX 1234" ]
        )
    }

    // MARK: - State

    @Test( "a freshly created filter set is inactive" )
    func emptyFiltersAreInactive()
    {
        let filters = ResultFilters()

        #expect( filters.isActive == false )
        #expect( filters.activeCount == 0 )
    }

    @Test( "a range filter counts once however many of its ends are set" )
    func rangeFilterCountsOnce()
    {
        var filters = ResultFilters()
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
        var filters = ResultFilters()
        filters.carriers = []

        #expect( filters.isActive )
        #expect( filters.apply( to: [ Self.fare() ] ).isEmpty )
    }

    // MARK: - Matching

    @Test( "an inactive filter set keeps every fare" )
    func inactiveFiltersKeepEverything()
    {
        let fares = [ Self.fare( amount: 100 ), Self.fare( amount: 900 ) ]

        #expect( ResultFilters().apply( to: fares ).count == 2 )
    }

    @Test( "the price filter keeps fares inside its bounds, inclusively" )
    func priceFilter()
    {
        var filters = ResultFilters()
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
        var filters = ResultFilters()
        filters.maxPrice = 400

        #expect( filters.matches( Self.fare( amount: .nan ) ) == false )
    }

    @Test( "the date filter keeps fares departing inside its bounds" )
    func dateFilter()
    {
        var filters = ResultFilters()
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
        var filters = ResultFilters()
        filters.carriers = [ "LX", "TP" ]

        #expect( filters.matches( Self.fare( carrier: "LX" ) ) )
        #expect( filters.matches( Self.fare( carrier: "AF" ) ) == false )
        #expect( filters.matches( Self.fare( carrier: nil ) ) == false )
    }

    @Test( "the departure time filter compares minutes since midnight" )
    func departureTimeFilter()
    {
        var filters = ResultFilters()
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
        var filters = ResultFilters()
        filters.arrivalEndMinute = 12 * 60

        #expect( filters.matches( Self.fare( arrivalTime: "11:45" ) ) )
        #expect( filters.matches( Self.fare( arrivalTime: "12:30" ) ) == false )
    }

    @Test( "the duration filter compares total minutes" )
    func durationFilter()
    {
        var filters = ResultFilters()
        filters.maxDurationMinutes = 3 * 60

        #expect( filters.matches( Self.fare( duration: "2h55" ) ) )
        #expect( filters.matches( Self.fare( duration: "3h00" ) ) )
        #expect( filters.matches( Self.fare( duration: "10h30" ) ) == false )
        #expect( filters.matches( Self.fare( duration: nil ) ) == false )
    }

    @Test( "the max stops filter is an upper bound" )
    func maxStopsFilter()
    {
        var filters = ResultFilters()
        filters.maxStops = 1

        #expect( filters.matches( Self.fare( stops: 0 ) ) )
        #expect( filters.matches( Self.fare( stops: 1 ) ) )
        #expect( filters.matches( Self.fare( stops: 2 ) ) == false )
        #expect( filters.matches( Self.fare( stops: nil ) ) == false )
    }

    @Test( "a fare matches the flight number filter when any of its segments is selected" )
    func flightNumberFilter()
    {
        var filters = ResultFilters()
        filters.flightNumbers = [ "LX 1234" ]

        #expect( filters.matches( Self.fare( flightNumbers: [ "LX 1234" ] ) ) )
        #expect( filters.matches( Self.fare( flightNumbers: [ "TP 5678", "LX 1234" ] ) ) )
        #expect( filters.matches( Self.fare( flightNumbers: [ "TP 5678" ] ) ) == false )
        #expect( filters.matches( Self.fare( flightNumbers: [] ) ) == false )
    }

    @Test( "filters combine with AND" )
    func filtersCombine()
    {
        var filters = ResultFilters()
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
        #expect( ResultFilters.minutes( fromClockTime: "00:00" ) == 0 )
        #expect( ResultFilters.minutes( fromClockTime: "06:35" ) == 395 )
        #expect( ResultFilters.minutes( fromClockTime: "23:59" ) == 1439 )
    }

    @Test( "malformed clock times parse to nothing" )
    func malformedClockTimeParsing()
    {
        #expect( ResultFilters.minutes( fromClockTime: nil ) == nil )
        #expect( ResultFilters.minutes( fromClockTime: "" ) == nil )
        #expect( ResultFilters.minutes( fromClockTime: "0900" ) == nil )
        #expect( ResultFilters.minutes( fromClockTime: "ab:cd" ) == nil )
        #expect( ResultFilters.minutes( fromClockTime: "25:00" ) == nil )
        #expect( ResultFilters.minutes( fromClockTime: "09:60" ) == nil )
    }

    @Test( "durations parse into total minutes" )
    func durationParsing()
    {
        #expect( ResultFilters.minutes( fromDuration: "2h05" ) == 125 )
        #expect( ResultFilters.minutes( fromDuration: "10h30" ) == 630 )
        #expect( ResultFilters.minutes( fromDuration: "0h45" ) == 45 )
    }

    @Test( "malformed durations parse to nothing" )
    func malformedDurationParsing()
    {
        #expect( ResultFilters.minutes( fromDuration: nil ) == nil )
        #expect( ResultFilters.minutes( fromDuration: "" ) == nil )
        #expect( ResultFilters.minutes( fromDuration: "150" ) == nil )
        #expect( ResultFilters.minutes( fromDuration: "xhy" ) == nil )
    }

    // MARK: - Days

    @Test( "day offsets count whole UTC days in both directions" )
    func dayIndexes()
    {
        let start = Self.date( 5, hour: 22 )

        #expect( ResultFilters.dayIndex( for: Self.date( 5, hour: 1 ), from: start ) == 0 )
        #expect( ResultFilters.dayIndex( for: Self.date( 8 ), from: start ) == 3 )
        #expect( ResultFilters.dayIndex( for: Self.date( 3 ), from: start ) == -3 )
    }

    @Test( "a day offset resolves to that day's first or last instant" )
    func dayIndexResolution()
    {
        let start = Self.date( 5 )

        let startOfDay = ResultFilters.date( atDayIndex: 2, from: start, isEndOfDay: false )
        let endOfDay   = ResultFilters.date( atDayIndex: 2, from: start, isEndOfDay: true )

        #expect( startOfDay == Self.date( 7, hour: 0 ) )
        #expect( endOfDay > startOfDay )
        #expect( endOfDay < Self.date( 8, hour: 0 ) )
        #expect( ResultFilters.dayIndex( for: endOfDay, from: start ) == 2 )
    }

    @Test( "an end-of-day bound includes a fare departing late that day" )
    func endOfDayBoundIncludesLateDepartures()
    {
        let start = Self.date( 5 )

        var filters = ResultFilters()
        filters.endDate = ResultFilters.date( atDayIndex: 0, from: start, isEndOfDay: true )

        #expect( filters.matches( Self.fare( departureDate: Self.date( 5, hour: 23 ) ) ) )
        #expect( filters.matches( Self.fare( departureDate: Self.date( 6, hour: 1 ) ) ) == false )
    }

    // MARK: - Chips

    @Test( "chips describe every active filter, in presentation order" )
    func chipsCoverActiveFilters()
    {
        var filters = ResultFilters()
        filters.maxPrice             = 320
        filters.carriers             = [ "LX", "TP" ]
        filters.departureStartMinute = 6 * 60
        filters.maxStops             = 0
        filters.maxTripDurationDays  = 5
        filters.inboundStartDate     = Self.date( 8 )

        // Round-trip, since a one-way search can never hold a trip-duration or inbound filter: its
        // fares supply no extents for them, so those rows are never offered.
        let chips = filters.chips( isRoundTrip: true )

        // The order is the popover's, so the trip duration sits second and the inbound rows last.
        #expect( chips.map( \.id ) == [ "price", "tripDuration", "carriers", "departure", "stops", "inboundDate" ] )
        #expect( chips.count == filters.activeCount )
    }

    @Test( "clearing one chip leaves the other filters alone" )
    func chipClearsOnlyItsOwnFilter() throws
    {
        var filters = ResultFilters()
        filters.maxPrice = 320
        filters.carriers = [ "LX" ]

        let priceChip = try #require( filters.chips( isRoundTrip: false ).first { $0.id == "price" } )
        let cleared   = priceChip.cleared

        #expect( cleared.maxPrice == nil )
        #expect( cleared.carriers == [ "LX" ] )
        #expect( cleared.activeCount == 1 )
    }

    @Test( "chip labels summarize one-sided and two-sided ranges" )
    func chipLabels()
    {
        var maxOnly = ResultFilters()
        maxOnly.maxPrice = 320
        #expect( maxOnly.chips( isRoundTrip: false ).first?.label == "Price ≤ 320" )

        var both = ResultFilters()
        both.departureStartMinute = 6 * 60
        both.departureEndMinute   = 14 * 60
        #expect( both.chips( isRoundTrip: false ).first?.label == "Departs 06:00–14:00" )

        var direct = ResultFilters()
        direct.maxStops = 0
        #expect( direct.chips( isRoundTrip: false ).first?.label == "Direct only" )

        var oneStop = ResultFilters()
        oneStop.maxStops = 1
        #expect( oneStop.chips( isRoundTrip: false ).first?.label == "≤ 1 stop" )
        #expect( oneStop.chips( isRoundTrip: true ).first?.label == "Outbound ≤ 1 stop" )
    }

    @Test( "a round trip's chips name the leg they narrow, as its popover rows do" )
    func chipLabelsNameTheOutboundLeg()
    {
        var filters = ResultFilters()
        filters.startDate            = Self.date( 5 )
        filters.endDate              = Self.date( 12 )
        filters.departureStartMinute = 6 * 60
        filters.arrivalEndMinute     = 23 * 60
        filters.maxDurationMinutes   = 5 * 60
        filters.maxStops             = 0

        let oneWay = Dictionary( uniqueKeysWithValues: filters.chips( isRoundTrip: false ).map { ( $0.id, $0.label ) } )
        #expect( oneWay[ "date" ] == "Date 5 Oct–12 Oct" )
        #expect( oneWay[ "departure" ] == "Departs ≥ 06:00" )
        #expect( oneWay[ "arrival" ] == "Arrives ≤ 23:00" )
        #expect( oneWay[ "duration" ] == "Duration ≤ 5h00" )
        #expect( oneWay[ "stops" ] == "Direct only" )

        let roundTrip = Dictionary( uniqueKeysWithValues: filters.chips( isRoundTrip: true ).map { ( $0.id, $0.label ) } )
        #expect( roundTrip[ "date" ] == "Outbound date 5 Oct–12 Oct" )
        #expect( roundTrip[ "departure" ] == "Outbound departure ≥ 06:00" )
        #expect( roundTrip[ "arrival" ] == "Outbound arrival ≤ 23:00" )
        #expect( roundTrip[ "duration" ] == "Outbound duration ≤ 5h00" )
        #expect( roundTrip[ "stops" ] == "Outbound direct only" )
    }

    @Test( "a round trip's carrier and flight-number chips say which leg's codes they list" )
    func multiSelectionChipsNameTheOutboundLeg()
    {
        var filters = ResultFilters()
        filters.carriers      = [ "LX", "TP" ]
        filters.flightNumbers = [ "LX 1234" ]

        let oneWay = Dictionary( uniqueKeysWithValues: filters.chips( isRoundTrip: false ).map { ( $0.id, $0.label ) } )
        #expect( oneWay[ "carriers" ] == "LX, TP" )
        #expect( oneWay[ "flightNumbers" ] == "LX 1234" )

        // A bare list of codes is the one chip shape carrying no noun at all, and the round-trip
        // table prints both legs' flight numbers identically — so the qualifier is what tells them
        // apart.
        let roundTrip = Dictionary( uniqueKeysWithValues: filters.chips( isRoundTrip: true ).map { ( $0.id, $0.label ) } )
        #expect( roundTrip[ "carriers" ] == "Outbound carriers: LX, TP" )
        #expect( roundTrip[ "flightNumbers" ] == "Outbound flight n°: LX 1234" )
    }

    @Test( "the price chip reads the same whatever legs the search has, since it isn't a leg's value" )
    func priceChipIsNotQualified()
    {
        var filters = ResultFilters()
        filters.maxPrice = 320

        #expect( filters.chips( isRoundTrip: false ).first?.label == "Price ≤ 320" )
        #expect( filters.chips( isRoundTrip: true ).first?.label == "Price ≤ 320" )
    }

    // MARK: - Round-trip filters

    @Test( "a trip-duration filter keeps the nights it spans and drops the rest" )
    func tripDurationMatching()
    {
        var filters = ResultFilters()
        filters.minTripDurationDays = 3
        filters.maxTripDurationDays = 5

        // Nights are counted from the outbound date, which is the 5th throughout.
        #expect( filters.matches( Self.roundTripFare( inboundDepartureDate: Self.date( 8 ) ) ) )
        #expect( filters.matches( Self.roundTripFare( inboundDepartureDate: Self.date( 10 ) ) ) )
        #expect( filters.matches( Self.roundTripFare( inboundDepartureDate: Self.date( 7 ) ) ) == false )
        #expect( filters.matches( Self.roundTripFare( inboundDepartureDate: Self.date( 11 ) ) ) == false )

        // A one-way fare carries no trip duration at all, and an active filter never lets a value
        // it can't read through.
        #expect( filters.matches( Self.fare() ) == false )
        #expect( filters.matches( Self.roundTripFare( inboundDepartureDate: nil ) ) == false )
    }

    @Test( "an inbound-date filter tests the return's departure date, not the outbound one" )
    func inboundDateMatching()
    {
        var filters = ResultFilters()
        filters.inboundStartDate = Self.date( 8, hour: 0 )
        filters.inboundEndDate   = Self.date( 12, hour: 23 )

        #expect( filters.matches( Self.roundTripFare( inboundDepartureDate: Self.date( 8 ) ) ) )
        #expect( filters.matches( Self.roundTripFare( inboundDepartureDate: Self.date( 12 ) ) ) )
        #expect( filters.matches( Self.roundTripFare( inboundDepartureDate: Self.date( 7 ) ) ) == false )
        #expect( filters.matches( Self.roundTripFare( inboundDepartureDate: Self.date( 13 ) ) ) == false )

        // Every fare above departs on the 5th, well outside the filter's own span, so only the
        // inbound date can be deciding these.
        #expect( filters.matches( Self.fare() ) == false )
    }

    @Test( "an inbound-departure filter tests the return's clock time" )
    func inboundDepartureMatching()
    {
        var filters = ResultFilters()
        filters.inboundDepartureStartMinute = 17 * 60

        #expect( filters.matches( Self.roundTripFare( inboundDepartureTime: "17:00" ) ) )
        #expect( filters.matches( Self.roundTripFare( inboundDepartureTime: "23:30" ) ) )
        #expect( filters.matches( Self.roundTripFare( inboundDepartureTime: "16:59" ) ) == false )
        #expect( filters.matches( Self.roundTripFare( inboundDepartureTime: nil ) ) == false )

        // The outbound leg departs at 08:00 on every one of those fares, so it isn't being read.
        var outbound = ResultFilters()
        outbound.departureStartMinute = 17 * 60
        #expect( outbound.matches( Self.roundTripFare( inboundDepartureTime: "23:30" ) ) == false )
    }

    @Test( "each round-trip filter counts once and gets one removable chip" )
    func roundTripChips() throws
    {
        var filters = ResultFilters()
        filters.minTripDurationDays         = 2
        filters.maxTripDurationDays         = 5
        filters.inboundStartDate            = Self.date( 8 )
        filters.inboundEndDate              = Self.date( 12 )
        filters.inboundDepartureStartMinute = 17 * 60

        #expect( filters.activeCount == 3 )

        let chips = filters.chips( isRoundTrip: true )
        #expect( chips.map( \.id ) == [ "tripDuration", "inboundDate", "inboundDeparture" ] )
        #expect( chips.map( \.label ) == [ "Trip 2–5 nights", "Inbound date 8 Oct–12 Oct", "Inbound departure ≥ 17:00" ] )
        #expect( chips.count == filters.activeCount )

        let tripChip = try #require( chips.first { $0.id == "tripDuration" } )
        #expect( tripChip.cleared.minTripDurationDays == nil )
        #expect( tripChip.cleared.maxTripDurationDays == nil )
        #expect( tripChip.cleared.inboundStartDate == Self.date( 8 ) )
        #expect( tripChip.cleared.activeCount == 2 )
    }

    @Test( "the trip-duration chip agrees with its own upper bound about nights" )
    func tripDurationChipPluralization()
    {
        var oneNight = ResultFilters()
        oneNight.maxTripDurationDays = 1
        #expect( oneNight.chips( isRoundTrip: true ).first?.label == "Trip ≤ 1 night" )

        var atLeastTwo = ResultFilters()
        atLeastTwo.minTripDurationDays = 2
        #expect( atLeastTwo.chips( isRoundTrip: true ).first?.label == "Trip ≥ 2 nights" )

        // Reachable once a fare returns the day it departs, which makes a lower bound of one night
        // selectable — the label ends in that bound, so the plural has to follow it.
        var atLeastOne = ResultFilters()
        atLeastOne.minTripDurationDays = 1
        #expect( atLeastOne.chips( isRoundTrip: true ).first?.label == "Trip ≥ 1 night" )
    }

    @Test( "a selection label spells values out until there are too many to read" )
    func listLabels()
    {
        #expect( ResultFilters.listLabel( [ "LX", "TP" ], noun: "carriers" ) == "LX, TP" )
        #expect( ResultFilters.listLabel( [ "A", "B", "C", "D" ], noun: "flights" ) == "4 flights" )
        #expect( ResultFilters.listLabel( [], noun: "carriers" ) == "No carriers" )
    }

    @Test( "a filter set survives a round trip through its persisted form" )
    func codableRoundTrip() throws
    {
        var filters = ResultFilters()
        filters.minPrice           = 120
        filters.maxPrice           = 480
        filters.carriers           = [ "LX", "TP" ]
        filters.maxStops           = 1
        filters.flightNumbers      = [ "LX 1234" ]
        filters.minDurationMinutes = 90

        filters.minTripDurationDays         = 2
        filters.maxTripDurationDays         = 5
        filters.inboundStartDate            = Self.date( 8 )
        filters.inboundEndDate              = Self.date( 12 )
        filters.inboundDepartureStartMinute = 17 * 60
        filters.inboundDepartureEndMinute   = 21 * 60

        let encoded = try JSONEncoder().encode( filters )
        let decoded = try JSONDecoder().decode( ResultFilters.self, from: encoded )

        #expect( decoded == filters )
    }

    @Test( "a filter set stored before the round-trip filters existed still decodes" )
    func storedSetWithoutRoundTripFiltersDecodes() throws
    {
        // Exactly what an earlier build wrote: the round-trip keys are absent rather than null.
        let stored  = Data( #"{"maxPrice":400,"maxStops":0}"#.utf8 )
        let decoded = try JSONDecoder().decode( ResultFilters.self, from: stored )

        #expect( decoded.maxPrice == 400 )
        #expect( decoded.maxStops == 0 )
        #expect( decoded.minTripDurationDays == nil )
        #expect( decoded.maxTripDurationDays == nil )
        #expect( decoded.inboundStartDate == nil )
        #expect( decoded.inboundEndDate == nil )
        #expect( decoded.inboundDepartureStartMinute == nil )
        #expect( decoded.inboundDepartureEndMinute == nil )

        // The set reads exactly as it did before the new fields were added.
        #expect( decoded.activeCount == 2 )
        #expect( decoded.chips( isRoundTrip: false ).map( \.label ) == [ "Price ≤ 400", "Direct only" ] )
    }
}
