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
            Section( "Clé API" )
            {
                SecureField( "X-Api-Key", text: $vm.apiKey )
                    .autocorrectionDisabled()
            }

            Section( "Trajet" )
            {
                TextField( "Origine (IATA)", text: $vm.origin )
                TextField( "Destination (IATA)", text: $vm.destination )
                DatePicker( "Aller", selection: $vm.departure, displayedComponents: .date )
                DatePicker( "Retour", selection: $vm.returnDate, displayedComponents: .date )

                Picker( "Cabine", selection: $vm.cabin )
                {
                    Text( "Economy" ).tag( "economy" )
                    Text( "Premium" ).tag( "premium_economy" )
                    Text( "Business" ).tag( "business" )
                    Text( "First" ).tag( "first" )
                }
                Toggle( "Vols directs uniquement", isOn: $vm.directOnly )
                Toggle( "Swiss + TAP seulement", isOn: $vm.onlyLXTP )
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
                        Text( vm.isLoading ? "Recherche…" : "Chercher" )
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

// MARK: - Détail

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
                Text( "Itinéraires (\( vm.itineraries.count ))" ).tag( 0 )
                Text( "JSON brut" ).tag( 1 )
            }
            .pickerStyle( .segmented )
            .labelsHidden()
            .padding( 8 )

            Divider()

            if tab == 0
            {
                Table( vm.itineraries )
                {
                    TableColumn( "Prix" )
                    { itin in
                        Text( "\( Int( itin.price.amount )) \( itin.price.currency )" )
                            .fontWeight( .semibold )
                            .monospacedDigit()
                    }
                    .width( 110 )

                    TableColumn( "Aller" ) { Text( flights( $0.outbound )) }
                    TableColumn( "Retour" ) { Text( flights( $0.inbound )) }
                    TableColumn( "Durée A" ) { Text( $0.outbound?.duration ?? "—" ) }.width( 90 )
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
                    Text( vm.rawJSON.isEmpty ? "Aucune réponse pour l'instant." : vm.rawJSON )
                        .font( .system( size: 11, design: .monospaced ))
                        .textSelection( .enabled )
                        .padding( 10 )
                        .frame( maxWidth: .infinity, alignment: .leading )
                }
                .overlay( alignment: .topTrailing )
                {
                    if !vm.rawJSON.isEmpty
                    {
                        Button( "Copier", systemImage: "doc.on.doc" ) { vm.copyJSON() }
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
