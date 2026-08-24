/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData

@Model
final class SearchRun
{
    var id: UUID
    var runAt: Date
    var rawJSON: String?
    var errorMessage: String?
    var requestCount: Int

    var savedSearch: SavedSearch?

    @Relationship( deleteRule: .cascade, inverse: \PriceSnapshot.run )     var itineraries: [ PriceSnapshot ] = []

    init(
        id: UUID = UUID(),
        runAt: Date = .now,
        rawJSON: String? = nil,
        errorMessage: String? = nil,
        requestCount: Int,
        savedSearch: SavedSearch? = nil
    )
    {
        self.id = id
        self.runAt = runAt
        self.rawJSON = rawJSON
        self.errorMessage = errorMessage
        self.requestCount = requestCount
        self.savedSearch = savedSearch
    }
}
