/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftUI

struct RunHistoryView: View
{
    var runs: [ SearchRun ]     // newest first
    @Binding var selection: SearchRun?
    @Binding var isFollowingLatest: Bool

    var body: some View
    {
        VStack( spacing: 0 )
        {
            RunPicker( runs: self.runs, selection: self.$selection, isFollowingLatest: self.$isFollowingLatest )

            Divider()

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

// MARK: - Run picker

private struct RunPicker: View
{
    var runs: [ SearchRun ]     // newest first
    @Binding var selection: SearchRun?
    @Binding var isFollowingLatest: Bool

    var body: some View
    {
        ScrollView( .horizontal, showsIndicators: false )
        {
            HStack( spacing: 8 )
            {
                ForEach( self.runs.pairedWithPrevious(), id: \.run.id )
                { pair in
                    RunChip( run: pair.run, previousRun: pair.previous, isSelected: pair.run.id == self.selection?.id )
                        .onTapGesture
                        {
                            self.selection = pair.run
                            self.isFollowingLatest = false
                        }
                }
            }
            .padding( .horizontal )
            .padding( .vertical, 8 )
        }
    }
}

private struct RunChip: View
{
    var run: SearchRun
    var previousRun: SearchRun?
    var isSelected: Bool

    private static let timeFormat = Date.FormatStyle().month( .abbreviated ).day().hour().minute()

    var body: some View
    {
        VStack( alignment: .leading, spacing: 2 )
        {
            Text( self.run.runAt, format: Self.timeFormat )
                .font( .caption2 )
                .foregroundStyle( .secondary )

            if let cheapest = self.run.cheapestFare
            {
                Text( "\( Int( cheapest.amount )) \( cheapest.currency )" )
                    .font( .callout.monospacedDigit() )
                    .fontWeight( .semibold )
            }
            else
            {
                Text( self.run.errorMessage != nil ? "Error" : "No fares" )
                    .font( .callout )
                    .foregroundStyle( .secondary )
            }

            if let delta = self.run.priceDelta( previous: self.previousRun ), Int( delta ) != 0
            {
                HStack( spacing: 2 )
                {
                    Image( systemName: delta < 0 ? "arrow.down" : "arrow.up" )
                    Text( "\( Int( abs( delta )) )" )
                }
                .font( .caption2 )
                .foregroundStyle( delta < 0 ? .green : .red )
            }
        }
        .padding( 8 )
        .frame( minWidth: 90, alignment: .leading )
        .background( self.isSelected ? Color.accentColor.opacity( 0.15 ) : Color.clear )
        .clipShape( RoundedRectangle( cornerRadius: 8 ) )
        .overlay
        {
            RoundedRectangle( cornerRadius: 8 )
                .stroke( self.isSelected ? Color.accentColor : Color.secondary.opacity( 0.25 ) )
        }
        .contentShape( Rectangle() )
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
    var ignavIDSortKey: String { self.ignavID ?? "" }
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
                TableColumn( "ignav_id", value: \.ignavIDSortKey )
                { snapshot in
                    Text( snapshot.ignavID ?? "—" ).font( .caption.monospaced() )
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
