/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftData
import SwiftUI

@main
struct TarmacApp: App
{
    let container: ModelContainer = {
        let schema = Schema( [ SavedSearch.self, SearchRun.self, PriceSnapshot.self ] )
        let config = ModelConfiguration( schema: schema, isStoredInMemoryOnly: false )
        do
        {
            return try ModelContainer( for: schema, configurations: [ config ] )
        }
        catch
        {
            fatalError( "Could not create ModelContainer: \( error )" )
        }
    }()
    let dateSession = SearchDateSession()
    let apiLog = APILog()
    let inspectorState = APIInspectorState()
    let newSearchCommand = NewSearchCommand()

    init()
    {
        let apiLog = self.apiLog
        APIRecording.install { transaction in apiLog.recordFromAnyIsolation( transaction ) }

        PriceSnapshotBackfill.backfillIfNeeded( in: self.container.mainContext )
        FilterPersistencePreference.clearFiltersIfNeeded( in: self.container.mainContext )
    }

    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
        }
        .modelContainer( container )
        .environment( self.dateSession )
        .environment( self.apiLog )
        .environment( self.inspectorState )
        .environment( self.newSearchCommand )
        .defaultSize( width: 1000, height: 620 )
        .windowResizability( .contentMinSize )
        .commands
        {
            // This app has only one main window, so "New Window" doesn't apply — Cmd-N and the
            // File menu's "new item" slot are repurposed for starting a new search instead.
            CommandGroup( replacing: .newItem )
            {
                Button( "New Search…" )
                {
                    self.newSearchCommand.request()
                }
                .keyboardShortcut( "n", modifiers: .command )
            }
        }

        Settings
        {
            PreferencesView()
        }

        // Keeps the "rawJSON" identifier the window has always had, so macOS's saved frame for it
        // survives the window becoming the API inspector.
        Window( "API Requests", id: "rawJSON" )
        {
            APIInspectorView()
                .environment( self.apiLog )
                .environment( self.inspectorState )
        }
        .windowResizability( .contentMinSize )
    }
}
