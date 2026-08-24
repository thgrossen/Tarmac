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
    var checkedAt: Date          // quand la requête a été faite
    var origin: String
    var destination: String
    var departureDate: String    // "YYYY-MM-DD"
    var returnDate: String?
    var cabinClass: String
    var amount: Double
    var currency: String
    var ignavID: String?

    init(
        checkedAt: Date = .now,
        origin: String,
        destination: String,
        departureDate: String,
        returnDate: String? = nil,
        cabinClass: String,
        amount: Double,
        currency: String,
        ignavID: String? = nil
    )
    {
        self.checkedAt = checkedAt
        self.origin = origin
        self.destination = destination
        self.departureDate = departureDate
        self.returnDate = returnDate
        self.cabinClass = cabinClass
        self.amount = amount
        self.currency = currency
        self.ignavID = ignavID
    }
}
