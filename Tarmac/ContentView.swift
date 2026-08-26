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
    @State private var refreshState = RefreshState()
    @State private var isPresentingNewSearchSheet = false

    // Falls back to the restored/newest search declaratively, so the very first render
    // already shows the right detail pane instead of a `nil`-selection empty state that
    // flips over once `SearchSidebar`'s `onAppear` runs.
    private var currentSelection: SavedSearch?
    {
        self.selectedSearch ?? SearchSelectionPreference.restoreSelection( from: self.searches )
    }

    var body: some View
    {
        NavigationSplitView
        {
            SearchSidebar(
                searches: self.searches,
                selection: $selectedSearch,
                refreshState: self.refreshState,
                isPresentingNewSearchSheet: $isPresentingNewSearchSheet
            )
            .navigationSplitViewColumnWidth( min: 220, ideal: 260, max: 340 )
        } detail: {
            ResultsPane(
                search: self.currentSelection,
                hasSearches: self.searches.isEmpty == false,
                refreshState: self.refreshState,
                onNewSearch: { self.isPresentingNewSearchSheet = true }
            )
        }
    }
}

// MARK: - Sidebar

struct SearchSidebar: View
{
    var searches: [ SavedSearch ]
    @Binding var selection: SavedSearch?
    var refreshState: RefreshState
    @Binding var isPresentingNewSearchSheet: Bool

    @Environment( \.modelContext ) private var modelContext
    @State private var selectedID: SavedSearch.ID?

    var body: some View
    {
        List( searches, selection: $selectedID )
        { search in
            SearchRow( search: search )
        }
        .onAppear
        {
            guard self.selectedID == nil
            else
            {
                return
            }

            if let restored = SearchSelectionPreference.restoreSelection( from: self.searches )
            {
                self.selectedID = restored.id
                self.selection = restored
            }
        }
        .onChange( of: self.selectedID )
        {
            SearchSelectionPreference.persist( self.selectedID )

            guard let selectedID = self.selectedID
            else
            {
                self.selection = nil
                return
            }

            // A freshly created search may not have reached `searches` yet (see the
            // `NewSearchSheet` sheet below, which sets both `selectedID` and `selection`
            // directly); don't clobber `selection` while that catches up.
            if let match = self.searches.first( where: { $0.id == selectedID } )
            {
                self.selection = match
            }
        }
        .toolbar
        {
            ToolbarItem
            {
                Button
                {
                    self.isPresentingNewSearchSheet = true
                } label: {
                    Label( "New Search", systemImage: "plus" )
                }
            }
        }
        .sheet( isPresented: $isPresentingNewSearchSheet )
        {
            NewSearchSheet
            { newSearch in
                self.selection = newSearch
                self.selectedID = newSearch.id
                Task { await self.runInitialSearch( for: newSearch ) }
            }
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
}

struct SearchRow: View
{
    var search: SavedSearch

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
    }
}

// MARK: - Detail

struct ResultsPane: View
{
    var search: SavedSearch?
    var hasSearches: Bool
    var refreshState: RefreshState
    var onNewSearch: () -> Void

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
                Button( "New Search", action: self.onNewSearch )
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
