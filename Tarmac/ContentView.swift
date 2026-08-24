/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftData
import SwiftUI

struct ContentView: View
{
    @State private var selectedSearch: SavedSearch?

    var body: some View
    {
        NavigationSplitView
        {
            SearchSidebar( selection: $selectedSearch )
                .navigationSplitViewColumnWidth( min: 220, ideal: 260, max: 340 )
        } detail: {
            ResultsPane( search: selectedSearch )
        }
        .navigationTitle( "Tarmac" )
    }
}

// MARK: - Sidebar

struct SearchSidebar: View
{
    @Query( sort: \SavedSearch.createdAt, order: .reverse ) private var searches: [ SavedSearch ]
    @Binding var selection: SavedSearch?

    var body: some View
    {
        List( searches, selection: $selection )
        { search in
            SearchRow( search: search )
        }
    }
}

struct SearchRow: View
{
    var search: SavedSearch

    var body: some View
    {
        Text( search.summary )
            .padding( .vertical, 2 )
    }
}

// MARK: - Detail

struct ResultsPane: View
{
    var search: SavedSearch?

    var body: some View
    {
        if let search
        {
            VStack( spacing: 0 )
            {
                Text( search.summary )
                    .font( .title3 )
                    .fontWeight( .semibold )
                    .frame( maxWidth: .infinity, alignment: .leading )
                    .padding()

                Divider()

                ContentUnavailableView(
                    "No results yet",
                    systemImage: "airplane.circle",
                    description: Text( "Refresh this search to check current prices." )
                )
                .frame( maxWidth: .infinity, maxHeight: .infinity )
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
