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

    /**
     * This run's itineraries, narrowed by the results filters.
     *
     * @param filters Filters to apply, or nil to apply none.
     * @return The matching itineraries, in their recorded order.
     */
    func fares( matching filters: OneWayFilters? ) -> [ PriceSnapshot ]
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
    func fareRange( matching filters: OneWayFilters? ) -> ( low: Double, high: Double )?
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
