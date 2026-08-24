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
        let schema = Schema( [ PriceSnapshot.self ] )
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

    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
        }
        .modelContainer( container )
        .defaultSize( width: 1000, height: 620 )
        .windowResizability( .contentMinSize )
    }
}
