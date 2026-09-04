/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData

enum SearchKind: String, Codable
{
    case oneWay
    case roundTrip
}

@Model
final class SavedSearch
{
    var id: UUID
    var createdAt: Date
    var isSeeded: Bool = false
    var kind: SearchKind
    var origin: String
    var destination: String
    var rangeStart: Date
    var rangeEnd: Date
    var cabinClass: String
    var directOnly: Bool
    var carryOnIncluded: Bool = false
    var checkedBagIncluded: Bool = false
    var passengers: Int = 1

    // Round-trip-only fields, ignored for one-way searches.
    var tripDurationDays: Int
    var flexibilityDays: Int
    var mustIncludeWeekend: Bool

    // Result filters this search's itinerary table and price history are narrowed by, remembered
    // across runs and across app launches. One-way-only for now; nil means nothing is filtered.
    var oneWayFilters: OneWayFilters? = nil

    @Relationship( deleteRule: .cascade, inverse: \SearchRun.savedSearch )     var runs: [ SearchRun ] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        isSeeded: Bool = false,
        kind: SearchKind,
        origin: String,
        destination: String,
        rangeStart: Date,
        rangeEnd: Date,
        cabinClass: String,
        directOnly: Bool = true,
        carryOnIncluded: Bool = false,
        checkedBagIncluded: Bool = false,
        passengers: Int = 1,
        tripDurationDays: Int = 3,
        flexibilityDays: Int = 0,
        mustIncludeWeekend: Bool = false
    )
    {
        self.id = id
        self.createdAt = createdAt
        self.isSeeded = isSeeded
        self.kind = kind
        self.origin = origin
        self.destination = destination
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.cabinClass = cabinClass
        self.directOnly = directOnly
        self.carryOnIncluded = carryOnIncluded
        self.checkedBagIncluded = checkedBagIncluded
        self.passengers = passengers
        self.tripDurationDays = tripDurationDays
        self.flexibilityDays = flexibilityDays
        self.mustIncludeWeekend = mustIncludeWeekend
    }

    /**
     * Short summary for sidebar rows, e.g. "GVA → LIS · round trip · 5–12 Oct".
     */
    var summary: String
    {
        "\( self.origin ) → \( self.destination ) · \( self.tripDetail )"
    }

    /**
     * Trip kind and date range, e.g. "round trip · 5–12 Oct".
     */
    var tripDetail: String
    {
        let kindLabel = self.kind == .roundTrip ? "round trip" : "one-way"
        return "\( kindLabel ) · \( self.dateRangeLabel )"
    }

    /**
     * This search's runs, most recent first.
     */
    var runsNewestFirst: [ SearchRun ]
    {
        self.runs.sorted { $0.runAt > $1.runAt }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        f.locale = Locale( identifier: "en_US" )
        f.timeZone = TimeZone( identifier: "UTC" )
        return f
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale( identifier: "en_US" )
        f.timeZone = TimeZone( identifier: "UTC" )
        return f
    }()

    private var dateRangeLabel: String
    {
        var calendar = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!

        let start = min( self.rangeStart, self.rangeEnd )
        let end   = max( self.rangeStart, self.rangeEnd )

        let sameMonth = calendar.isDate( start, equalTo: end, toGranularity: .month )

        if sameMonth
        {
            let startLabel = Self.dayFormatter.string( from: start )
            let endLabel   = Self.dayMonthFormatter.string( from: end )
            return "\( startLabel )–\( endLabel )"
        }
        else
        {
            let startLabel = Self.dayMonthFormatter.string( from: start )
            let endLabel   = Self.dayMonthFormatter.string( from: end )
            return "\( startLabel ) – \( endLabel )"
        }
    }
}
