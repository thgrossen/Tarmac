/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

/**
 * The extents a one-way search's filters may be set within, derived from the fares its runs have
 * actually returned.
 *
 * Bounds span every run of the search rather than just the selected one, so a filter keeps meaning
 * the same thing — and its controls keep the same extents — while stepping through updates.
 *
 * A field is nil (or empty) when the data can't support that filter, which includes the degenerate
 * case of a single distinct value: filtering to the one value every fare already has narrows
 * nothing, so those rows are left out of the popover entirely.
 */
struct OneWayFilterBounds: Equatable
{
    var priceRange: ClosedRange< Double >?
    var dateRange: ClosedRange< Date >?
    var carriers: [ String ] = []
    var departureMinuteRange: ClosedRange< Int >?
    var arrivalMinuteRange: ClosedRange< Int >?
    var durationRange: ClosedRange< Int >?
    var stopsRange: ClosedRange< Int >?
    var flightNumbers: [ String ] = []

    // Currency the prices are quoted in, purely so the price filter can label its ends.
    var currency: String?

    /**
     * Whether there is nothing to filter on at all — no run has returned a fare carrying any
     * filterable value, so the whole filter UI has nothing to offer.
     */
    var isEmpty: Bool
    {
        self.priceRange == nil
            && self.dateRange == nil
            && self.carriers.isEmpty
            && self.departureMinuteRange == nil
            && self.arrivalMinuteRange == nil
            && self.durationRange == nil
            && self.stopsRange == nil
            && self.flightNumbers.isEmpty
    }

    /**
     * Derives the filterable extents from every fare of every run of a search.
     *
     * @param runs The search's runs, in any order.
     * @return The bounds each filter may be set within.
     */
    static func bounds( for runs: [ SearchRun ] ) -> OneWayFilterBounds
    {
        let snapshots = runs.flatMap { $0.itineraries }

        var bounds = OneWayFilterBounds()
        bounds.priceRange           = Self.range( of: snapshots.map( \.amount ).filter { $0.isFinite } )
        bounds.dateRange            = Self.range( of: snapshots.compactMap( \.departureDate ) )
        bounds.carriers             = Self.distinct( snapshots.compactMap( \.carrier ) )
        bounds.departureMinuteRange = Self.range( of: snapshots.compactMap { OneWayFilters.minutes( fromClockTime: $0.departureTime ) } )
        bounds.arrivalMinuteRange   = Self.range( of: snapshots.compactMap { OneWayFilters.minutes( fromClockTime: $0.arrivalTime ) } )
        bounds.durationRange        = Self.range( of: snapshots.compactMap { OneWayFilters.minutes( fromDuration: $0.outboundDuration ) } )
        bounds.stopsRange           = Self.range( of: snapshots.compactMap( \.outboundStopCount ) )
        bounds.flightNumbers        = Self.distinct( snapshots.flatMap( \.outboundFlightNumbers ) )
        bounds.currency             = snapshots.first( where: { $0.amount.isFinite } )?.currency
        return bounds
    }

    /**
     * Spans a set of values, treating a single distinct value as unfilterable.
     *
     * @param values Values to span.
     * @return The closed range from the lowest to the highest value, or nil when they are all equal (or there are none).
     */
    private static func range< T: Comparable >( of values: [ T ] ) -> ClosedRange< T >?
    {
        guard let low = values.min(),
              let high = values.max(),
              low < high
        else
        {
            return nil
        }
        return low ... high
    }

    /**
     * Collects the distinct values available to a multi-selection filter, treating a single
     * distinct value as unfilterable.
     *
     * @param values Values to collect, with duplicates.
     * @return The distinct values, sorted, or empty when there are fewer than two of them.
     */
    private static func distinct( _ values: [ String ] ) -> [ String ]
    {
        let distinct = Set( values.filter { $0.isEmpty == false } ).sorted()
        return distinct.count > 1 ? distinct : []
    }
}
