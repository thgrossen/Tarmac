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
}
