/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Charts
import SwiftUI

struct RunHistoryView: View
{
    var runs: [ SearchRun ]     // newest first
    @Binding var selection: SearchRun?

    var body: some View
    {
        VStack( spacing: 0 )
        {
            if PriceHistoryChart.chartRuns( for: self.runs ).count > 1
            {
                PriceHistoryChart( runs: self.runs, selection: self.$selection )

                Divider()
            }

            if let selectedRun = self.selection
            {
                RunDetailView( run: selectedRun )
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
     * @return The padded domain, or 0...1 if there is nothing to plot.
     */
    static func yDomain( for runs: [ SearchRun ] ) -> ClosedRange< Double >
    {
        let lows  = runs.compactMap { $0.cheapestFare?.amount }
        let highs = runs.compactMap { $0.maxFare?.amount }
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
     * for a run with no fares (an error, or none found), a thin flat marker sitting at the
     * bottom of the y-axis domain — keeping it visible and selectable without implying a price.
     *
     * @param run The run to compute a bar extent for.
     * @param yDomain The chart's y-axis domain (see `yDomain(for:)`).
     * @return The bar's low and high values, in the same units as `yDomain`.
     */
    static func barExtent( for run: SearchRun, yDomain: ClosedRange< Double > ) -> ( low: Double, high: Double )
    {
        if let low = run.cheapestFare?.amount,
           let high = run.maxFare?.amount
        {
            return ( low, high )
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
            let yDomain = Self.yDomain( for: chartRuns )
            let domainValues = Self.paddedDomainValues(
                chartRuns: chartRuns,
                availableWidth: outerGeometry.size.width,
                slotWidth: Self.barSlotWidth
            )

            Chart( chartRuns, id: \.id )
            { run in
                let extent = Self.barExtent( for: run, yDomain: yDomain )
                let hasFare = run.cheapestFare != nil

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

        let extent = Self.barExtent( for: run, yDomain: Self.yDomain( for: self.chartRuns ) )
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
        guard let duration = self.outboundDuration,
              let hourIndex = duration.firstIndex( of: "h" ),
              let hours = Int( duration[ duration.startIndex ..< hourIndex ] ),
              let minutes = Int( duration[ duration.index( after: hourIndex )... ] )
        else
        {
            return 0
        }
        return hours * 60 + minutes
    }

    var carrierSortKey: String { self.carrier ?? "" }
    var departureTimeSortKey: String { self.departureTime ?? "" }
    var arrivalTimeSortKey: String { self.arrivalTime ?? "" }
    var departureDateSortKey: Date { self.departureDate ?? .distantPast }
}

// MARK: - Run detail

private struct RunDetailView: View
{
    var run: SearchRun
    @State private var tab = 0
    @State private var sortOrder = [ KeyPathComparator( \PriceSnapshot.amount ) ]

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

            Picker( "", selection: self.$tab )
            {
                Text( "Itineraries (\( self.run.itineraries.count ))" ).tag( 0 )
                Text( "Raw JSON" ).tag( 1 )
            }
            .pickerStyle( .segmented )
            .labelsHidden()
            .padding( 8 )

            Divider()

            if self.tab == 0
            {
                self.itineraryTable
            }
            else
            {
                self.rawJSONView
            }
        }
        .onChange( of: self.run.id )
        {
            self.sortOrder = [ KeyPathComparator( \PriceSnapshot.amount ) ]
        }
    }

    private var sortedItineraries: [ PriceSnapshot ]
    {
        self.run.itineraries.sorted( using: self.sortOrder )
    }

    private var isOneWaySearch: Bool
    {
        self.run.savedSearch?.kind == .oneWay
    }

    @ViewBuilder     private var itineraryTable: some View
    {
        if self.run.itineraries.isEmpty
        {
            ContentUnavailableView(
                "No fares found",
                systemImage: "airplane.circle",
                description: Text( "This run returned no itineraries." )
            )
            .frame( maxWidth: .infinity, maxHeight: .infinity )
        }
        else
        {
            Table( self.sortedItineraries, sortOrder: self.$sortOrder )
            {
                TableColumn( "Price", value: \.amount )
                { snapshot in
                    Text( "\( Int( snapshot.amount )) \( snapshot.currency )" )
                        .fontWeight( .semibold )
                        .monospacedDigit()
                }
                .width( 110 )

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
                    .width( 80 )
                    TableColumn( "Carrier", value: \.carrierSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.carrier ?? "—" ) }
                    TableColumn( "Flight n°", value: \.outboundSummarySortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.outboundSummary ?? "—" ) }
                    TableColumn( "Departure", value: \.departureTimeSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.departureTime ?? "—" ) }
                    .width( 80 )
                    TableColumn( "Arrival", value: \.arrivalTimeSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.arrivalTime ?? "—" ) }
                    .width( 80 )
                    TableColumn( "Duration", value: \.outboundDurationSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.outboundDuration ?? "—" ) }
                    .width( 90 )
                }
                else
                {
                    TableColumn( "Outbound", value: \.outboundSummarySortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.outboundSummary ?? "—" ) }
                    TableColumn( "Inbound", value: \.inboundSummarySortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.inboundSummary ?? "—" ) }
                    TableColumn( "Duration", value: \.outboundDurationSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.outboundDuration ?? "—" ) }
                    .width( 90 )
                    TableColumn( "Carrier", value: \.carrierSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.carrier ?? "—" ) }
                    TableColumn( "Departure", value: \.departureTimeSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.departureTime ?? "—" ) }
                    .width( 80 )
                    TableColumn( "Arrival", value: \.arrivalTimeSortKey )
                    { ( snapshot: PriceSnapshot ) in Text( snapshot.arrivalTime ?? "—" ) }
                    .width( 80 )
                }
            }
            .tableStyle( .inset( alternatesRowBackgrounds: true ) )
        }
    }

    private var rawJSONView: some View
    {
        ScrollView( [ .vertical, .horizontal ] )
        {
            Text( self.run.rawJSON?.isEmpty == false ? self.run.rawJSON! : "No response for this run." )
                .font( .system( size: 11, design: .monospaced ) )
                .textSelection( .enabled )
                .padding( 10 )
                .frame( maxWidth: .infinity, alignment: .leading )
        }
        .overlay( alignment: .topTrailing )
        {
            if let rawJSON = self.run.rawJSON, rawJSON.isEmpty == false
            {
                Button( "Copy", systemImage: "doc.on.doc" )
                {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString( rawJSON, forType: .string )
                }
                .padding( 10 )
            }
        }
    }
}
