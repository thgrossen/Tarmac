/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Charts
import SwiftData
import SwiftUI

struct RunHistoryView: View
{
    var runs: [ SearchRun ]     // newest first
    @Binding var selection: SearchRun?
    var filters: OneWayFilters?

    /**
     * Title and body copy for the itinerary table's empty state, which distinguishes a run that
     * came back with nothing from one whose results the filters have hidden entirely.
     *
     * @param isFiltered Whether the run returned fares that the active filters excluded.
     * @return The empty state's title and description.
     */
    static func emptyState( isFiltered: Bool ) -> ( title: String, description: String )
    {
        if isFiltered
        {
            return ( "No fares match these filters", "Widen or clear the filters to see this update's itineraries." )
        }
        return ( "No fares found", "This run returned no itineraries." )
    }

    var body: some View
    {
        VStack( spacing: 0 )
        {
            if PriceHistoryChart.chartRuns( for: self.runs ).count > 1
            {
                PriceHistoryChart( runs: self.runs, selection: self.$selection, filters: self.filters )

                Divider()
            }

            if let selectedRun = self.selection
            {
                RunDetailView( run: selectedRun, filters: self.filters )
            }
            else
            {
                ContentUnavailableView(
                    "No run selected",
                    systemImage: "clock.arrow.circlepath",
                    description: Text( "Pick a run above to see its itineraries." )
                )
                .frame( maxWidth: .infinity, maxHeight: .infinity )
            }
        }
    }
}

// MARK: - Price history chart

struct PriceHistoryChart: View
{
    var runs: [ SearchRun ]     // newest first
    @Binding var selection: SearchRun?
    var filters: OneWayFilters?

    @State private var hoveredRunID: String?
    @State private var hoverLocation: CGPoint?
    @Environment( \.controlActiveState ) private var controlActiveState

    private static let barWidth: CGFloat = 22
    private static let barSlotWidth: CGFloat = 32
    private static let tooltipTimeFormat = Date.FormatStyle().month( .abbreviated ).day().hour().minute()

    /**
     * Runs to plot, oldest first (for left-to-right reading). Every run gets a slot — including
     * ones with no fares (an error, or none found) — so they stay reachable/selectable via the
     * chart; see `barExtent(for:yDomain:)` for how those are drawn.
     *
     * @param runs Runs to reorder, newest first.
     * @return The runs to plot, oldest first.
     */
    static func chartRuns( for runs: [ SearchRun ] ) -> [ SearchRun ]
    {
        runs.reversed()
    }

    /**
     * Y-axis domain spanning every plotted run's low/high range, padded by 10% of the overall
     * span (or a flat $1 if every run has the exact same price) so bars don't touch the chart's
     * edges.
     *
     * @param runs Runs to plot (see `chartRuns(for:)`).
     * @param filters Results filters the plotted prices are narrowed by, or nil to plot every fare.
     * @return The padded domain, or 0...1 if there is nothing to plot.
     */
    static func yDomain( for runs: [ SearchRun ], filters: OneWayFilters? = nil ) -> ClosedRange< Double >
    {
        let ranges = runs.compactMap { $0.fareRange( matching: filters ) }
        let lows   = ranges.map( \.low )
        let highs  = ranges.map( \.high )
        guard let minLow = lows.min(),
              let maxHigh = highs.max()
        else
        {
            return 0...1
        }

        let padding = max( ( maxHigh - minLow ) * 0.1, 1 )
        return ( minLow - padding )...( maxHigh + padding )
    }

    /**
     * The low/high range to draw a run's bar over: its actual cheapest/most-expensive fare, or,
     * for a run with no fares to plot (an error, none found, or none matching the filters), a thin
     * flat marker sitting at the bottom of the y-axis domain — keeping it visible and selectable
     * without implying a price.
     *
     * @param run The run to compute a bar extent for.
     * @param yDomain The chart's y-axis domain (see `yDomain(for:)`).
     * @param filters Results filters the plotted prices are narrowed by, or nil to plot every fare.
     * @return The bar's low and high values, in the same units as `yDomain`.
     */
    static func barExtent( for run: SearchRun, yDomain: ClosedRange< Double >, filters: OneWayFilters? = nil ) -> ( low: Double, high: Double )
    {
        if let range = run.fareRange( matching: filters )
        {
            return range
        }

        let markerHeight = ( yDomain.upperBound - yDomain.lowerBound ) * 0.03
        return ( yDomain.lowerBound, yDomain.lowerBound + markerHeight )
    }

    /**
     * The chart's categorical x-axis domain: the runs' own IDs, followed by enough unique
     * placeholder categories to fill the rest of the available width. Swift Charts spreads a
     * nominal axis' categories evenly across the whole plot width, so without this padding, a
     * handful of bars in a full-width chart would be spread out with large gaps between them
     * instead of packed to the left with the leftover space after them.
     *
     * @param chartRuns Runs to plot (see `chartRuns(for:)`), oldest first.
     * @param availableWidth The chart's available plotting width.
     * @param slotWidth Width reserved per category (bar plus gap).
     * @return The runs' IDs, plus placeholder IDs for any unused trailing slots.
     */
    static func paddedDomainValues( chartRuns: [ SearchRun ], availableWidth: CGFloat, slotWidth: CGFloat ) -> [ String ]
    {
        let ids = chartRuns.map( \.id.uuidString )
        guard slotWidth > 0
        else
        {
            return ids
        }

        let totalSlots  = max( ids.count, Int( ( availableWidth / slotWidth ).rounded( .down ) ) )
        let paddingCount = totalSlots - ids.count
        guard paddingCount > 0
        else
        {
            return ids
        }

        return ids + ( 0..<paddingCount ).map { "__padding-\( $0 )" }
    }

    private var chartRuns: [ SearchRun ] { Self.chartRuns( for: self.runs ) }

    // Suppresses the hover tint/tooltip while the app isn't frontmost, matching the sidebar's
    // own hover treatment, without discarding the raw hover state `onContinuousHover` tracks.
    private var effectiveHoveredRunID: String?
    {
        self.controlActiveState == .inactive ? nil : self.hoveredRunID
    }

    private var hoveredRun: SearchRun?
    {
        guard let effectiveHoveredRunID
        else
        {
            return nil
        }
        return self.runs.first( where: { $0.id.uuidString == effectiveHoveredRunID } )
    }

    /**
     * Base fill color for one bar, before any hover tint: the full accent color for the currently
     * selected run, a muted secondary tint for a run with no fares to plot (an error, or none
     * found), a light/translucent accent for the most recent update when it isn't selected,
     * otherwise the system's gray "selected, window not key" color, for a lower-key look.
     *
     * @param isLatest Whether the bar is the most recent update being plotted.
     * @param isSelected Whether the bar is the currently selected run.
     * @param hasFare Whether the run found at least one fare to plot a real range for.
     * @return The color to fill the bar with.
     */
    /**
     * Currency the plotted prices are quoted in, taken from the first fare that carries a usable
     * price. Every fare of a search is quoted in the same market's currency, so one is enough.
     *
     * @param runs Runs being plotted.
     * @return The currency code, or nil if no run has a usable price.
     */
    static func currency( for runs: [ SearchRun ] ) -> String?
    {
        for run in runs
        {
            if let currency = run.itineraries.first( where: { $0.amount.isFinite } )?.currency
            {
                return currency
            }
        }
        return nil
    }

    /**
     * Labels one y-axis tick, naming the currency so the axis reads as money rather than as bare
     * numbers.
     *
     * @param amount Price the tick sits at.
     * @param currency Currency the prices are quoted in, or nil if it isn't known.
     * @return The tick's label, e.g. "300 CHF".
     */
    static func axisLabel( for amount: Double, currency: String? ) -> String
    {
        let rounded = Int( amount.rounded() )
        guard let currency
        else
        {
            return "\( rounded )"
        }
        return "\( rounded ) \( currency )"
    }

    private func barColor( isLatest: Bool, isSelected: Bool, hasFare: Bool ) -> Color
    {
        if isSelected
        {
            return Color.accentColor
        }
        if hasFare == false
        {
            return Color.secondary.opacity( 0.4 )
        }
        if isLatest
        {
            return Color.accentColor.opacity( 0.4 )
        }
        return Color( nsColor: .unemphasizedSelectedContentBackgroundColor )
    }

    var body: some View
    {
        GeometryReader
        { outerGeometry in
            let chartRuns = self.chartRuns
            let yDomain = Self.yDomain( for: chartRuns, filters: self.filters )
            let currency = Self.currency( for: chartRuns )
            let domainValues = Self.paddedDomainValues(
                chartRuns: chartRuns,
                availableWidth: outerGeometry.size.width,
                slotWidth: Self.barSlotWidth
            )

            Chart( chartRuns, id: \.id )
            { run in
                let extent = Self.barExtent( for: run, yDomain: yDomain, filters: self.filters )
                let hasFare = run.fareRange( matching: self.filters ) != nil

                BarMark(
                    x: .value( "Run", run.id.uuidString ),
                    yStart: .value( "Low", extent.low ),
                    yEnd: .value( "High", extent.high ),
                    width: .fixed( Self.barWidth )
                )
                .foregroundStyle( self.barColor( isLatest: run.id == chartRuns.last?.id, isSelected: run.id == self.selection?.id, hasFare: hasFare ) )

                // Layered on top of the base bar (rather than replacing its color) so the
                // hover tint blends with whatever's underneath it, matching how the sidebar's
                // row-hover tint sits over the row's own background instead of replacing it.
                if run.id.uuidString == self.effectiveHoveredRunID
                {
                    BarMark(
                        x: .value( "Run", run.id.uuidString ),
                        yStart: .value( "Low", extent.low ),
                        yEnd: .value( "High", extent.high ),
                        width: .fixed( Self.barWidth )
                    )
                    .foregroundStyle( Color.accentColor.opacity( 0.12 ) )
                }
            }
            .chartXScale( domain: domainValues )
            .chartXAxis( .hidden )
            .chartYAxis
            {
                AxisMarks
                { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel
                    {
                        if let amount = value.as( Double.self )
                        {
                            Text( Self.axisLabel( for: amount, currency: currency ) )
                        }
                    }
                }
            }
            .chartYScale( domain: yDomain )
            .chartOverlay
            { proxy in
                GeometryReader
                { geometry in
                    Rectangle()
                        .fill( Color.clear )
                        .contentShape( Rectangle() )
                        .onContinuousHover
                        { phase in
                            switch phase
                            {
                            case .active( let location ):
                                self.hoveredRunID = self.runID( at: location, proxy: proxy, geometry: geometry )
                                self.hoverLocation = location

                            case .ended:
                                self.hoveredRunID = nil
                                self.hoverLocation = nil
                            }
                        }
                        .gesture(
                            SpatialTapGesture()
                                .onEnded
                                { value in
                                    guard let tappedRunID = self.runID( at: value.location, proxy: proxy, geometry: geometry ),
                                          let tappedRun = self.runs.first( where: { $0.id.uuidString == tappedRunID } )
                                    else
                                    {
                                        return
                                    }
                                    self.selection = tappedRun
                                }
                        )
                        .overlay
                        {
                            if let hoveredRun = self.hoveredRun,
                               let hoverLocation = self.hoverLocation
                            {
                                Text( hoveredRun.runAt, format: Self.tooltipTimeFormat )
                                    .font( .caption2 )
                                    .padding( .horizontal, 6 )
                                    .padding( .vertical, 3 )
                                    .background( .thinMaterial, in: RoundedRectangle( cornerRadius: 4 ) )
                                    .allowsHitTesting( false )
                                    .position( x: hoverLocation.x, y: max( hoverLocation.y - 20, 12 ) )
                            }
                        }
                }
            }
        }
        .frame( height: 120 )
        .padding( .horizontal )
        .padding( .top, 8 )
    }

    /**
     * Resolves a point in the chart overlay's local coordinate space to the run whose bar
     * actually covers that point — both horizontally (within the bar's fixed-width column, not
     * just its nearest category) and vertically (within its low-high range) — so hovering blank
     * space inside the plot area (e.g. the padding added by `paddedDomainValues(...)`, or simply
     * above/below a bar) doesn't match anything.
     *
     * @param location Point in the overlay's local coordinate space (e.g. a hover or tap location).
     * @param proxy The chart's plotting proxy, used to map between plot-area-relative positions and plotted values.
     * @param geometry The overlay's geometry, used to find the plot area's origin within `location`'s coordinate space.
     * @return The matching run's ID, or nil if `location` doesn't land on a plotted bar.
     */
    private func runID( at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy ) -> String?
    {
        let origin      = geometry[ proxy.plotAreaFrame ].origin
        let relativeX   = location.x - origin.x
        let relativeY   = location.y - origin.y

        guard let category: String = proxy.value( atX: relativeX ),
              let run = self.runs.first( where: { $0.id.uuidString == category } ),
              let barCenterX = proxy.position( forX: category )
        else
        {
            return nil
        }

        let extent = Self.barExtent( for: run, yDomain: Self.yDomain( for: self.chartRuns, filters: self.filters ), filters: self.filters )
        guard let lowY = proxy.position( forY: extent.low ),
              let highY = proxy.position( forY: extent.high )
        else
        {
            return nil
        }

        let barMinX = barCenterX - Self.barWidth / 2
        let barMaxX = barCenterX + Self.barWidth / 2
        guard relativeX >= barMinX,
              relativeX <= barMaxX,
              relativeY >= min( lowY, highY ),
              relativeY <= max( lowY, highY )
        else
        {
            return nil
        }

        return category
    }
}

// MARK: - Sortable columns

// Table's sortable-column initializer doesn't resolve for Optional<String> keypaths, so the
// sortable columns sort by these non-optional keys instead, still displaying the real optional value.
private extension PriceSnapshot
{
    var outboundSummarySortKey: String { self.outboundSummary ?? "" }
    var inboundSummarySortKey: String { self.inboundSummary ?? "" }

    // Sorts by total minutes rather than the "<h>h<mm>" display string itself, since the
    // unpadded hour component (e.g. "10h30" vs. "2h05") doesn't compare correctly as text.
    var outboundDurationSortKey: Int
    {
        OneWayFilters.minutes( fromDuration: self.outboundDuration ) ?? 0
    }

    var carrierSortKey: String { self.carrier ?? "" }
    var departureTimeSortKey: String { self.departureTime ?? "" }
    var arrivalTimeSortKey: String { self.arrivalTime ?? "" }
    var departureDateSortKey: Date { self.departureDate ?? .distantPast }
    var inboundDepartureTimeSortKey: String { self.inboundDepartureTime ?? "" }
    var inboundDepartureDateSortKey: Date { self.inboundDepartureDate ?? .distantPast }

    // -1 rather than the 0 outboundDurationSortKey falls back to, so fares with no duration
    // sort apart from genuine same-day returns instead of being interleaved with them.
    var tripDurationSortKey: Int { self.tripDurationDays ?? -1 }
}

// MARK: - Run detail

private struct RunDetailView: View
{
    var run: SearchRun
    var filters: OneWayFilters?
    @State private var sortOrder = [ KeyPathComparator( \PriceSnapshot.amount ) ]

    @Environment( APIInspectorState.self ) private var inspectorState
    @Environment( \.openWindow ) private var openWindow

    var body: some View
    {
        VStack( spacing: 0 )
        {
            if let errorMessage = self.run.errorMessage
            {
                Text( errorMessage )
                    .font( .callout.monospaced() )
                    .foregroundStyle( .red )
                    .textSelection( .enabled )
                    .padding( 10 )
                    .frame( maxWidth: .infinity, alignment: .leading )
                    .background( .red.opacity( 0.08 ) )
            }

            if let partialFailureMessage = self.run.partialFailureMessage
            {
                Text( partialFailureMessage )
                    .font( .callout.monospaced() )
                    .foregroundStyle( .orange )
                    .textSelection( .enabled )
                    .padding( 10 )
                    .frame( maxWidth: .infinity, alignment: .leading )
                    .background( .orange.opacity( 0.08 ) )
            }

            self.itineraryTable
                .contextMenu
                {
                    Button( "Show API Requests" )
                    {
                        self.inspectorState.run       = self.run
                        self.inspectorState.scope     = .thisRun
                        self.inspectorState.selection = nil
                        self.openWindow( id: "rawJSON" )
                    }
                }
        }
        .onChange( of: self.run.id )
        {
            self.sortOrder = [ KeyPathComparator( \PriceSnapshot.amount ) ]
            self.syncInspectorWindow()
        }
        .onAppear
        {
            // Switching to a different search recreates this view entirely (its parent,
            // `SearchDetailView`, is `.id(search.id)`-keyed), so `onChange(of: self.run.id)`
            // above never fires for that transition — this is a brand new view's initial value,
            // not a change. `onAppear` catches that case too.
            self.syncInspectorWindow()
        }
    }

    /**
     * Keeps an already-open API inspector scoped to whatever run the table is now showing;
     * harmless if the window isn't open — it'll simply show this next time it is.
     */
    private func syncInspectorWindow()
    {
        if self.inspectorState.run != nil
        {
            self.inspectorState.run       = self.run
            self.inspectorState.selection = nil
        }
    }

    private var sortedItineraries: [ PriceSnapshot ]
    {
        self.run.fares( matching: self.filters ).sorted( using: self.sortOrder )
    }

    private var isOneWaySearch: Bool
    {
        self.run.savedSearch?.kind == .oneWay
    }

    @ViewBuilder     private var itineraryTable: some View
    {
        let itineraries = self.sortedItineraries

        if itineraries.isEmpty
        {
            let emptyState = RunHistoryView.emptyState( isFiltered: self.run.itineraries.isEmpty == false )

            ContentUnavailableView(
                emptyState.title,
                systemImage: self.run.itineraries.isEmpty ? "airplane.circle" : "line.3.horizontal.decrease.circle",
                description: Text( emptyState.description )
            )
            .frame( maxWidth: .infinity, maxHeight: .infinity )
        }
        else
        {
            Table( itineraries, sortOrder: self.$sortOrder )
            {
                TableColumn( "Price", value: \.amount )
                { snapshot in
                    Text( "\( Int( snapshot.amount )) \( snapshot.currency )" )
                        .fontWeight( .semibold )
                        .monospacedDigit()
                }
                .width( min: 70, ideal: 110 )

                if self.isOneWaySearch
                {
                    TableColumn( "Date", value: \.departureDateSortKey )
                    { ( snapshot: PriceSnapshot ) in
                        if let departureDate = snapshot.departureDate
                        {
                            Text( departureDate, format: .dateTime.day().month( .abbreviated ) )
                        }
                        else
                        {
                            Text( "—" )
                        }
                    }
                    .width( min: 55, ideal: 80 )
                    TableColumn( "Carrier", value: \.carrierSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.carrier ?? "—" ) }
                    TableColumn( "Flight n°", value: \.outboundSummarySortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.outboundSummary ?? "—" ) }
                    TableColumn( "Departure", value: \.departureTimeSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.departureTime ?? "—" ) }
                    .width( min: 55, ideal: 80 )
                    TableColumn( "Arrival", value: \.arrivalTimeSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.arrivalTime ?? "—" ) }
                    .width( min: 55, ideal: 80 )
                    TableColumn( "Duration", value: \.outboundDurationSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.outboundDuration ?? "—" ) }
                    .width( min: 60, ideal: 90 )
                    TableColumn( "Book" )
                    { ( snapshot: PriceSnapshot ) in
                        // Keyed by the row's identity so re-sorting the table carries each
                        // button's fetched links with its own fare rather than its position.
                        BookingLinkButton( snapshot: snapshot )
                            .id( snapshot.persistentModelID )
                    }
                    .width( min: 44, ideal: 52 )
                }
                else
                {
                    TableColumn( "Trip", value: \.tripDurationSortKey )
                    { ( snapshot: PriceSnapshot ) in
                        if let tripDurationDays = snapshot.tripDurationDays
                        {
                            Text( "\( tripDurationDays ) d" )
                                .monospacedDigit()
                        }
                        else
                        {
                            Text( "—" )
                        }
                    }
                    .width( min: 44, ideal: 60 )
                    TableColumn( "Outbound", value: \.outboundSummarySortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.outboundSummary ?? "—" ) }
                    TableColumn( "Outbound Date", value: \.departureDateSortKey )
                    { ( snapshot: PriceSnapshot ) in
                        if let departureDate = snapshot.departureDate
                        {
                            Text( departureDate, format: .dateTime.day().month( .abbreviated ) )
                        }
                        else
                        {
                            Text( "—" )
                        }
                    }
                    .width( min: 55, ideal: 80 )
                    TableColumn( "Outbound Time", value: \.departureTimeSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.departureTime ?? "—" ) }
                    .width( min: 55, ideal: 80 )
                    TableColumn( "Inbound", value: \.inboundSummarySortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.inboundSummary ?? "—" ) }
                    TableColumn( "Inbound Date", value: \.inboundDepartureDateSortKey )
                    { ( snapshot: PriceSnapshot ) in
                        if let inboundDepartureDate = snapshot.inboundDepartureDate
                        {
                            Text( inboundDepartureDate, format: .dateTime.day().month( .abbreviated ) )
                        }
                        else
                        {
                            Text( "—" )
                        }
                    }
                    .width( min: 55, ideal: 80 )
                    TableColumn( "Inbound Time", value: \.inboundDepartureTimeSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.inboundDepartureTime ?? "—" ) }
                    .width( min: 55, ideal: 80 )
                    TableColumn( "Book" )
                    { ( snapshot: PriceSnapshot ) in
                        // Keyed by the row's identity so re-sorting the table carries each
                        // button's fetched links with its own fare rather than its position.
                        BookingLinkButton( snapshot: snapshot )
                            .id( snapshot.persistentModelID )
                    }
                    .width( min: 44, ideal: 52 )
                }
            }
            .tableStyle( .inset( alternatesRowBackgrounds: true ) )
        }
    }
}
