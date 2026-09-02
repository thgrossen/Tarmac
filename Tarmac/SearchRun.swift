/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData

@Model
final class SearchRun
{
    var id: UUID
    var runAt: Date
    var rawJSON: String?
    var errorMessage: String?
    var partialFailureMessage: String?
    var requestCount: Int

    var savedSearch: SavedSearch?

    @Relationship( deleteRule: .cascade, inverse: \PriceSnapshot.run )     var itineraries: [ PriceSnapshot ] = []

    init(
        id: UUID = UUID(),
        runAt: Date = .now,
        rawJSON: String? = nil,
        errorMessage: String? = nil,
        partialFailureMessage: String? = nil,
        requestCount: Int,
        savedSearch: SavedSearch? = nil
    )
    {
        self.id = id
        self.runAt = runAt
        self.rawJSON = rawJSON
        self.errorMessage = errorMessage
        self.partialFailureMessage = partialFailureMessage
        self.requestCount = requestCount
        self.savedSearch = savedSearch
    }

    /**
     * Cheapest itinerary found by this run, or nil if it found none.
     */
    var cheapestFare: PriceSnapshot?
    {
        self.itineraries.min { $0.amount < $1.amount }
    }

    /**
     * Most expensive itinerary found by this run, or nil if it found none.
     */
    var maxFare: PriceSnapshot?
    {
        self.itineraries.max { $0.amount < $1.amount }
    }
}
