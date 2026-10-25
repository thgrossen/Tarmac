/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData

enum PriceSnapshotBackfill
{
    /**
     * Separator joining a leg's segments in `PriceSnapshot.outboundSummary` and
     * `PriceSnapshot.inboundSummary`, e.g. "LX 1234 → TP 5678".
     */
    static let flightNumberSeparator = " → "

    /**
     * Fills in each leg's stop count and per-segment flight numbers on fares recorded before those
     * were stored in their own right, recovering them from the summary strings those fares already
     * carry so existing run history is filterable too.
     *
     * Idempotent: a leg that already has a stop count is left alone, so this is safe to run on
     * every launch.
     *
     * @param context Model context holding the fares to backfill.
     */
    static func backfillIfNeeded( in context: ModelContext )
    {
        let outbound        = FetchDescriptor< PriceSnapshot >( predicate: #Predicate { $0.outboundStopCount == nil } )
        let pendingOutbound = ( try? context.fetch( outbound ) ) ?? []

        // A fare whose summary yields nothing has no segments to count, so its stop count stays
        // unknown rather than being recorded as a direct flight.
        for snapshot in pendingOutbound
        {
            let flightNumbers = Self.flightNumbers( from: snapshot.outboundSummary )
            guard flightNumbers.isEmpty == false
            else
            {
                continue
            }

            snapshot.outboundFlightNumbers = flightNumbers
            snapshot.outboundStopCount     = flightNumbers.count - 1
        }

        // Only a round trip's fares carry an inbound summary, so a one-way fare is never fetched here.
        let inbound        = FetchDescriptor< PriceSnapshot >( predicate: #Predicate { $0.inboundStopCount == nil && $0.inboundSummary != nil } )
        let pendingInbound = ( try? context.fetch( inbound ) ) ?? []

        for snapshot in pendingInbound
        {
            let flightNumbers = Self.flightNumbers( from: snapshot.inboundSummary )
            guard flightNumbers.isEmpty == false
            else
            {
                continue
            }

            snapshot.inboundFlightNumbers = flightNumbers
            snapshot.inboundStopCount     = flightNumbers.count - 1
        }

        guard pendingOutbound.isEmpty == false || pendingInbound.isEmpty == false
        else
        {
            return
        }
        try? context.save()
    }

    /**
     * Recovers a leg's per-segment flight numbers from its summary string.
     *
     * @param summary Summary as stored on a fare, e.g. "LX 1234 → TP 5678", or nil.
     * @return One entry per segment, in order; empty when the summary is missing or blank.
     */
    static func flightNumbers( from summary: String? ) -> [ String ]
    {
        guard let summary
        else
        {
            return []
        }

        return summary
            .components( separatedBy: Self.flightNumberSeparator )
            .map { $0.trimmingCharacters( in: .whitespaces ) }
            .filter { $0.isEmpty == false }
    }
}
