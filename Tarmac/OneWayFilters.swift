/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

/**
 * Per-search result filters for a one-way search, persisted on `SavedSearch`.
 *
 * Every field is nil when that filter is unset, rather than being pinned to the full extent of the
 * data — so a filter never becomes active on its own when a later run widens the available range,
 * and stored values never need clamping when the bounds shift underneath them.
 *
 * Filters combine with AND. See `OneWayFilterBounds` for the editable extents these values are
 * chosen from.
 */
struct OneWayFilters: Codable, Equatable
{
    var minPrice: Double?
    var maxPrice: Double?
    var startDate: Date?
    var endDate: Date?
    var carriers: [ String ]?               // nil = every carrier
    var departureStartMinute: Int?          // minutes since midnight
    var departureEndMinute: Int?
    var arrivalStartMinute: Int?
    var arrivalEndMinute: Int?
    var minDurationMinutes: Int?
    var maxDurationMinutes: Int?
    var maxStops: Int?
    var flightNumbers: [ String ]?          // nil = every flight number

    // MARK: - State

    /**
     * Number of filters currently narrowing the results. A range filter counts once even when both
     * of its ends are set, matching how it's presented as a single control and a single chip.
     *
     * @return The count of active filters, 0 when nothing is set.
     */
    var activeCount: Int
    {
        let isSet = [
            self.minPrice != nil || self.maxPrice != nil,
            self.startDate != nil || self.endDate != nil,
            self.carriers != nil,
            self.departureStartMinute != nil || self.departureEndMinute != nil,
            self.arrivalStartMinute != nil || self.arrivalEndMinute != nil,
            self.minDurationMinutes != nil || self.maxDurationMinutes != nil,
            self.maxStops != nil,
            self.flightNumbers != nil,
        ]

        return isSet.filter { $0 }.count
    }

    /**
     * Whether any filter is set.
     */
    var isActive: Bool
    {
        self.activeCount > 0
    }

    // MARK: - Matching

    /**
     * Tests one fare against every active filter.
     *
     * A fare missing the value a filter tests (e.g. no recorded carrier) is excluded while that
     * filter is active, so an active filter never silently lets unknown data through.
     *
     * @param snapshot Fare to test.
     * @return true when the fare satisfies every active filter.
     */
    func matches( _ snapshot: PriceSnapshot ) -> Bool
    {
        if let minPrice,
           snapshot.amount.isFinite == false || snapshot.amount < minPrice
        {
            return false
        }
        if let maxPrice,
           snapshot.amount.isFinite == false || snapshot.amount > maxPrice
        {
            return false
        }

        if self.startDate != nil || self.endDate != nil
        {
            guard let departureDate = snapshot.departureDate
            else
            {
                return false
            }
            if let startDate,
               departureDate < startDate
            {
                return false
            }
            if let endDate,
               departureDate > endDate
            {
                return false
            }
        }

        if let carriers
        {
            guard let carrier = snapshot.carrier,
                  carriers.contains( carrier )
            else
            {
                return false
            }
        }

        if Self.isOutside(
            Self.minutes( fromClockTime: snapshot.departureTime ),
            start: self.departureStartMinute,
            end: self.departureEndMinute
        )
        {
            return false
        }

        // Arrival is a bare "HH:mm" wall-clock time with no date, so a flight landing the next
        // morning is matched on that morning's clock time.
        if Self.isOutside(
            Self.minutes( fromClockTime: snapshot.arrivalTime ),
            start: self.arrivalStartMinute,
            end: self.arrivalEndMinute
        )
        {
            return false
        }

        if Self.isOutside(
            Self.minutes( fromDuration: snapshot.outboundDuration ),
            start: self.minDurationMinutes,
            end: self.maxDurationMinutes
        )
        {
            return false
        }

        if let maxStops
        {
            guard let stopCount = snapshot.outboundStopCount,
                  stopCount <= maxStops
            else
            {
                return false
            }
        }

        if let flightNumbers
        {
            guard snapshot.outboundFlightNumbers.contains( where: { flightNumbers.contains( $0 ) } )
            else
            {
                return false
            }
        }

        return true
    }

    /**
     * Filters a collection of fares down to the ones matching every active filter, preserving order.
     *
     * @param snapshots Fares to filter.
     * @return The matching fares.
     */
    func apply( to snapshots: [ PriceSnapshot ] ) -> [ PriceSnapshot ]
    {
        guard self.isActive
        else
        {
            return snapshots
        }
        return snapshots.filter { self.matches( $0 ) }
    }

    /**
     * Tests one optional value against an optional lower and upper bound. A nil value fails as soon
     * as either bound is set, and passes when neither is.
     *
     * @param value Value to test, or nil when the fare doesn't carry it.
     * @param start Inclusive lower bound, or nil if unset.
     * @param end Inclusive upper bound, or nil if unset.
     * @return true when the value falls outside an active bound.
     */
    private static func isOutside( _ value: Int?, start: Int?, end: Int? ) -> Bool
    {
        guard start != nil || end != nil
        else
        {
            return false
        }

        guard let value
        else
        {
            return true
        }

        if let start,
           value < start
        {
            return true
        }
        if let end,
           value > end
        {
            return true
        }
        return false
    }

    // MARK: - Parsing

    /**
     * Parses a wall-clock time as stored on a fare into minutes since midnight.
     *
     * @param clockTime Time in "HH:mm" form, e.g. "06:35".
     * @return Minutes since midnight, or nil if the string is missing or unparseable.
     */
    static func minutes( fromClockTime clockTime: String? ) -> Int?
    {
        guard let clockTime,
              let separatorIndex = clockTime.firstIndex( of: ":" ),
              let hours = Int( clockTime[ clockTime.startIndex ..< separatorIndex ] ),
              let minutes = Int( clockTime[ clockTime.index( after: separatorIndex )... ] ),
              ( 0 ... 23 ).contains( hours ),
              ( 0 ... 59 ).contains( minutes )
        else
        {
            return nil
        }
        return hours * 60 + minutes
    }

    /**
     * Parses a leg duration as stored on a fare into total minutes.
     *
     * @param duration Duration in "<h>h<mm>" form, e.g. "10h30".
     * @return Total minutes, or nil if the string is missing or unparseable.
     */
    static func minutes( fromDuration duration: String? ) -> Int?
    {
        guard let duration,
              let hourIndex = duration.firstIndex( of: "h" ),
              let hours = Int( duration[ duration.startIndex ..< hourIndex ] ),
              let minutes = Int( duration[ duration.index( after: hourIndex )... ] )
        else
        {
            return nil
        }
        return hours * 60 + minutes
    }

    // MARK: - Days

    // Departure dates are compared in UTC throughout the app (see `SavedSearch.dateRangeLabel`),
    // so the date filter counts whole UTC days too.
    private static let calendar: Calendar = {
        var c = Calendar( identifier: .gregorian )
        c.timeZone = TimeZone( identifier: "UTC" )!
        return c
    }()

    /**
     * Number of whole days from one date to another, used to drive the date filter's slider by day
     * rather than by timestamp.
     *
     * @param date Date to place.
     * @param start Date day 0 corresponds to.
     * @return The day offset, which may be negative if `date` precedes `start`.
     */
    static func dayIndex( for date: Date, from start: Date ) -> Int
    {
        let startDay = Self.calendar.startOfDay( for: start )
        let day      = Self.calendar.startOfDay( for: date )
        return Self.calendar.dateComponents( [ .day ], from: startDay, to: day ).day ?? 0
    }

    /**
     * Resolves a day offset back to a date bound.
     *
     * @param index Day offset from `start`.
     * @param start Date day 0 corresponds to.
     * @param isEndOfDay Whether to return the last instant of that day rather than its first, so a fare departing late in the day still falls inside an upper bound set on it.
     * @return The date bound.
     */
    static func date( atDayIndex index: Int, from start: Date, isEndOfDay: Bool ) -> Date
    {
        let startDay = Self.calendar.startOfDay( for: start )
        let day      = Self.calendar.date( byAdding: .day, value: index, to: startDay ) ?? startDay
        guard isEndOfDay
        else
        {
            return day
        }
        return Self.calendar.date( byAdding: .day, value: 1, to: day ).map { $0.addingTimeInterval( -1 ) } ?? day
    }

    // MARK: - Formatting

    /**
     * Renders minutes since midnight back as a wall-clock label.
     *
     * @param minutes Minutes since midnight.
     * @return The time in "HH:mm" form.
     */
    static func clockTimeLabel( forMinutes minutes: Int ) -> String
    {
        String( format: "%02d:%02d", minutes / 60, minutes % 60 )
    }

    /**
     * Renders a number of minutes as a duration label, matching how durations are shown in the
     * itinerary table.
     *
     * @param minutes Total minutes.
     * @return The duration in "<h>h<mm>" form.
     */
    static func durationLabel( forMinutes minutes: Int ) -> String
    {
        "\( minutes / 60 )h\( String( format: "%02d", minutes % 60 ) )"
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale( identifier: "en_US" )
        f.timeZone = TimeZone( identifier: "UTC" )
        return f
    }()

    /**
     * Renders a departure date as a short day/month label, matching the sidebar's date ranges.
     *
     * @param date Date to render.
     * @return The date in "5 Oct" form.
     */
    static func dateLabel( for date: Date ) -> String
    {
        Self.dayFormatter.string( from: date )
    }

    // MARK: - Chips

    /**
     * One active filter, as shown in the results header's chip strip: a stable identity, a label
     * summarizing what it restricts to, and the filter set with just that one filter removed.
     */
    struct Chip: Identifiable, Equatable
    {
        let id: String
        let label: String
        let cleared: OneWayFilters
    }

    /**
     * Describes every currently active filter, in the order they're presented in the popover.
     *
     * @return One chip per active filter; empty when nothing is set.
     */
    func chips() -> [ Chip ]
    {
        var chips: [ Chip ] = []

        if self.minPrice != nil || self.maxPrice != nil
        {
            var cleared = self
            cleared.minPrice = nil
            cleared.maxPrice = nil
            chips.append( Chip( id: "price", label: "Price \( Self.rangeLabel( self.minPrice.map( Self.priceLabel ), self.maxPrice.map( Self.priceLabel ) ) )", cleared: cleared ) )
        }

        if self.startDate != nil || self.endDate != nil
        {
            var cleared = self
            cleared.startDate = nil
            cleared.endDate = nil
            chips.append( Chip( id: "date", label: "Date \( Self.rangeLabel( self.startDate.map( Self.dateLabel(for:) ), self.endDate.map( Self.dateLabel(for:) ) ) )", cleared: cleared ) )
        }

        if let carriers
        {
            var cleared = self
            cleared.carriers = nil
            chips.append( Chip( id: "carriers", label: Self.listLabel( carriers, noun: "carriers" ), cleared: cleared ) )
        }

        if self.departureStartMinute != nil || self.departureEndMinute != nil
        {
            var cleared = self
            cleared.departureStartMinute = nil
            cleared.departureEndMinute = nil
            chips.append( Chip( id: "departure", label: "Departs \( Self.rangeLabel( self.departureStartMinute.map( Self.clockTimeLabel(forMinutes:) ), self.departureEndMinute.map( Self.clockTimeLabel(forMinutes:) ) ) )", cleared: cleared ) )
        }

        if self.arrivalStartMinute != nil || self.arrivalEndMinute != nil
        {
            var cleared = self
            cleared.arrivalStartMinute = nil
            cleared.arrivalEndMinute = nil
            chips.append( Chip( id: "arrival", label: "Arrives \( Self.rangeLabel( self.arrivalStartMinute.map( Self.clockTimeLabel(forMinutes:) ), self.arrivalEndMinute.map( Self.clockTimeLabel(forMinutes:) ) ) )", cleared: cleared ) )
        }

        if self.minDurationMinutes != nil || self.maxDurationMinutes != nil
        {
            var cleared = self
            cleared.minDurationMinutes = nil
            cleared.maxDurationMinutes = nil
            chips.append( Chip( id: "duration", label: "Duration \( Self.rangeLabel( self.minDurationMinutes.map( Self.durationLabel(forMinutes:) ), self.maxDurationMinutes.map( Self.durationLabel(forMinutes:) ) ) )", cleared: cleared ) )
        }

        if let maxStops
        {
            var cleared = self
            cleared.maxStops = nil
            let label = maxStops == 0 ? "Direct only" : "≤ \( maxStops ) stop\( maxStops == 1 ? "" : "s" )"
            chips.append( Chip( id: "stops", label: label, cleared: cleared ) )
        }

        if let flightNumbers
        {
            var cleared = self
            cleared.flightNumbers = nil
            chips.append( Chip( id: "flightNumbers", label: Self.listLabel( flightNumbers, noun: "flights" ), cleared: cleared ) )
        }

        return chips
    }

    /**
     * Labels a range filter from its two optional ends, e.g. "120–480", "≥ 120" or "≤ 480".
     *
     * @param lower Rendered lower bound, or nil if unset.
     * @param upper Rendered upper bound, or nil if unset.
     * @return The range label; empty when neither end is set.
     */
    static func rangeLabel( _ lower: String?, _ upper: String? ) -> String
    {
        switch ( lower, upper )
        {
            case let ( .some( lower ), .some( upper ) ):
                return "\( lower )–\( upper )"

            case let ( .some( lower ), .none ):
                return "≥ \( lower )"

            case let ( .none, .some( upper ) ):
                return "≤ \( upper )"

            case ( .none, .none ):
                return ""
        }
    }

    /**
     * Labels a multi-selection filter, spelling the values out while there are few enough to read
     * and collapsing to a count beyond that.
     *
     * @param values Selected values.
     * @param noun Plural noun describing what was selected, e.g. "carriers".
     * @return The label, e.g. "LX, TP" or "4 flights" or "No carriers".
     */
    static func listLabel( _ values: [ String ], noun: String ) -> String
    {
        guard values.isEmpty == false
        else
        {
            return "No \( noun )"
        }
        guard values.count > 3
        else
        {
            return values.joined( separator: ", " )
        }
        return "\( values.count ) \( noun )"
    }

    private static func priceLabel( _ amount: Double ) -> String
    {
        "\( Int( amount ))"
    }
}
