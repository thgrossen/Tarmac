/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

enum DepartureDateDefaults
{
    private static var utcCalendar: Calendar
    {
        var calendar = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        return calendar
    }

    /**
     * The earliest selectable departure date: midnight UTC the day after `referenceDate`.
     *
     * @param referenceDate Date to compute "today" from; defaults to now.
     * @return Midnight UTC tomorrow.
     */
    static func earliestDeparture( referenceDate: Date = .now ) -> Date
    {
        let calendar = Self.utcCalendar
        let today = calendar.startOfDay( for: referenceDate )
        return calendar.date( byAdding: .day, value: 1, to: today )!
    }

    /**
     * The default 1-day browsing window for a brand-new search, starting tomorrow.
     *
     * @param referenceDate Date to compute "today" from; defaults to now.
     * @return A range starting tomorrow and ending one day later.
     */
    static func defaultRange( referenceDate: Date = .now ) -> SearchDateSession.DateRange
    {
        let start = Self.earliestDeparture( referenceDate: referenceDate )
        let end = Self.utcCalendar.date( byAdding: .day, value: 1, to: start )!
        return SearchDateSession.DateRange( start: start, end: end )
    }

    /**
     * Clamps a departure date range so it never starts before the earliest selectable
     * date, regardless of where it was pre-filled from (e.g. a session-scoped range
     * recorded before an app session crossed a day boundary).
     *
     * @param range Range to clamp.
     * @param referenceDate Date to compute "today" from; defaults to now.
     * @return `range` unchanged if already valid, otherwise shifted so both ends respect the earliest selectable date.
     */
    static func clamped( _ range: SearchDateSession.DateRange, referenceDate: Date = .now ) -> SearchDateSession.DateRange
    {
        let earliest = Self.earliestDeparture( referenceDate: referenceDate )
        let start = max( range.start, earliest )
        let end = max( range.end, start )
        return SearchDateSession.DateRange( start: start, end: end )
    }
}
