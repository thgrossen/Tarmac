/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData

enum TestSupport
{
    static func makeInMemoryContext( for types: any PersistentModel.Type... ) throws -> ModelContext
    {
        let schema = Schema( types )
        let config = ModelConfiguration( schema: schema, isStoredInMemoryOnly: true )
        let container = try ModelContainer( for: schema, configurations: [ config ] )
        return ModelContext( container )
    }
}
