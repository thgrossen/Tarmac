/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData

enum DefaultSearchSeeder
{
    /**
     * Inserts a saved search reproducing the app's pre-upgrade hardcoded
     * GVA → LIS round trip, if no saved search exists yet.
     *
     * @param context Model context to seed.
     * @param referenceDate Date to compute the default search's departure window from; defaults to now.
     */
    static func seedIfNeeded( in context: ModelContext, referenceDate: Date = .now )
    {
        let existingCount = ( try? context.fetchCount( FetchDescriptor< SavedSearch >() ) ) ?? 0
        guard existingCount == 0
        else
        {
            return
        }

        var calendar      = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        let today = calendar.startOfDay( for: referenceDate )
        guard let departure = calendar.date( byAdding: .day, value: 60, to: today )
        else
        {
            return
        }

        let defaultSearch = SavedSearch(
            isSeeded: true,
            kind: .roundTrip,
            origin: "GVA",
            destination: "LIS",
            rangeStart: departure,
            rangeEnd: departure,
            cabinClass: "business",
            directOnly: true,
            carryOnIncluded: false,
            checkedBagIncluded: false,
            tripDurationDays: 3,
            flexibilityDays: 0,
            mustIncludeWeekend: false
        )
        context.insert( defaultSearch )
        try? context.save()
    }
}
