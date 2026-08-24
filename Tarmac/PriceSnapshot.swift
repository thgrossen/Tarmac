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
}
