/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftUI

/**
 * Editor for a search's result filters, presented from the results header's Filters button.
 *
 * Every row is driven by `ResultFilterBounds`, so only the filters the returned fares can actually
 * support are offered. Dragging a range back to its full extent clears that filter rather than
 * leaving it set to "everything".
 */
struct ResultFiltersPopover: View
{
    var bounds: ResultFilterBounds
    var isRoundTrip: Bool
    @Binding var filters: ResultFilters

    // Departure, arrival and inbound-departure times are filtered across the whole clock rather than
    // only the span the results happen to cover, so "leaves after 06:00" means the same thing
    // whatever the data; the bounds derived from the fares only decide whether the filter is worth
    // offering at all.
    private static let clockMinuteBounds: ClosedRange< Double > = 0 ... Double( 24 * 60 - 1 )

    var body: some View
    {
        Form
        {
            Section
            {
                if let priceRange = self.bounds.priceRange
                {
                    RangeFilterRow(
                        title: "Price",
                        bounds: priceRange,
                        step: 1,
                        format: self.priceLabel,
                        lower: self.$filters.minPrice,
                        upper: self.$filters.maxPrice
                    )
                }

                if let tripDurationRange = self.bounds.tripDurationRange
                {
                    RangeFilterRow(
                        title: "Trip",
                        bounds: Double( tripDurationRange.lowerBound ) ... Double( tripDurationRange.upperBound ),
                        step: 1,
                        format: { SavedSearch.nightsLabel( forNights: Int( $0.rounded() ) ) },
                        lower: self.wholeNumberBinding( self.$filters.minTripDurationDays ),
                        upper: self.wholeNumberBinding( self.$filters.maxTripDurationDays )
                    )
                }

                if let dateRange = self.bounds.dateRange
                {
                    RangeFilterRow(
                        title: Self.outboundRowTitle( "Date", isRoundTrip: self.isRoundTrip ),
                        bounds: 0 ... Double( ResultFilters.dayIndex( for: dateRange.upperBound, from: dateRange.lowerBound ) ),
                        step: 1,
                        format: { ResultFilters.dateLabel( for: ResultFilters.date( atDayIndex: Int( $0.rounded() ), from: dateRange.lowerBound, isEndOfDay: false ) ) },
                        lower: self.dayBinding( self.$filters.startDate, from: dateRange.lowerBound, isEndOfDay: false ),
                        upper: self.dayBinding( self.$filters.endDate, from: dateRange.lowerBound, isEndOfDay: true )
                    )
                }

                if self.bounds.carriers.isEmpty == false
                {
                    MultiSelectFilterRow(
                        title: Self.outboundRowTitle( "Carriers", isRoundTrip: self.isRoundTrip ),
                        noun: "carriers",
                        values: self.bounds.carriers,
                        selection: self.$filters.carriers
                    )
                }

                if self.bounds.departureMinuteRange != nil
                {
                    RangeFilterRow(
                        title: Self.outboundRowTitle( "Departure", isRoundTrip: self.isRoundTrip ),
                        bounds: Self.clockMinuteBounds,
                        step: 5,
                        format: { ResultFilters.clockTimeLabel( forMinutes: Int( $0.rounded() ) ) },
                        lower: self.wholeNumberBinding( self.$filters.departureStartMinute ),
                        upper: self.wholeNumberBinding( self.$filters.departureEndMinute )
                    )
                }

                if self.bounds.arrivalMinuteRange != nil
                {
                    RangeFilterRow(
                        title: Self.outboundRowTitle( "Arrival", isRoundTrip: self.isRoundTrip ),
                        bounds: Self.clockMinuteBounds,
                        step: 5,
                        format: { ResultFilters.clockTimeLabel( forMinutes: Int( $0.rounded() ) ) },
                        lower: self.wholeNumberBinding( self.$filters.arrivalStartMinute ),
                        upper: self.wholeNumberBinding( self.$filters.arrivalEndMinute )
                    )
                }

                if let durationRange = self.bounds.durationRange
                {
                    RangeFilterRow(
                        title: Self.outboundRowTitle( "Duration", isRoundTrip: self.isRoundTrip ),
                        bounds: Double( durationRange.lowerBound ) ... Double( durationRange.upperBound ),
                        step: 5,
                        format: { ResultFilters.durationLabel( forMinutes: Int( $0.rounded() ) ) },
                        lower: self.wholeNumberBinding( self.$filters.minDurationMinutes ),
                        upper: self.wholeNumberBinding( self.$filters.maxDurationMinutes )
                    )
                }

                if let stopsRange = self.bounds.stopsRange
                {
                    self.maxStopsRow( stopsRange )
                }

                if self.bounds.flightNumbers.isEmpty == false
                {
                    MultiSelectFilterRow(
                        title: Self.outboundRowTitle( "Flight n°", isRoundTrip: self.isRoundTrip ),
                        noun: "flights",
                        values: self.bounds.flightNumbers,
                        selection: self.$filters.flightNumbers
                    )
                }

                if let inboundDateRange = self.bounds.inboundDateRange
                {
                    RangeFilterRow(
                        title: "Inbound date",
                        bounds: 0 ... Double( ResultFilters.dayIndex( for: inboundDateRange.upperBound, from: inboundDateRange.lowerBound ) ),
                        step: 1,
                        format: { ResultFilters.dateLabel( for: ResultFilters.date( atDayIndex: Int( $0.rounded() ), from: inboundDateRange.lowerBound, isEndOfDay: false ) ) },
                        lower: self.dayBinding( self.$filters.inboundStartDate, from: inboundDateRange.lowerBound, isEndOfDay: false ),
                        upper: self.dayBinding( self.$filters.inboundEndDate, from: inboundDateRange.lowerBound, isEndOfDay: true )
                    )
                }

                if self.bounds.inboundDepartureMinuteRange != nil
                {
                    RangeFilterRow(
                        title: "Inbound departure",
                        bounds: Self.clockMinuteBounds,
                        step: 5,
                        format: { ResultFilters.clockTimeLabel( forMinutes: Int( $0.rounded() ) ) },
                        lower: self.wholeNumberBinding( self.$filters.inboundDepartureStartMinute ),
                        upper: self.wholeNumberBinding( self.$filters.inboundDepartureEndMinute )
                    )
                }
            }

            Section
            {
                HStack
                {
                    Spacer()
                    Button( "Reset All" )
                    {
                        self.filters = ResultFilters()
                    }
                    .disabled( self.filters.isActive == false )
                }
            }
        }
        .formStyle( .grouped )
        .scrollDisabled( true )
        .frame( width: 420 )
    }

    private func priceLabel( _ amount: Double ) -> String
    {
        guard let currency = self.bounds.currency
        else
        {
            return "\( Int( amount ))"
        }
        return "\( Int( amount )) \( currency )"
    }

    private func maxStopsRow( _ range: ClosedRange< Int > ) -> some View
    {
        // The most stops any fare of this search has can't exclude anything, so picking it is how
        // the filter is cleared.
        let selection = Binding< Int >(
            get: { self.filters.maxStops ?? range.upperBound },
            set: { self.filters.maxStops = $0 >= range.upperBound ? nil : $0 }
        )

        return Picker( Self.outboundRowTitle( "Max stops", isRoundTrip: self.isRoundTrip ), selection: selection )
        {
            ForEach( Array( range ), id: \.self )
            { stops in
                Text( Self.maxStopsLabel( for: stops, isUnrestricted: stops >= range.upperBound ) )
                    .tag( stops )
            }
        }
    }

    /**
     * Titles a row filtering on the outbound leg. Every row this titles reads an outbound value,
     * and a round trip has a second leg those values could just as well belong to, so its rows name
     * the leg they narrow — without which "Direct only" would read as a promise about both legs.
     *
     * Sentence case is kept, matching the rows a one-way search shows rather than the results
     * table's Title Case column headings.
     *
     * @param title The row's title where there is only one leg to describe.
     * @param isRoundTrip Whether the search has an inbound leg to distinguish the outbound one from.
     * @return The title unchanged for a one-way search, and qualified as the outbound leg's for a round trip.
     */
    static func outboundRowTitle( _ title: String, isRoundTrip: Bool ) -> String
    {
        guard isRoundTrip
        else
        {
            return title
        }

        return "Outbound \( title.lowercased() )"
    }

    /**
     * Labels one entry of the max-stops menu.
     *
     * @param stops Maximum number of stops the entry allows.
     * @param isUnrestricted Whether that maximum is the most any fare of this search has, so choosing it excludes nothing.
     * @return "Any", "Direct only", "Up to 1 stop" or "Up to N stops".
     */
    static func maxStopsLabel( for stops: Int, isUnrestricted: Bool ) -> String
    {
        if isUnrestricted
        {
            return "Any"
        }
        if stops == 0
        {
            return "Direct only"
        }
        return "Up to \( stops ) stop\( stops == 1 ? "" : "s" )"
    }

    /**
     * Adapts a whole-number filter — minutes since midnight, total minutes, or nights — to the
     * slider's `Double` domain.
     *
     * @param source Binding to the stored filter value.
     * @return A binding usable by `RangeFilterRow`.
     */
    private func wholeNumberBinding( _ source: Binding< Int? > ) -> Binding< Double? >
    {
        Binding(
            get: { source.wrappedValue.map( Double.init ) },
            set: { source.wrappedValue = $0.map { Int( $0.rounded() ) } }
        )
    }

    /**
     * Adapts a date-valued filter to the slider's domain, which counts whole days from the earliest
     * departure the search has seen.
     *
     * @param source Binding to the stored filter value.
     * @param start Date day 0 corresponds to.
     * @param isEndOfDay Whether the bound should land on the last instant of the selected day.
     * @return A binding usable by `RangeFilterRow`.
     */
    private func dayBinding( _ source: Binding< Date? >, from start: Date, isEndOfDay: Bool ) -> Binding< Double? >
    {
        Binding(
            get: { source.wrappedValue.map { Double( ResultFilters.dayIndex( for: $0, from: start ) ) } },
            set: { source.wrappedValue = $0.map { ResultFilters.date( atDayIndex: Int( $0.rounded() ), from: start, isEndOfDay: isEndOfDay ) } }
        )
    }
}

// MARK: - Rows

/**
 * One labelled two-thumb range filter. A thumb sitting on its end of `bounds` means that end isn't
 * restricting anything, and is stored as nil.
 */
private struct RangeFilterRow: View
{
    var title: String
    var bounds: ClosedRange< Double >
    var step: Double
    var format: ( Double ) -> String
    @Binding var lower: Double?
    @Binding var upper: Double?

    var body: some View
    {
        LabeledContent( self.title )
        {
            RangeSlider(
                bounds: self.bounds,
                step: self.step,
                format: self.format,
                lowerValue: Binding(
                    get: { self.lower ?? self.bounds.lowerBound },
                    set: { self.lower = $0 <= self.bounds.lowerBound ? nil : $0 }
                ),
                upperValue: Binding(
                    get: { self.upper ?? self.bounds.upperBound },
                    set: { self.upper = $0 >= self.bounds.upperBound ? nil : $0 }
                )
            )
        }
    }
}

/**
 * One labelled multi-selection filter, presented as a menu of checkable values with All/None
 * shortcuts. A nil selection means the filter is off; an empty one means nothing is allowed through.
 */
private struct MultiSelectFilterRow: View
{
    var title: String
    var noun: String
    var values: [ String ]
    @Binding var selection: [ String ]?

    var body: some View
    {
        LabeledContent( self.title )
        {
            Menu( self.selection.map { ResultFilters.listLabel( $0, noun: self.noun ) } ?? "All" )
            {
                Button( "All" )
                {
                    self.selection = nil
                }
                Button( "None" )
                {
                    self.selection = []
                }

                Divider()

                ForEach( self.values, id: \.self )
                { value in
                    Toggle( value, isOn: self.binding( for: value ) )
                }
            }
        }
    }

    private func binding( for value: String ) -> Binding< Bool >
    {
        Binding(
            get: { self.selection?.contains( value ) ?? true },
            set: { isOn in
                var selected = self.selection ?? self.values
                selected.removeAll { $0 == value }
                if isOn
                {
                    selected.append( value )
                }

                // Selecting everything is the same as not filtering at all, so it clears rather
                // than storing a list that lets every fare through.
                let sorted = selected.sorted()
                self.selection = sorted == self.values ? nil : sorted
            }
        )
    }
}
