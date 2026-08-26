/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

enum SearchSelectionPreference
{
    static let selectedSearchIDDefaultsKey = "selected_search_id"

    /**
     * Persists (or clears) the currently selected search's ID.
     *
     * @param id ID of the search to remember, or nil to clear it.
     * @param defaults UserDefaults suite to persist the selection to.
     */
    static func persist( _ id: UUID?, defaults: UserDefaults = .standard )
    {
        if let id
        {
            defaults.set( id.uuidString, forKey: Self.selectedSearchIDDefaultsKey )
        }
        else
        {
            defaults.removeObject( forKey: Self.selectedSearchIDDefaultsKey )
        }
    }

    /**
     * Reads back the persisted selection, if any.
     *
     * @param defaults UserDefaults suite to read the selection from.
     * @return The persisted search ID, or nil if none is stored.
     */
    static func persistedSearchID( defaults: UserDefaults = .standard ) -> UUID?
    {
        guard let raw = defaults.string( forKey: Self.selectedSearchIDDefaultsKey )
        else
        {
            return nil
        }
        return UUID( uuidString: raw )
    }

    /**
     * Chooses which search should be selected, preferring the persisted selection
     * when it still exists and otherwise falling back to the newest search.
     *
     * @param searches Currently available searches, newest first.
     * @param defaults UserDefaults suite to read the persisted selection from.
     * @return The search to select, or nil if `searches` is empty.
     */
    static func restoreSelection( from searches: [ SavedSearch ], defaults: UserDefaults = .standard ) -> SavedSearch?
    {
        let persistedID = Self.persistedSearchID( defaults: defaults )
        if let persistedID,
           let match = searches.first( where: { $0.id == persistedID } )
        {
            return match
        }

        return searches.first
    }
}
