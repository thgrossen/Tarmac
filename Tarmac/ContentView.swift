/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftUI

struct ContentView: View
{
    @State private var vm = SearchViewModel()

    var body: some View
    {
        NavigationSplitView
        {
            SearchForm( vm: vm )
                .navigationSplitViewColumnWidth( min: 300, ideal: 320, max: 380 )
        } detail: {
            ResultsPane( vm: vm )
        }
        .navigationTitle( "Ignav — GVA ↔ LIS" )
    }
}

// MARK: - Sidebar

struct SearchForm: View
{
    @Bindable var vm: SearchViewModel

    var body: some View
    {
        Form
        {
            Section( "Trip" )
            {
                TextField( "Origin (IATA)", text: $vm.origin )
                TextField( "Destination (IATA)", text: $vm.destination )
                DatePicker( "Departure", selection: $vm.departure, displayedComponents: .date )
                DatePicker( "Return", selection: $vm.returnDate, displayedComponents: .date )

                Picker( "Cabin", selection: $vm.cabin )
                {
                    Text( "Economy" ).tag( "economy" )
                    Text( "Premium" ).tag( "premium_economy" )
                    Text( "Business" ).tag( "business" )
                    Text( "First" ).tag( "first" )
                }
                Toggle( "Direct flights only", isOn: $vm.directOnly )
            }

            Section
            {
                Button
                {
                    Task { await vm.search() }
                } label: {
                    HStack
                    {
                        if vm.isLoading { ProgressView().controlSize( .small ) }
                        Text( vm.isLoading ? "Searching…" : "Search" )
                    }
                    .frame( maxWidth: .infinity )
                }
                .keyboardShortcut( .return, modifiers: .command )
                .disabled( vm.isLoading )
            }
        }
        .formStyle( .grouped )
        .autocorrectionDisabled()
    }
}

// MARK: - Detail

struct ResultsPane: View
{
    var vm: SearchViewModel
    @State private var tab = 0

    var body: some View
    {
        VStack( spacing: 0 )
        {
            if let err = vm.errorMessage
            {
                Text( err )
                    .font( .callout.monospaced())
                    .foregroundStyle( .red )
                    .textSelection( .enabled )
                    .padding( 10 )
                    .frame( maxWidth: .infinity, alignment: .leading )
                    .background( .red.opacity( 0.08 ))
            }

            Picker( "", selection: $tab )
            {
                Text( "Itineraries (\( vm.itineraries.count ))" ).tag( 0 )
                Text( "Raw JSON" ).tag( 1 )
            }
            .pickerStyle( .segmented )
            .labelsHidden()
            .padding( 8 )

            Divider()

            if tab == 0
            {
                Table( vm.itineraries )
                {
                    TableColumn( "Price" )
                    { itin in
                        Text( "\( Int( itin.price.amount )) \( itin.price.currency )" )
                            .fontWeight( .semibold )
                            .monospacedDigit()
                    }
                    .width( 110 )

                    TableColumn( "Outbound" ) { Text( flights( $0.outbound )) }
                    TableColumn( "Return" ) { Text( flights( $0.inbound )) }
                    TableColumn( "Duration" ) { Text( $0.outbound?.duration ?? "—" ) }.width( 90 )
                    TableColumn( "ignav_id" )
                    { itin in
                        Text( itin.ignav_id ?? "—" ).font( .caption.monospaced())
                    }
                }
                .tableStyle( .inset( alternatesRowBackgrounds: true ))
            }
            else
            {
                ScrollView( [ .vertical, .horizontal ] )
                {
                    Text( vm.rawJSON.isEmpty ? "No response yet." : vm.rawJSON )
                        .font( .system( size: 11, design: .monospaced ))
                        .textSelection( .enabled )
                        .padding( 10 )
                        .frame( maxWidth: .infinity, alignment: .leading )
                }
                .overlay( alignment: .topTrailing )
                {
                    if !vm.rawJSON.isEmpty
                    {
                        Button( "Copy", systemImage: "doc.on.doc" ) { vm.copyJSON() }
                            .padding( 10 )
                    }
                }
            }
        }
        .frame( minWidth: 620, minHeight: 420 )
    }

    private func flights( _ leg: Leg? ) -> String
    {
        guard let segs = leg?.segments, !segs.isEmpty else { return "—" }
        return segs.map { "\( $0.carrier_code ?? "" )\( $0.flight_number ?? "" )" }
            .joined( separator: " → " )
    }
}
