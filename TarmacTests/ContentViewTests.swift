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

@Suite( "SearchDetailView" )
struct SearchDetailViewTests
{
    @Test( "Nothing is filterable until a fare carries a value some filter could narrow" )
    func isFilterableFollowsTheBounds()
    {
        #expect( SearchDetailView.isFilterable( bounds: ResultFilterBounds() ) == false )

        // Fares carrying an inbound leg, as a round trip's do.
        let run = SearchRun( requestCount: 1 )
        run.itineraries = [
            PriceSnapshot( amount: 300, currency: "CHF", outboundSummary: "LX 1234", inboundSummary: "LX 5678", departureTime: "06:00", inboundDepartureTime: "21:15" ),
            PriceSnapshot( amount: 900, currency: "CHF", outboundSummary: "TP 4321", inboundSummary: "TP 8765", departureTime: "18:45", inboundDepartureTime: "07:30" ),
        ]

        #expect( SearchDetailView.isFilterable( bounds: ResultFilterBounds.bounds( for: [ run ] ) ) )
    }

    @Test( "The Filters button counts only the filters that are actually narrowing the results" )
    func filtersButtonTitleCountsAppliedFilters()
    {
        var active = ResultFilters()
        active.maxPrice = 400
        active.maxStops = 0

        #expect( SearchDetailView.filtersButtonTitle( isFilterable: true, filters: active ) == "Filters (2)" )
        #expect( SearchDetailView.filtersButtonTitle( isFilterable: true, filters: ResultFilters() ) == "Filters" )

        // With nothing to filter on the popover cannot be opened and the chip bar is absent, so a
        // count would name filters the user has no way to reach.
        #expect( SearchDetailView.filtersButtonTitle( isFilterable: false, filters: active ) == "Filters" )
    }

    @Test( "The button reads Update while nothing is running" )
    func updateButtonTitleWhenIdle()
    {
        #expect( SearchDetailView.updateButtonTitle( isLoading: false, progress: nil ) == "Update" )

        // Progress can't outlive its refresh, but the title shouldn't depend on that holding.
        #expect( SearchDetailView.updateButtonTitle( isLoading: false, progress: SearchProgress( completed: 7, total: 24 ) ) == "Update" )
    }

    @Test( "A refresh too short to count just says it's updating" )
    func updateButtonTitleWhileLoadingWithoutCountableProgress()
    {
        #expect( SearchDetailView.updateButtonTitle( isLoading: true, progress: nil ) == "Updating…" )
        #expect( SearchDetailView.updateButtonTitle( isLoading: true, progress: SearchProgress( completed: 0, total: 0 ) ) == "Updating…" )
        #expect( SearchDetailView.updateButtonTitle( isLoading: true, progress: SearchProgress( completed: 1, total: 2 ) ) == "Updating…" )
    }

    @Test( "A countable refresh carries the percentage, without the counts" )
    func updateButtonTitleWhileLoadingWithCountableProgress()
    {
        #expect( SearchDetailView.updateButtonTitle( isLoading: true, progress: SearchProgress( completed: 0, total: 3 ) ) == "Updating… 0%" )
        #expect( SearchDetailView.updateButtonTitle( isLoading: true, progress: SearchProgress( completed: 7, total: 24 ) ) == "Updating… 29%" )
        #expect( SearchDetailView.updateButtonTitle( isLoading: true, progress: SearchProgress( completed: 24, total: 24 ) ) == "Updating… 100%" )

        // The button holds at 99% too, rather than rounding up while requests are still in flight.
        #expect( SearchDetailView.updateButtonTitle( isLoading: true, progress: SearchProgress( completed: 999, total: 1_000 ) ) == "Updating… 99%" )
    }

    @Test( "The button and the placeholder start counting at the same point" )
    func updateButtonTitleFlipsWithTheIndicator()
    {
        for total in 0 ... 5
        {
            let progress    = SearchProgress( completed: 0, total: total )
            let isCountable = total >= SearchProgress.determinateMinimumRequests

            #expect( SearchDetailView.updateButtonTitle( isLoading: true, progress: progress ) == ( isCountable ? "Updating… 0%" : "Updating…" ) )
            #expect( ( SearchProgressIndicator.determinateProgress( for: progress ) != nil ) == isCountable )
        }
    }

    @Test( "The reserved width covers every title the button can show while loading" )
    func widestLoadingTitleIsTheWidest()
    {
        #expect( SearchDetailView.widestLoadingTitle == "Updating… 100%" )

        // The titles share a prefix and are digit-monospaced, so glyph count stands in for width.
        let totals = [ 0, 1, 2, 3, 5, 24, 100 ]
        for total in totals
        {
            for completed in [ 0, total / 2, total ]
            {
                let title = SearchDetailView.updateButtonTitle(
                    isLoading: true,
                    progress: SearchProgress( completed: completed, total: total )
                )

                #expect( title.count <= SearchDetailView.widestLoadingTitle.count )
            }
        }

        #expect( SearchDetailView.updateButtonTitle( isLoading: true, progress: nil ).count <= SearchDetailView.widestLoadingTitle.count )
    }
}
