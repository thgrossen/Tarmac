/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import Observation

/**
 * Shared state for the single API inspector window: which run it is scoped to, and how its list is
 * currently narrowed. The run is kept in sync with whatever run the results table is showing, so
 * the window follows along without needing to be reopened.
 */
@Observable
final class APIInspectorState
{
    enum Scope: String, CaseIterable, Identifiable
    {
        case thisRun
        case all

        var id: String { self.rawValue }

        var label: String
        {
            switch self
            {
                case .thisRun: return "This Run"
                case .all:     return "All"
            }
        }
    }

    var run: SearchRun?
    var scope: Scope = .thisRun
    var query = ""
    var failuresOnly = false
    var selection: APITransaction.ID?

    /**
     * Run to restrict the listing to, which is nothing at all when the scope is widened to every
     * call or when no run has been picked yet.
     */
    var scopedRunID: UUID?
    {
        self.scope == .thisRun ? self.run?.id : nil
    }
}
