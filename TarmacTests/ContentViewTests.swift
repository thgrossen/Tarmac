/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "ContentView" )
struct ContentViewTests
{
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

    @Test( "Returns the selected search when exactly one is selected" )
    func returnsSelectedSearch()
    {
        let search = Self.makeSearch()

        let resolved = ContentView.currentSelection( selectedSearch: search, selectedCount: 1, searches: [ search ] )

        #expect( resolved?.id == search.id )
    }

    @Test( "Falls back to the restored/newest search when nothing is selected" )
    func fallsBackWhenNothingSelected()
    {
        let search = Self.makeSearch()

        let resolved = ContentView.currentSelection( selectedSearch: nil, selectedCount: 0, searches: [ search ] )

        #expect( resolved?.id == search.id )
    }

    @Test( "Returns nil while multiple searches are selected, even if a stale single selection lingers" )
    func returnsNilWhenMultipleSelected()
    {
        let search = Self.makeSearch()

        let resolved = ContentView.currentSelection( selectedSearch: search, selectedCount: 2, searches: [ search ] )

        #expect( resolved == nil )
    }

    @Test( "Does not fall back to the restored/newest search while multiple searches are selected" )
    func doesNotFallBackWhenMultipleSelected()
    {
        let search = Self.makeSearch()

        let resolved = ContentView.currentSelection( selectedSearch: nil, selectedCount: 2, searches: [ search ] )

        #expect( resolved == nil )
    }
}

@Suite( "SearchSidebar" )
struct SearchSidebarTests
{
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

    @Test( "Resolves to the matching search when exactly one ID is selected" )
    func resolvesSingleSelection()
    {
        let target = Self.makeSearch()
        let other  = Self.makeSearch( origin: "ZRH", destination: "JFK" )

        let resolved = SearchSidebar.singleSelection( for: [ target.id ], in: [ target, other ] )

        #expect( resolved?.id == target.id )
    }

    @Test( "Resolves to nil when nothing is selected" )
    func resolvesNilWhenEmpty()
    {
        let search = Self.makeSearch()

        let resolved = SearchSidebar.singleSelection( for: [], in: [ search ] )

        #expect( resolved == nil )
    }

    @Test( "Resolves to nil when more than one search is selected" )
    func resolvesNilWhenMultiple()
    {
        let first  = Self.makeSearch()
        let second = Self.makeSearch( origin: "ZRH", destination: "JFK" )

        let resolved = SearchSidebar.singleSelection( for: [ first.id, second.id ], in: [ first, second ] )

        #expect( resolved == nil )
    }

    @Test( "Resolves to nil when the selected ID no longer exists among the searches" )
    func resolvesNilWhenSelectionIsStale()
    {
        let search = Self.makeSearch()

        let resolved = SearchSidebar.singleSelection( for: [ UUID() ], in: [ search ] )

        #expect( resolved == nil )
    }

    @Test( "Deleting a search that isn't selected leaves the current selection untouched" )
    func deletingUnselectedSearchLeavesSelectionUntouched()
    {
        let selected   = Self.makeSearch()
        let unselected = Self.makeSearch( origin: "ZRH", destination: "JFK" )

        let result = SearchSidebar.selectedIDs(
            afterDeleting: [ unselected.id ],
            from: [ selected.id ],
            searches: [ selected ]
        )

        #expect( result == [ selected.id ] )
    }

    @Test( "Deleting one of several selected searches keeps the rest selected" )
    func deletingOneOfManySelectedKeepsTheRestSelected()
    {
        let first  = Self.makeSearch()
        let second = Self.makeSearch( origin: "ZRH", destination: "JFK" )
        let third  = Self.makeSearch( origin: "LHR", destination: "CDG" )

        let result = SearchSidebar.selectedIDs(
            afterDeleting: [ first.id ],
            from: [ first.id, second.id, third.id ],
            searches: [ second, third ]
        )

        #expect( result == [ second.id, third.id ] )
    }

    @Test( "Deleting the sole selected search falls back to the restored/newest remaining search" )
    func deletingSoleSelectedSearchFallsBackToRestoredSearch()
    {
        let deleted  = Self.makeSearch()
        let newest   = Self.makeSearch( origin: "ZRH", destination: "JFK" )

        let result = SearchSidebar.selectedIDs(
            afterDeleting: [ deleted.id ],
            from: [ deleted.id ],
            searches: [ newest ]
        )

        #expect( result == [ newest.id ] )
    }

    @Test( "Deleting the last remaining search leaves the selection empty" )
    func deletingLastRemainingSearchLeavesSelectionEmpty()
    {
        let deleted = Self.makeSearch()

        let result = SearchSidebar.selectedIDs(
            afterDeleting: [ deleted.id ],
            from: [ deleted.id ],
            searches: []
        )

        #expect( result.isEmpty )
    }

    @Test( "Deleting a bulk selection that has no restored fallback leaves the selection empty" )
    func deletingBulkSelectionWithNoRemainingSearchesLeavesSelectionEmpty()
    {
        let first  = Self.makeSearch()
        let second = Self.makeSearch( origin: "ZRH", destination: "JFK" )

        let result = SearchSidebar.selectedIDs(
            afterDeleting: [ first.id, second.id ],
            from: [ first.id, second.id ],
            searches: []
        )

        #expect( result.isEmpty )
    }

    @Test( "Deletion targets are the row alone when it isn't part of the current selection" )
    func deletionTargetsIsRowAloneWhenNotSelected()
    {
        let row      = Self.makeSearch()
        let selected = Self.makeSearch( origin: "ZRH", destination: "JFK" )

        let targets = SearchSidebar.deletionTargets( for: row.id, selectedIDs: [ selected.id ] )

        #expect( targets == [ row.id ] )
    }

    @Test( "Deletion targets are the row alone when nothing is currently selected" )
    func deletionTargetsIsRowAloneWhenNothingSelected()
    {
        let row = Self.makeSearch()

        let targets = SearchSidebar.deletionTargets( for: row.id, selectedIDs: [] )

        #expect( targets == [ row.id ] )
    }

    @Test( "Deletion targets are the whole selection when the row is part of it" )
    func deletionTargetsIsWholeSelectionWhenRowIsSelected()
    {
        let first  = Self.makeSearch()
        let second = Self.makeSearch( origin: "ZRH", destination: "JFK" )

        let targets = SearchSidebar.deletionTargets( for: first.id, selectedIDs: [ first.id, second.id ] )

        #expect( targets == [ first.id, second.id ] )
    }

    @Test( "Delete confirmation title is singular for one search" )
    func deleteConfirmationTitleIsSingularForOne()
    {
        #expect( SearchSidebar.deleteConfirmationTitle( for: 1 ) == "Delete this search?" )
    }

    @Test( "Delete confirmation title is plural and counted for more than one search" )
    func deleteConfirmationTitleIsPluralForMany()
    {
        #expect( SearchSidebar.deleteConfirmationTitle( for: 3 ) == "Delete 3 searches?" )
    }

    @Test( "Delete confirmation message is singular for one search" )
    func deleteConfirmationMessageIsSingularForOne()
    {
        #expect( SearchSidebar.deleteConfirmationMessage( for: 1 ) == "This permanently deletes this search and its run history. This can't be undone." )
    }

    @Test( "Delete confirmation message is plural and counted for more than one search" )
    func deleteConfirmationMessageIsPluralForMany()
    {
        #expect( SearchSidebar.deleteConfirmationMessage( for: 3 ) == "This permanently deletes these 3 searches and their run history. This can't be undone." )
    }
}

@Suite( "ResultsPane" )
struct ResultsPaneTests
{
    @Test( "Selection summary title is counted for more than one search" )
    func selectionSummaryTitleIsCountedForMany()
    {
        #expect( ResultsPane.selectionSummaryTitle( for: 3 ) == "3 searches selected" )
    }

    @Test( "Selection summary title is counted for exactly two searches" )
    func selectionSummaryTitleIsCountedForTwo()
    {
        #expect( ResultsPane.selectionSummaryTitle( for: 2 ) == "2 searches selected" )
    }
}
