/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

/**
 * How far a search's sweep has got: how many of its planned Ignav requests have been made.
 * A sweep knows its full request count before firing the first one, so progress can be counted
 * rather than merely animated — but only once there are enough requests for a bar to say
 * anything a spinner doesn't.
 */
struct SearchProgress: Equatable, Sendable
{
    /**
     * Smallest planned request count that earns a determinate bar. Below it a sweep finishes in
     * one or two jumps, where a bar reads as a glitch rather than as progress.
     */
    nonisolated static let determinateMinimumRequests = 3

    let completed: Int
    let total: Int

    /**
     * @param completed Requests already made, clamped into `0...total`.
     * @param total Requests the sweep plans to make; negatives are treated as none.
     */
    init( completed: Int, total: Int )
    {
        let plannedTotal = max( 0, total )

        self.total     = plannedTotal
        self.completed = min( max( 0, completed ), plannedTotal )
    }

    /**
     * Whether this sweep is worth showing as a counted bar rather than an indeterminate spinner.
     */
    var isDeterminate: Bool
    {
        self.total >= Self.determinateMinimumRequests
    }

    /**
     * Share of the sweep already made, in `0...1`, and 0 for a sweep with nothing planned.
     */
    var fraction: Double
    {
        guard self.total > 0
        else
        {
            return 0
        }

        return Double( self.completed ) / Double( self.total )
    }

    /**
     * The share made as a rounded percentage, e.g. "29%". Held at "99%" until the last request
     * lands, so a long sweep never reads as finished while requests are still in flight.
     */
    var percentText: String
    {
        guard self.total > 0
        else
        {
            return "0%"
        }

        guard self.completed < self.total
        else
        {
            return "100%"
        }

        let percent = Int( ( self.fraction * 100 ).rounded() )

        return "\( min( percent, 99 ) )%"
    }

    /**
     * The counts in words, e.g. "7 of 24 requests".
     */
    var countText: String
    {
        "\( self.completed ) of \( self.total ) \( self.total == 1 ? "request" : "requests" )"
    }

    /**
     * Percentage and counts together, e.g. "29% (7 of 24 requests)" — the tail each call site
     * appends to its own verb, so the two never word progress differently.
     */
    var detailText: String
    {
        "\( self.percentText ) (\( self.countText ))"
    }
}
