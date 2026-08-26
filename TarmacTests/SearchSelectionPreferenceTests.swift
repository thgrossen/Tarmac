/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "SearchSelectionPreference" )
struct SearchSelectionPreferenceTests
{
    private static func freshDefaults() -> UserDefaults
    {
        UserDefaults( suiteName: "SearchSelectionPreferenceTests.\( UUID().uuidString )" )!
    }

    private static func makeSearch( origin: String = "GVA", destination: String = "LIS" ) -> SavedSearch
    {
        SavedSearch(
            kind: .oneWay,
            origin: origin,
            destination: destination,
            rangeStart: .now,
            rangeEnd: .now,
            cabinClass: "economy"
        )
    }

    @Test( "No persisted ID when nothing has been saved yet" )
    func persistedSearchIDDefaultsToNil()
    {
        let defaults = Self.freshDefaults()
        #expect( SearchSelectionPreference.persistedSearchID( defaults: defaults ) == nil )
    }

    @Test( "Persists and reads back a selected search ID" )
    func persistRoundTrips()
    {
        let defaults = Self.freshDefaults()
        let id = UUID()

        SearchSelectionPreference.persist( id, defaults: defaults )

        #expect( SearchSelectionPreference.persistedSearchID( defaults: defaults ) == id )
    }

    @Test( "Persisting nil clears a previously stored ID" )
    func persistNilClears()
    {
        let defaults = Self.freshDefaults()
        SearchSelectionPreference.persist( UUID(), defaults: defaults )

        SearchSelectionPreference.persist( nil, defaults: defaults )

        #expect( SearchSelectionPreference.persistedSearchID( defaults: defaults ) == nil )
    }

    @Test( "Restores the persisted search when it still exists" )
    func restoresPersistedSearch()
    {
        let defaults = Self.freshDefaults()
        let target = Self.makeSearch()
        let other  = Self.makeSearch( origin: "ZRH", destination: "JFK" )
        SearchSelectionPreference.persist( target.id, defaults: defaults )

        let restored = SearchSelectionPreference.restoreSelection( from: [ other, target ], defaults: defaults )

        #expect( restored?.id == target.id )
    }

    @Test( "Falls back to the newest search when no ID has been persisted" )
    func fallsBackWhenNoPersistedID()
    {
        let defaults = Self.freshDefaults()
        let newest = Self.makeSearch()
        let older  = Self.makeSearch( origin: "ZRH", destination: "JFK" )

        let restored = SearchSelectionPreference.restoreSelection( from: [ newest, older ], defaults: defaults )

        #expect( restored?.id == newest.id )
    }

    @Test( "Falls back to the newest search when the persisted search is gone" )
    func fallsBackWhenPersistedSearchIsStale()
    {
        let defaults = Self.freshDefaults()
        SearchSelectionPreference.persist( UUID(), defaults: defaults )
        let newest = Self.makeSearch()
        let older  = Self.makeSearch( origin: "ZRH", destination: "JFK" )

        let restored = SearchSelectionPreference.restoreSelection( from: [ newest, older ], defaults: defaults )

        #expect( restored?.id == newest.id )
    }

    @Test( "Returns nil when there are no searches at all" )
    func returnsNilWhenNoSearches()
    {
        let defaults = Self.freshDefaults()
        SearchSelectionPreference.persist( UUID(), defaults: defaults )

        let restored = SearchSelectionPreference.restoreSelection( from: [], defaults: defaults )

        #expect( restored == nil )
    }
}
