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
     * Origin and destination joined by an arrow whose heads say which way the trip runs, e.g.
     * "AAA → BBB" for a one-way and "AAA ↔ BBB" for a round trip.
     */
    var routeLabel: String
    {
        let arrow = self.kind == .roundTrip ? "↔" : "→"
        return "\( self.origin ) \( arrow ) \( self.destination )"
    }

    /**
     * Short summary for sidebar rows, e.g. "AAA ↔ BBB · round trip · 5–15 Oct".
     */
    var summary: String
    {
        "\( self.routeLabel ) · \( self.tripDetail )"
    }

    /**
     * Trip kind and date range, e.g. "round trip · 5–15 Oct". A round trip's range runs from its
     * earliest departure to the latest day it could return, not to its latest departure.
     */
    var tripDetail: String
    {
        let kindLabel = self.kind == .roundTrip ? "round trip" : "one-way"
        return "\( kindLabel ) · \( self.dateRangeLabel )"
    }

    /**
     * The trip durations, in nights, a round-trip sweep covers: the chosen duration widened by the
     * flexibility either side, never shorter than a single night.
     *
     * Meaningless for a one-way search, whose round-trip fields carry their defaults.
     */
    var searchedDurationRange: ClosedRange< Int >
    {
        let shortest = max( 1, self.tripDurationDays - self.flexibilityDays )
        let longest  = max( shortest, self.tripDurationDays + self.flexibilityDays )
        return shortest ... longest
    }

    /**
     * The last day a round trip could return on: the latest departure plus the longest duration
     * searched. Nil for a one-way search, which has no return.
     *
     * This is the span the search asks for, not the pairs that survive `mustIncludeWeekend` — a
     * weekend requirement can drop the very pair that reaches this date. The departure side reads
     * the same way, printing `rangeStart` even when the first few departures are filtered out.
     */
    var latestReturnDate: Date?
    {
        guard self.kind == .roundTrip
        else
        {
            return nil
        }

        // Normalised the same way the sweep normalises its range, so the label and the candidates
        // agree even when a stored bound carries a time component.
        let latestDeparture = Self.utcCalendar.startOfDay( for: max( self.rangeStart, self.rangeEnd ) )
        return Self.utcCalendar.date( byAdding: .day, value: self.searchedDurationRange.upperBound, to: latestDeparture )
    }

    /**
     * How a trip duration reads, both beside the search form's stepper and in a details summary.
     *
     * @param nights Trip duration in nights.
     * @return A singular or plural night count.
     */
    static func nightsLabel( forNights nights: Int ) -> String
    {
        "\( nights ) night\( nights == 1 ? "" : "s" )"
    }

    /**
     * How a cabin class reads in a details summary, in the lower case the summary's other
     * components use.
     *
     * @param cabinClass Stored cabin class, as sent to Ignav.
     * @return A short label, or the stored value unchanged when it isn't one this app offers.
     */
    static func cabinLabel( for cabinClass: String ) -> String
    {
        switch cabinClass
        {
            case "economy":         return "economy"
            case "premium_economy": return "premium"
            case "business":        return "business"
            case "first":           return "first"
            default:                return cabinClass
        }
    }

    /**
     * The parameters a round-trip run was made with, for display beside its results, e.g.
     * "3 nights ±2 · weekend · direct · business · 1 passenger". Components that are off or
     * unset are left out rather than stated as absent, so the line says only what was asked for.
     *
     * @param search Search to describe.
     * @return The summary, or nil for a one-way search, whose parameters the results already show.
     */
    static func detailsSummary( for search: SavedSearch ) -> String?
    {
        guard search.kind == .roundTrip
        else
        {
            return nil
        }

        var components: [ String ] = []

        let nights = Self.nightsLabel( forNights: search.tripDurationDays )
        components.append( search.flexibilityDays > 0 ? "\( nights ) ±\( search.flexibilityDays )" : nights )

        if search.mustIncludeWeekend
        {
            components.append( "weekend" )
        }
        if search.directOnly
        {
            components.append( "direct" )
        }

        components.append( Self.cabinLabel( for: search.cabinClass ) )

        if search.carryOnIncluded
        {
            components.append( "carry-on" )
        }
        if search.checkedBagIncluded
        {
            components.append( "checked bag" )
        }

        components.append( "\( search.passengers ) passenger\( search.passengers == 1 ? "" : "s" )" )

        return components.joined( separator: " · " )
    }

    /**
     * This search's runs, most recent first.
     */
    var runsNewestFirst: [ SearchRun ]
    {
        self.runs.sorted { $0.runAt > $1.runAt }
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        return calendar
    }()

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
        // A round trip's range bounds are both departures, so its span runs to the latest day it
        // could still be returning on rather than to the last day it could set off. The nil case is
        // a one-way search, which has no return and spans its departures alone.
        let start = Self.utcCalendar.startOfDay( for: min( self.rangeStart, self.rangeEnd ) )
        let end   = self.latestReturnDate ?? Self.utcCalendar.startOfDay( for: max( self.rangeStart, self.rangeEnd ) )

        let sameMonth = Self.utcCalendar.isDate( start, equalTo: end, toGranularity: .month )

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
