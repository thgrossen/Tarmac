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
     * Change in cheapest fare relative to a previous run, e.g. for a "price movement"
     * indicator. Negative means this run is cheaper than `previous`.
     *
     * @param previous Chronologically preceding run to compare against, if any.
     * @return The difference in cheapest-fare amount, or nil if either run found no fares.
     */
    func priceDelta( previous: SearchRun? ) -> Double?
    {
        guard let cheapest = self.cheapestFare?.amount,
              let previousCheapest = previous?.cheapestFare?.amount
        else
        {
            return nil
        }
        return cheapest - previousCheapest
    }
}

extension Array where Element == SearchRun
{
    /**
     * Pairs each run in a newest-first list with the run chronologically immediately
     * before it (i.e. the next element in the list), or nil for the oldest run.
     *
     * @return One pair per run, in the same order as the receiver.
     */
    func pairedWithPrevious() -> [ ( run: SearchRun, previous: SearchRun? ) ]
    {
        self.enumerated().map
        { index, run in
            ( run, index + 1 < self.count ? self[ index + 1 ] : nil )
        }
    }
}
