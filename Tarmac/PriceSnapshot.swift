/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData

@Model
final class PriceSnapshot
{
    var amount: Double
    var currency: String
    var ignavID: String?
    var outboundSummary: String?
    var inboundSummary: String?
    var outboundDuration: String?
    var carrier: String?
    var departureTime: String?
    var arrivalTime: String?
    var departureDate: Date?
    var inboundDepartureTime: String? = nil
    var inboundDepartureDate: Date? = nil
    var inboundArrivalTime: String? = nil
    var inboundDuration: String? = nil
    var outboundStopCount: Int? = nil
    var inboundStopCount: Int? = nil
    var outboundFlightNumbers: [ String ] = []
    var inboundFlightNumbers: [ String ] = []

    // Booking links already resolved for this fare, kept so switching searches, adding runs or
    // relaunching the app doesn't spend another billed lookup for the same result. They stop
    // being offered once the run falls outside the booking-link lifetime.
    var bookingLinks: [ BookingLinkChoice ] = []

    var run: SearchRun?

    init(
        amount: Double,
        currency: String,
        ignavID: String? = nil,
        outboundSummary: String? = nil,
        inboundSummary: String? = nil,
        outboundDuration: String? = nil,
        carrier: String? = nil,
        departureTime: String? = nil,
        arrivalTime: String? = nil,
        departureDate: Date? = nil,
        inboundDepartureTime: String? = nil,
        inboundDepartureDate: Date? = nil,
        inboundArrivalTime: String? = nil,
        inboundDuration: String? = nil,
        outboundStopCount: Int? = nil,
        inboundStopCount: Int? = nil,
        outboundFlightNumbers: [ String ] = [],
        inboundFlightNumbers: [ String ] = [],
        run: SearchRun? = nil
    )
    {
        self.amount = amount
        self.currency = currency
        self.ignavID = ignavID
        self.outboundSummary = outboundSummary
        self.inboundSummary = inboundSummary
        self.outboundDuration = outboundDuration
        self.carrier = carrier
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.departureDate = departureDate
        self.inboundDepartureTime = inboundDepartureTime
        self.inboundDepartureDate = inboundDepartureDate
        self.inboundArrivalTime = inboundArrivalTime
        self.inboundDuration = inboundDuration
        self.outboundStopCount = outboundStopCount
        self.inboundStopCount = inboundStopCount
        self.outboundFlightNumbers = outboundFlightNumbers
        self.inboundFlightNumbers = inboundFlightNumbers
        self.run = run
    }

    /**
     * Amount and currency for display, e.g. "397 CHF", or `nil` when `amount` isn't finite
     * (e.g. an unparseable price from the API).
     */
    var formattedAmount: String?
    {
        guard self.amount.isFinite
        else
        {
            return nil
        }

        return "\( Int( self.amount )) \( self.currency )"
    }

    /**
     * The marketing carrier of every segment the fare flies, outbound then inbound, read off the
     * front of each segment's flight number. A segment recorded without a carrier yields an empty
     * code rather than being skipped, so it can never pass for one flown by a selected carrier.
     *
     * @return One code per segment, e.g. [ "LX", "TP", "TP" ]; empty when no segment was recorded.
     */
    var carrierCodes: [ String ]
    {
        ( self.outboundFlightNumbers + self.inboundFlightNumbers ).map { flightNumber in String( flightNumber.prefix { $0 != " " } ) }
    }

    // Autoupdating rather than a snapshot, so each reading resolves against the zone in force at
    // the time: this is read per fare while a trip-duration filter is active, and a search's results
    // outlive a change of time zone.
    private static let localCalendar = Calendar.autoupdatingCurrent

    /**
     * How long the round trip lasts, counted in nights: the whole-day difference between the
     * outbound and inbound departure dates, not the inclusive day count. An outbound departing
     * 5 October and an inbound departing 8 October is 3, matching the number
     * `SavedSearch.tripDurationDays` was configured with rather than being off by one against it.
     *
     * Both dates are instants derived from local wall-clock times, so they are normalised in the
     * current zone — the one their strings were parsed in — before differencing. That makes these
     * whole *local* days, where `ResultFilters` buckets its date filters into whole UTC ones.
     *
     * @return The number of nights, or `nil` for a one-way fare, a fare missing either date, or
     *         an inbound departing before the outbound.
     */
    var tripDurationDays: Int?
    {
        guard let departureDate = self.departureDate,
              let inboundDepartureDate = self.inboundDepartureDate
        else
        {
            return nil
        }

        let calendar = Self.localCalendar
        let outboundDay = calendar.startOfDay( for: departureDate )
        let inboundDay = calendar.startOfDay( for: inboundDepartureDate )

        guard let days = calendar.dateComponents( [ .day ], from: outboundDay, to: inboundDay ).day,
              days >= 0
        else
        {
            return nil
        }

        return days
    }
}
