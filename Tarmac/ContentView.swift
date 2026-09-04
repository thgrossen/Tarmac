/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftData
import SwiftUI

struct ContentView: View
{
    @Query( sort: \SavedSearch.createdAt, order: .reverse ) private var searches: [ SavedSearch ]
    @State private var selectedSearch: SavedSearch?
    @State private var selectedCount = 0
    @State private var refreshState = RefreshState()
    @State private var isPresentingNewSearchSheet = false

    @Environment( NewSearchCommand.self ) private var newSearchCommand

    /**
     * Resolves the search to show in the detail pane, falling back to the restored/newest
     * search only when nothing has been explicitly selected — never while multiple searches
     * are selected, which intentionally clears `selectedSearch` without persisting.
     *
     * @param selectedSearch The sidebar's single-selection binding; nil when zero or multiple searches are selected.
     * @param selectedCount Number of searches currently selected in the sidebar.
     * @param searches Currently available searches to fall back against.
     * @return The search to display, or nil to show the pane's empty/summary state.
     */
    static func currentSelection( selectedSearch: SavedSearch?, selectedCount: Int, searches: [ SavedSearch ] ) -> SavedSearch?
    {
        guard selectedCount <= 1
        else
        {
            return nil
        }
        return selectedSearch ?? SearchSelectionPreference.restoreSelection( from: searches )
    }

    // Falls back to the restored/newest search declaratively, so the very first render
    // already shows the right detail pane instead of a `nil`-selection empty state that
    // flips over once `SearchSidebar`'s `onAppear` runs.
    private var currentSelection: SavedSearch?
    {
        Self.currentSelection( selectedSearch: self.selectedSearch, selectedCount: self.selectedCount, searches: self.searches )
    }

    var body: some View
    {
        NavigationSplitView
        {
            SearchSidebar(
                searches: self.searches,
                selection: $selectedSearch,
                selectedCount: $selectedCount,
                refreshState: self.refreshState,
                isPresentingNewSearchSheet: $isPresentingNewSearchSheet
            )
            .navigationSplitViewColumnWidth( min: 220, ideal: 260, max: 340 )
        } detail: {
            ResultsPane(
                search: self.currentSelection,
                selectedCount: self.selectedCount,
                hasSearches: self.searches.isEmpty == false,
                refreshState: self.refreshState,
                onNewSearch: { self.isPresentingNewSearchSheet = true }
            )
        }
        .onChange( of: self.newSearchCommand.pendingRequestID )
        {
            self.consumeNewSearchCommand()
        }
        .onAppear
        {
            // Closing the main window doesn't quit the app (e.g. Settings or the Raw Data
            // window can keep it running), so a `NewSearchCommand` request made in that state
            // is left pending with no `ContentView` to observe its `onChange` — consume it here
            // too, once a `ContentView` exists again.
            self.consumeNewSearchCommand()
        }
    }

    private func consumeNewSearchCommand()
    {
        if self.newSearchCommand.consumePendingRequest()
        {
            self.isPresentingNewSearchSheet = true
        }
    }
}

// MARK: - Sidebar

struct SearchSidebar: View
{
    var searches: [ SavedSearch ]
    @Binding var selection: SavedSearch?
    @Binding var selectedCount: Int
    var refreshState: RefreshState
    @Binding var isPresentingNewSearchSheet: Bool

    @Environment( \.modelContext ) private var modelContext
    @State private var selectedIDs: Set< SavedSearch.ID > = []
    @State private var isPresentingClearAllConfirmation = false
    @State private var isPresentingDeleteConfirmation = false
    @State private var pendingDeletionIDs: Set< SavedSearch.ID > = []

    /**
     * Resolves a `Set`-based selection down to the single search it represents.
     *
     * @param selectedIDs Currently selected search IDs.
     * @param searches Currently available searches to resolve the IDs against.
     * @return The single selected search, or nil if the selection isn't exactly one search.
     */
    static func singleSelection( for selectedIDs: Set< SavedSearch.ID >, in searches: [ SavedSearch ] ) -> SavedSearch?
    {
        guard let onlyID = selectedIDs.count == 1 ? selectedIDs.first : nil
        else
        {
            return nil
        }
        return searches.first( where: { $0.id == onlyID } )
    }

    /**
     * Computes the sidebar's selection after a set of searches has been deleted. Deleted
     * searches that weren't part of the selection leave it untouched; deleting part of a
     * larger selection keeps the rest selected; deleting the entire selection falls back to
     * the restored/newest of the remaining searches.
     *
     * @param deletedIDs IDs of the searches that were just deleted.
     * @param selectedIDs Selection immediately before the delete.
     * @param searches Currently available searches, with the deleted ones already excluded.
     * @return The selection to apply after the delete.
     */
    static func selectedIDs( afterDeleting deletedIDs: Set< SavedSearch.ID >, from selectedIDs: Set< SavedSearch.ID >, searches: [ SavedSearch ] ) -> Set< SavedSearch.ID >
    {
        let remaining = selectedIDs.subtracting( deletedIDs )
        guard remaining.isEmpty
        else
        {
            return remaining
        }

        let restored = SearchSelectionPreference.restoreSelection( from: searches )
        return restored.map { [ $0.id ] } ?? []
    }

    /**
     * Resolves which searches a delete action should target: the row it was invoked on, or —
     * when that row is part of the current multi-selection — every selected search, matching
     * Finder/Mail conventions for right-clicking within an existing selection.
     *
     * @param rowID ID of the row the delete action was invoked on.
     * @param selectedIDs Currently selected search IDs.
     * @return The IDs to delete.
     */
    static func deletionTargets( for rowID: SavedSearch.ID, selectedIDs: Set< SavedSearch.ID > ) -> Set< SavedSearch.ID >
    {
        selectedIDs.contains( rowID ) ? selectedIDs : [ rowID ]
    }

    /**
     * Title for the delete confirmation alert, pluralized by how many searches will be deleted.
     *
     * @param count Number of searches pending deletion.
     * @return "Delete this search?" for one, "Delete N searches?" for more than one.
     */
    static func deleteConfirmationTitle( for count: Int ) -> String
    {
        count == 1 ? "Delete this search?" : "Delete \( count ) searches?"
    }

    /**
     * Body copy for the delete confirmation alert, pluralized by how many searches will be deleted.
     *
     * @param count Number of searches pending deletion.
     * @return The alert's message text.
     */
    static func deleteConfirmationMessage( for count: Int ) -> String
    {
        if count == 1
        {
            return "This permanently deletes this search and its run history. This can't be undone."
        }
        return "This permanently deletes these \( count ) searches and their run history. This can't be undone."
    }

    var body: some View
    {
        List( searches, selection: $selectedIDs )
        { search in
            SearchRow(
                search: search,
                isSelected: self.selectedIDs.contains( search.id ),
                onDelete: { self.requestDelete( for: search.id ) }
            )
        }
        .onAppear
        {
            guard self.selectedIDs.isEmpty
            else
            {
                return
            }

            if let restored = SearchSelectionPreference.restoreSelection( from: self.searches )
            {
                self.selectedIDs = [ restored.id ]
                self.selection = restored
                self.selectedCount = 1
            }
        }
        .onChange( of: self.selectedIDs )
        {
            self.selectedCount = self.selectedIDs.count

            guard self.selectedIDs.count <= 1
            else
            {
                // Multiple searches selected: leave any previously persisted single
                // selection untouched so relaunching still restores it.
                self.selection = nil
                return
            }

            SearchSelectionPreference.persist( self.selectedIDs.first )

            guard self.selectedIDs.isEmpty == false
            else
            {
                self.selection = nil
                return
            }

            // A freshly created search may not have reached `searches` yet (see the
            // `NewSearchSheet` sheet below, which sets both `selectedIDs` and `selection`
            // directly); don't clobber `selection` while that catches up.
            if let match = Self.singleSelection( for: self.selectedIDs, in: self.searches )
            {
                self.selection = match
            }
        }
        .onDeleteCommand
        {
            guard self.selectedIDs.isEmpty == false
            else
            {
                return
            }
            self.pendingDeletionIDs = self.selectedIDs
            self.isPresentingDeleteConfirmation = true
        }
        .toolbar
        {
            ToolbarItem
            {
                Button( "New Search", systemImage: "plus" )
                {
                    self.isPresentingNewSearchSheet = true
                }
            }

            ToolbarItem
            {
                Menu
                {
                    Button( "Clear All Searches", role: .destructive )
                    {
                        self.isPresentingClearAllConfirmation = true
                    }
                    .disabled( self.searches.isEmpty )
                } label: {
                    Label( "More", systemImage: "ellipsis.circle" )
                }
            }
        }
        .sheet( isPresented: $isPresentingNewSearchSheet )
        {
            NewSearchSheet
            { newSearch in
                self.selection = newSearch
                self.selectedIDs = [ newSearch.id ]
                self.selectedCount = 1
                Task { await self.runInitialSearch( for: newSearch ) }
            }
        }
        .alert( "Clear All Searches?", isPresented: $isPresentingClearAllConfirmation )
        {
            Button( "Clear All Searches", role: .destructive )
            {
                self.clearAllSearches()
            }
            Button( "Cancel", role: .cancel ) {}
        } message: {
            Text( "This permanently deletes every saved search and its run history. This can't be undone." )
        }
        .alert( Self.deleteConfirmationTitle( for: self.pendingDeletionIDs.count ), isPresented: $isPresentingDeleteConfirmation )
        {
            Button( "Delete", role: .destructive )
            {
                self.deleteSearches( self.pendingDeletionIDs )
            }
            Button( "Cancel", role: .cancel ) {}
        } message: {
            Text( Self.deleteConfirmationMessage( for: self.pendingDeletionIDs.count ) )
        }
    }

    private func runInitialSearch( for search: SavedSearch ) async
    {
        let apiKey = UserDefaults.standard.string( forKey: SearchViewModel.apiKeyDefaultsKey ) ?? ""
        guard apiKey.isEmpty == false
        else
        {
            self.refreshState.setError( "Add your Ignav API key.", for: search.id )
            return
        }

        guard self.refreshState.beginRefresh( for: search.id )
        else
        {
            return
        }

        let run = await SearchRunner.run( for: search, apiKey: apiKey )
        self.modelContext.insert( run )
        self.refreshState.endRefresh( for: search.id, errorMessage: run.errorMessage )
    }

    /**
     * Resolves the delete target for a row-level delete action (the row alone, or the whole
     * multi-selection when the row is part of it) and presents the confirmation alert.
     *
     * @param id ID of the row the delete action was invoked on.
     */
    private func requestDelete( for id: SavedSearch.ID )
    {
        self.pendingDeletionIDs = Self.deletionTargets( for: id, selectedIDs: self.selectedIDs )
        self.isPresentingDeleteConfirmation = true
    }

    /**
     * Deletes every search in `ids`, updating the sidebar's selection — collapsing to a
     * restored search only once the selection would otherwise become empty.
     *
     * @param ids IDs of the searches to delete.
     */
    private func deleteSearches( _ ids: Set< SavedSearch.ID > )
    {
        guard ids.isEmpty == false
        else
        {
            return
        }

        for search in self.searches where ids.contains( search.id )
        {
            self.modelContext.delete( search )
        }

        // `onChange( of: self.selectedIDs )` above propagates this into `selection`/`selectedCount`.
        let remainingSearches = self.searches.filter { ids.contains( $0.id ) == false }
        self.selectedIDs = Self.selectedIDs( afterDeleting: ids, from: self.selectedIDs, searches: remainingSearches )
    }

    /**
     * Deletes every saved search, clearing the sidebar's selection.
     */
    private func clearAllSearches()
    {
        for search in self.searches
        {
            self.modelContext.delete( search )
        }
        self.selectedIDs = []
        self.selection = nil
        self.selectedCount = 0
    }
}

struct SearchRow: View
{
    var search: SavedSearch
    var isSelected: Bool
    var onDelete: () -> Void

    @State private var isHovering = false
    @Environment( \.controlActiveState ) private var controlActiveState

    private var isHoverTintVisible: Bool
    {
        self.isHovering && self.isSelected == false && self.controlActiveState != .inactive
    }

    var body: some View
    {
        VStack( alignment: .leading, spacing: 3 )
        {
            Text( "\( self.search.origin ) → \( self.search.destination )" )
                .font( .headline )

            HStack( spacing: 4 )
            {
                Text( self.search.tripDetail )

                if let cheapestFare = self.search.runsNewestFirst.first?.cheapestFare,
                   let formattedAmount = cheapestFare.formattedAmount
                {
                    Text( "· \( formattedAmount )" )
                }
            }
            .font( .caption )
            .foregroundStyle( .secondary )
        }
        .padding( .vertical, 4 )
        .frame( maxWidth: .infinity, alignment: .leading )
        .contentShape( Rectangle() )
        .onHover { self.isHovering = $0 }
        // `.listRowBackground` spans the row's full, un-inset bounds — unlike the system
        // selection highlight, it isn't clipped to a rounded shape on its own, so the rounding
        // and margin are drawn explicitly here instead.
        .listRowBackground(
            RoundedRectangle( cornerRadius: 8, style: .continuous )
                .fill( Color.accentColor.opacity( self.isHoverTintVisible ? 0.12 : 0 ) )
                .padding( .horizontal, 10 )
        )
        .contextMenu
        {
            Button( "Delete", role: .destructive, action: self.onDelete )
        }
    }
}

// MARK: - Detail

struct ResultsPane: View
{
    var search: SavedSearch?
    var selectedCount: Int
    var hasSearches: Bool
    var refreshState: RefreshState
    var onNewSearch: () -> Void

    /**
     * Title for the results pane's multi-selection summary.
     *
     * @param count Number of searches currently selected in the sidebar.
     * @return "N searches selected".
     */
    static func selectionSummaryTitle( for count: Int ) -> String
    {
        "\( count ) searches selected"
    }

    var body: some View
    {
        if self.selectedCount > 1
        {
            Text( Self.selectionSummaryTitle( for: self.selectedCount ) )
                .font( .callout )
                .foregroundStyle( .secondary )
                .frame( minWidth: 620, minHeight: 420, alignment: .center )
        }
        else if let search
        {
            SearchDetailView( search: search, refreshState: self.refreshState )
                .id( search.id )
        }
        else if self.hasSearches == false
        {
            ContentUnavailableView
            {
                Label( "No searches yet", systemImage: "airplane" )
            } description: {
                Text( "Create a search to start tracking prices." )
            } actions: {
                Button( "New Search" )
                {
                    self.onNewSearch()
                }
            }
            .frame( minWidth: 620, minHeight: 420 )
        }
        else
        {
            ContentUnavailableView(
                "No search selected",
                systemImage: "airplane",
                description: Text( "Select a search from the sidebar." )
            )
            .frame( minWidth: 620, minHeight: 420 )
        }
    }
}

struct SearchDetailView: View
{
    var search: SavedSearch
    var refreshState: RefreshState

    @Environment( \.modelContext ) private var modelContext
    @State private var selectedRun: SearchRun?
    @State private var filters = OneWayFilters()
    @State private var isPresentingFilters = false

    // Cached rather than recomputed per render: it walks every fare of every run, and runs are
    // append-only, so it can only change when a refresh adds one.
    @State private var filterBounds = OneWayFilterBounds()

    private var isLoading: Bool { self.refreshState.isLoading( self.search.id ) }
    private var errorMessage: String? { self.refreshState.errorMessage( for: self.search.id ) }

    // Filters are one-way-only for now, and only mean anything once a run has returned fares to
    // derive their extents from.
    private var isFilterable: Bool { self.search.kind == .oneWay }

    /**
     * The filters to narrow the chart and the table by: the active set for a filterable search, and
     * nil otherwise, which leaves every result in place.
     *
     * @param filters The search's stored filters.
     * @param isFilterable Whether this search supports filtering at all.
     * @return The filters to apply, or nil to apply none.
     */
    static func appliedFilters( _ filters: OneWayFilters, isFilterable: Bool ) -> OneWayFilters?
    {
        guard isFilterable,
              filters.isActive
        else
        {
            return nil
        }
        return filters
    }

    var body: some View
    {
        VStack( spacing: 0 )
        {
            HStack
            {
                Spacer()

                if self.isFilterable
                {
                    Button
                    {
                        self.isPresentingFilters = true
                    } label: {
                        Label( self.filters.isActive ? "Filters (\( self.filters.activeCount ))" : "Filters", systemImage: "line.3.horizontal.decrease.circle" )
                    }
                    .disabled( self.filterBounds.isEmpty )
                    .popover( isPresented: self.$isPresentingFilters, arrowEdge: .bottom )
                    {
                        OneWayFiltersPopover( bounds: self.filterBounds, filters: self.$filters )
                    }
                }

                Button
                {
                    Task { await self.refresh() }
                } label: {
                    HStack
                    {
                        if self.isLoading { ProgressView().controlSize( .small ) }
                        Text( self.isLoading ? "Refreshing…" : "Refresh" )
                    }
                }
                .keyboardShortcut( .return, modifiers: .command )
                .disabled( self.isLoading )
            }
            .padding()

            if self.isFilterable
            {
                FilterChipBar(
                    filters: self.filters,
                    matchingCount: self.filters.apply( to: self.selectedRun?.itineraries ?? [] ).count,
                    totalCount: self.selectedRun?.itineraries.count ?? 0,
                    onChange: { self.filters = $0 },
                    onEdit: { self.isPresentingFilters = true }
                )
            }

            if let errorMessage = self.errorMessage
            {
                Text( errorMessage )
                    .font( .callout.monospaced() )
                    .foregroundStyle( .red )
                    .textSelection( .enabled )
                    .padding( 10 )
                    .frame( maxWidth: .infinity, alignment: .leading )
                    .background( .red.opacity( 0.08 ) )
            }

            Divider()

            let runs = self.search.runsNewestFirst
            if runs.isEmpty
            {
                VStack( spacing: 12 )
                {
                    ProgressView()
                    Text( "Searching…" )
                        .font( .callout )
                        .foregroundStyle( .secondary )
                }
                .frame( maxWidth: .infinity, maxHeight: .infinity )
            }
            else
            {
                RunHistoryView(
                    runs: runs,
                    selection: self.$selectedRun,
                    filters: Self.appliedFilters( self.filters, isFilterable: self.isFilterable )
                )
                .onAppear
                {
                    if self.selectedRun == nil
                    {
                        self.selectedRun = runs.first
                    }

                    // The search's very first run arriving takes this view from absent to present,
                    // so `onChange( of: runs.count )` below never sees it — pick the bounds up here.
                    self.refreshFilterBounds()
                }
                .onChange( of: runs.count )
                {
                    self.selectedRun = runs.first
                    self.refreshFilterBounds()
                }
            }
        }
        .frame( minWidth: 620, minHeight: 420 )
        .navigationTitle( self.search.summary )
        .onAppear
        {
            // This view is `.id( search.id )`-keyed by `ResultsPane`, so switching searches builds a
            // brand new one — seeding from the model here is what restores each search's own filters.
            self.filters = self.search.oneWayFilters ?? OneWayFilters()
            self.refreshFilterBounds()
        }
        .onChange( of: self.filters )
        {
            self.search.oneWayFilters = self.filters.isActive ? self.filters : nil
        }
    }

    private func refreshFilterBounds()
    {
        self.filterBounds = self.isFilterable ? OneWayFilterBounds.bounds( for: self.search.runs ) : OneWayFilterBounds()
    }

    private func refresh() async
    {
        let apiKey = UserDefaults.standard.string( forKey: SearchViewModel.apiKeyDefaultsKey ) ?? ""
        guard apiKey.isEmpty == false
        else
        {
            self.refreshState.setError( "Add your Ignav API key.", for: self.search.id )
            return
        }

        guard self.refreshState.beginRefresh( for: self.search.id )
        else
        {
            return
        }

        let run = await SearchRunner.run( for: self.search, apiKey: apiKey )
        self.modelContext.insert( run )
        self.refreshState.endRefresh( for: self.search.id, errorMessage: run.errorMessage )
    }
}
