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

    /**
     * Set when a round-trip sweep's cap kept it from covering every date pair it could have,
     * stating how many of them it did cover. Nil on a round-trip run that searched its whole
     * matrix, and on every one-way run — one-way sweeps cap and sample too, but do not yet
     * report it.
     */
    var truncationMessage: String?

    var requestCount: Int

    var savedSearch: SavedSearch?

    @Relationship( deleteRule: .cascade, inverse: \PriceSnapshot.run )     var itineraries: [ PriceSnapshot ] = []

    init(
        id: UUID = UUID(),
        runAt: Date = .now,
        rawJSON: String? = nil,
        errorMessage: String? = nil,
        partialFailureMessage: String? = nil,
        truncationMessage: String? = nil,
        requestCount: Int,
        savedSearch: SavedSearch? = nil
    )
    {
        self.id = id
        self.runAt = runAt
        self.rawJSON = rawJSON
        self.errorMessage = errorMessage
        self.partialFailureMessage = partialFailureMessage
        self.truncationMessage = truncationMessage
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

    /**
     * This run's itineraries, narrowed by the results filters.
     *
     * @param filters Filters to apply, or nil to apply none.
     * @return The matching itineraries, in their recorded order.
     */
    func fares( matching filters: ResultFilters? ) -> [ PriceSnapshot ]
    {
        filters?.apply( to: self.itineraries ) ?? self.itineraries
    }

    /**
     * The price span this run's matching itineraries cover, which is what the price history chart
     * plots as one bar. Prices that failed to parse are left out, so they can't drag the span to
     * something meaningless.
     *
     * @param filters Filters to apply, or nil to apply none.
     * @return The cheapest and most expensive matching price, or nil if nothing matched.
     */
    func fareRange( matching filters: ResultFilters? ) -> ( low: Double, high: Double )?
    {
        let amounts = self.fares( matching: filters ).map( \.amount ).filter { $0.isFinite }
        guard let low = amounts.min(),
              let high = amounts.max()
        else
        {
            return nil
        }
        return ( low, high )
    }
}
