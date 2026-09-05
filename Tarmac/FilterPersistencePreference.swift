/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData

/**
 * Whether a search's results filters outlive the app. They're stored on the search itself so they
 * survive switching between searches; this decides whether a relaunch starts from them or from a
 * clean slate.
 */
enum FilterPersistencePreference
{
    nonisolated static let keepOnLaunchDefaultsKey = "keep_filters_on_launch"
    nonisolated static let defaultKeepOnLaunch = false

    /**
     * Whether filters should be carried across a relaunch.
     *
     * @param defaults UserDefaults suite to read the preference from.
     * @return True to keep each search's filters, false to start unfiltered.
     */
    static func keepsOnLaunch( defaults: UserDefaults = .standard ) -> Bool
    {
        guard defaults.object( forKey: Self.keepOnLaunchDefaultsKey ) != nil
        else
        {
            return Self.defaultKeepOnLaunch
        }

        return defaults.bool( forKey: Self.keepOnLaunchDefaultsKey )
    }

    /**
     * Clears every search's stored filters unless the user asked for them to be kept, so a launch
     * shows all the fares each search found rather than silently hiding some.
     *
     * @param context Model context holding the searches.
     * @param defaults UserDefaults suite to read the preference from.
     */
    static func clearFiltersIfNeeded( in context: ModelContext, defaults: UserDefaults = .standard )
    {
        guard Self.keepsOnLaunch( defaults: defaults ) == false,
              let searches = try? context.fetch( FetchDescriptor< SavedSearch >() )
        else
        {
            return
        }

        var isChanged = false
        for search in searches where search.resultFilters != nil
        {
            search.resultFilters = nil
            isChanged = true
        }

        if isChanged
        {
            try? context.save()
        }
    }
}
