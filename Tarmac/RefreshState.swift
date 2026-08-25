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

    func isLoading( _ id: UUID ) -> Bool
    {
        self.loadingSearchIDs.contains( id )
    }

    func errorMessage( for id: UUID ) -> String?
    {
        self.errorMessages[ id ]
    }

    /**
     * Marks a search as refreshing and clears any error left over from a previous run.
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
        return true
    }

    /**
     * Marks a search's refresh as finished, recording the outcome's error message, if any.
     *
     * @param id Identifier of the SavedSearch that finished refreshing.
     * @param errorMessage Error to surface, or nil if the refresh succeeded.
     */
    func endRefresh( for id: UUID, errorMessage: String? )
    {
        self.loadingSearchIDs.remove( id )
        self.errorMessages[ id ] = errorMessage
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
