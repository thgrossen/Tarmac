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
    @State private var newSearchKind: SearchKind = .oneWay

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
                isPresentingNewSearchSheet: $isPresentingNewSearchSheet,
                newSearchKind: $newSearchKind
            )
            .navigationSplitViewColumnWidth( min: 220, ideal: 260, max: 340 )
        } detail: {
            ResultsPane(
                search: self.currentSelection,
                hasSearches: self.searches.isEmpty == false,
                refreshState: self.refreshState,
                onNewSearch: { kind in
                    self.newSearchKind = kind
                    self.isPresentingNewSearchSheet = true
                }
            )
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
    @Binding var newSearchKind: SearchKind

    @Environment( \.modelContext ) private var modelContext
    @State private var selectedIDs: Set< SavedSearch.ID > = []
    @State private var isPresentingClearAllConfirmation = false

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
     * Computes the sidebar's selection after one search has been deleted. A deleted search
     * that wasn't part of the selection leaves it untouched; deleting a selected search out
     * of a larger selection keeps the rest selected; deleting the last selected search falls
     * back to the restored/newest of the remaining searches.
     *
     * @param deletedID ID of the search that was just deleted.
     * @param selectedIDs Selection immediately before the delete.
     * @param searches Currently available searches, with the deleted one already excluded.
     * @return The selection to apply after the delete.
     */
    static func selectedIDs( afterDeleting deletedID: SavedSearch.ID, from selectedIDs: Set< SavedSearch.ID >, searches: [ SavedSearch ] ) -> Set< SavedSearch.ID >
    {
        guard selectedIDs.contains( deletedID )
        else
        {
            return selectedIDs
        }

        let remaining = selectedIDs.subtracting( [ deletedID ] )
        guard remaining.isEmpty
        else
        {
            return remaining
        }

        let restored = SearchSelectionPreference.restoreSelection( from: searches )
        return restored.map { [ $0.id ] } ?? []
    }

    var body: some View
    {
        List( searches, selection: $selectedIDs )
        { search in
            SearchRow( search: search, onDelete: { self.deleteSearch( search ) } )
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
            guard let search = Self.singleSelection( for: self.selectedIDs, in: self.searches )
            else
            {
                return
            }
            self.deleteSearch( search )
        }
        .toolbar
        {
            ToolbarItem
            {
                Menu
                {
                    Button( "One-way" )
                    {
                        self.newSearchKind = .oneWay
                        self.isPresentingNewSearchSheet = true
                    }
                    Button( "Round Trip" )
                    {
                        self.newSearchKind = .roundTrip
                        self.isPresentingNewSearchSheet = true
                    }
                } label: {
                    Label( "New Search", systemImage: "plus" )
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
            NewSearchSheet( kind: self.newSearchKind )
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
     * Deletes a single search, updating the sidebar's selection if that search was selected —
     * collapsing to a restored search only once the selection would otherwise become empty.
     *
     * @param search Search to delete.
     */
    private func deleteSearch( _ search: SavedSearch )
    {
        self.modelContext.delete( search )

        // `onChange( of: self.selectedIDs )` above propagates this into `selection`/`selectedCount`.
        let remainingSearches = self.searches.filter { $0.id != search.id }
        self.selectedIDs = Self.selectedIDs( afterDeleting: search.id, from: self.selectedIDs, searches: remainingSearches )
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
    var onDelete: () -> Void

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
    var hasSearches: Bool
    var refreshState: RefreshState
    var onNewSearch: ( SearchKind ) -> Void

    var body: some View
    {
        if let search
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
                Menu
                {
                    Button( "One-way" )
                    {
                        self.onNewSearch( .oneWay )
                    }
                    Button( "Round Trip" )
                    {
                        self.onNewSearch( .roundTrip )
                    }
                } label: {
                    Text( "New Search" )
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
    @State private var isFollowingLatestRun = true

    private var isLoading: Bool { self.refreshState.isLoading( self.search.id ) }
    private var errorMessage: String? { self.refreshState.errorMessage( for: self.search.id ) }

    var body: some View
    {
        VStack( spacing: 0 )
        {
            HStack
            {
                VStack( alignment: .leading, spacing: 2 )
                {
                    Text( search.summary )
                        .font( .title3 )
                        .fontWeight( .semibold )

                    if search.kind == .oneWay
                    {
                        Text( "Refresh checks the earliest date in the range." )
                            .font( .caption )
                            .foregroundStyle( .secondary )
                    }
                }

                Spacer()

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
                ContentUnavailableView(
                    "No results yet",
                    systemImage: "airplane.circle",
                    description: Text( "Refresh this search to check current prices." )
                )
                .frame( maxWidth: .infinity, maxHeight: .infinity )
            }
            else
            {
                RunHistoryView(
                    runs: runs,
                    selection: self.$selectedRun,
                    isFollowingLatest: self.$isFollowingLatestRun
                )
                .onAppear
                {
                    if self.selectedRun == nil
                    {
                        self.selectedRun = runs.first
                    }
                }
                .onChange( of: runs.count )
                {
                    let selectionStillValid = runs.contains { $0.id == self.selectedRun?.id }
                    if self.isFollowingLatestRun || selectionStillValid == false
                    {
                        self.selectedRun = runs.first
                    }
                }
            }
        }
        .frame( minWidth: 620, minHeight: 420 )
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
