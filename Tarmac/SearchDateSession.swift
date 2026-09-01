/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import Observation

/**
 * In-memory, non-persisted record of the departure date range last used for each search
 * kind, so a second new search created later in the same app session picks up the
 * previous one's dates. Starts empty on every launch; never written to disk.
 */
@Observable
final class SearchDateSession
{
    struct DateRange: Equatable
    {
        var start: Date
        var end: Date
    }

    private( set ) var ranges: [ SearchKind: DateRange ] = [ : ]

    /**
     * The departure date range last used for a search kind this session, if any.
     *
     * @param kind Search kind to look up.
     * @return The recorded range, or nil if none has been recorded yet this session.
     */
    func range( for kind: SearchKind ) -> DateRange?
    {
        self.ranges[ kind ]
    }

    /**
     * Records the departure date range just used for a search kind.
     *
     * @param range Range to remember.
     * @param kind Search kind the range applies to.
     */
    func recordRange( _ range: DateRange, for kind: SearchKind )
    {
        self.ranges[ kind ] = range
    }
}
