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

    var run: SearchRun?

    init(
        amount: Double,
        currency: String,
        ignavID: String? = nil,
        outboundSummary: String? = nil,
        inboundSummary: String? = nil,
        outboundDuration: String? = nil,
        run: SearchRun? = nil
    )
    {
        self.amount = amount
        self.currency = currency
        self.ignavID = ignavID
        self.outboundSummary = outboundSummary
        self.inboundSummary = inboundSummary
        self.outboundDuration = outboundDuration
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
