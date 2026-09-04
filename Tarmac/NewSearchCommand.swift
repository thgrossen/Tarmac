/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import Observation

/**
 * One-shot bridge from the app's "New Search…" menu command (declared at the `App` level, in
 * `TarmacApp`) down into `ContentView`'s own new-search-sheet state, since the two live in
 * separate parts of the view hierarchy.
 */
@Observable
final class NewSearchCommand
{
    private( set ) var pendingRequestID: UUID?

    func request()
    {
        self.pendingRequestID = UUID()
    }

    /**
     * Consumes a pending request, if any, so it isn't acted on more than once.
     *
     * @return true if there was a pending request to consume.
     */
    func consumePendingRequest() -> Bool
    {
        guard self.pendingRequestID != nil
        else
        {
            return false
        }
        self.pendingRequestID = nil
        return true
    }
}
