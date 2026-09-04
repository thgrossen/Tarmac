/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import Observation

@Observable
final class RefreshState
{
    private( set ) var loadingSearchIDs: Set< UUID > = []
    private( set ) var errorMessages: [ UUID: String ] = [ : ]
    private( set ) var progressBySearchID: [ UUID: SearchProgress ] = [ : ]

    func isLoading( _ id: UUID ) -> Bool
    {
        self.loadingSearchIDs.contains( id )
    }

    func errorMessage( for id: UUID ) -> String?
    {
        self.errorMessages[ id ]
    }

    /**
     * How far a search's refresh has got, or nil when it isn't refreshing — or is refreshing but
     * hasn't reported yet.
     *
     * @param id Identifier of the SavedSearch to report on.
     * @return The search's latest progress, or nil.
     */
    func progress( for id: UUID ) -> SearchProgress?
    {
        self.progressBySearchID[ id ]
    }

    /**
     * Marks a search as refreshing and clears the error and progress left over from a previous run.
     *
     * @param id Identifier of the SavedSearch being refreshed.
     * @return false, doing nothing, if that search already has a refresh in flight.
     */
    func beginRefresh( for id: UUID ) -> Bool
    {
        guard self.loadingSearchIDs.contains( id ) == false
        else
        {
            return false
        }
        self.loadingSearchIDs.insert( id )
        self.errorMessages[ id ] = nil
        // Upholds "progress only while loading" defensively — `endRefresh` has already dropped
        // the previous run's entry, so there is nothing here to clear along any reachable path.
        self.progressBySearchID[ id ] = nil
        return true
    }

    /**
     * Records how far a search's refresh has got. Progress is dropped for a search that isn't
     * refreshing, so an emission that lands after `endRefresh` can't resurrect a finished run's
     * indicator, and dropped when it would walk the count backwards within one sweep.
     *
     * @param progress Progress reported by the sweep.
     * @param id Identifier of the SavedSearch being refreshed.
     */
    func updateProgress( _ progress: SearchProgress, for id: UUID )
    {
        guard self.loadingSearchIDs.contains( id )
        else
        {
            return
        }

        // A changed total means a different sweep, which starts its own count from zero rather
        // than continuing this one's.
        if let current = self.progressBySearchID[ id ],
           progress.total == current.total,
           progress.completed < current.completed
        {
            return
        }

        self.progressBySearchID[ id ] = progress
    }

    /**
     * Marks a search's refresh as finished, recording the outcome's error message, if any, and
     * dropping its progress — the run's results stand in for it from here on.
     *
     * @param id Identifier of the SavedSearch that finished refreshing.
     * @param errorMessage Error to surface, or nil if the refresh succeeded.
     */
    func endRefresh( for id: UUID, errorMessage: String? )
    {
        self.loadingSearchIDs.remove( id )
        self.errorMessages[ id ] = errorMessage
        self.progressBySearchID[ id ] = nil
    }

    /**
     * Records an error for a search without touching its loading state, used for
     * failures that happen before a refresh actually starts (e.g. a missing API key).
     *
     * @param message Error message to surface.
     * @param id Identifier of the SavedSearch the error applies to.
     */
    func setError( _ message: String, for id: UUID )
    {
        self.errorMessages[ id ] = message
    }
}
