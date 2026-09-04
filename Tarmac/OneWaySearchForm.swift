/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftData
import SwiftUI

struct OneWaySearchForm: View
{
    @Environment( \.modelContext ) private var modelContext
    @Environment( \.dismiss ) private var dismiss
    @Environment( SearchDateSession.self ) private var dateSession

    // Owned by the enclosing `NewSearchSheet` and shared with `RoundTripSearchForm`, so
    // switching kinds doesn't lose what the user already entered in these fields.
    @Binding var origin: String
    @Binding var destination: String
    @Binding var cabinClass: String
    @Binding var directOnly: Bool
    @Binding var carryOnIncluded: Bool
    @Binding var checkedBagIncluded: Bool
    @Binding var passengers: Int
    var onCreate: ( SavedSearch ) -> Void

    @State private var rangeStart = DepartureDateDefaults.defaultRange().start
    @State private var rangeEnd = DepartureDateDefaults.defaultRange().end

    private var isValid: Bool
    {
        IATACode.isValid( self.origin ) && IATACode.isValid( self.destination )
    }

    private var earliestSelectableDate: Date
    {
        DepartureDateDefaults.earliestDeparture()
    }

    var body: some View
    {
        VStack( spacing: 0 )
        {
            Form
            {
                Section
                {
                    TextField( "Origin (IATA)", text: $origin )
                    HStack
                    {
                        Text( "Destination (IATA)" )
                        Button
                        {
                            self.swapOriginAndDestination()
                        } label: {
                            Label( "Swap origin and destination", systemImage: "arrow.left.arrow.right" )
                        }
                        .labelStyle( .iconOnly )
                        .buttonStyle( .borderless )
                        .help( "Swap origin and destination" )
                        .disabled( FieldSwap.isEnabled( origin: self.origin, destination: self.destination ) == false )
                        Spacer()
                        TextField( "", text: $destination )
                            .multilineTextAlignment( .trailing )
                    }
                    DatePicker( "Earliest departure", selection: $rangeStart, in: self.earliestSelectableDate..., displayedComponents: .date )
                    DatePicker( "Latest departure", selection: $rangeEnd, in: rangeStart..., displayedComponents: .date )

                    CabinClassPicker( selection: $cabinClass )
                    Toggle( "Direct flights only", isOn: $directOnly )
                    Toggle( "Carry-on included", isOn: $carryOnIncluded )
                    Toggle( "Checked bag included", isOn: $checkedBagIncluded )
                    Picker( "Passengers", selection: $passengers )
                    {
                        ForEach( 1 ... 12, id: \.self )
                        { count in
                            Text( "\( count )" ).tag( count )
                        }
                    }
                }
            }
            .formStyle( .grouped )
            .scrollDisabled( true )
            .autocorrectionDisabled()
            .onAppear
            {
                self.prefillDates()
            }

            HStack
            {
                Spacer()

                Button( "Cancel", role: .cancel )
                {
                    self.dismiss()
                }
                .keyboardShortcut( .cancelAction )

                Button( "Search" )
                {
                    self.save()
                }
                .keyboardShortcut( .defaultAction )
                .disabled( self.isValid == false )
            }
            .padding()
        }
    }

    private func swapOriginAndDestination()
    {
        let result = FieldSwap.swapped( origin: self.origin, destination: self.destination )
        self.origin = result.origin
        self.destination = result.destination
    }

    private func prefillDates()
    {
        let range: SearchDateSession.DateRange
        if let stored = self.dateSession.range( for: .oneWay )
        {
            range = DepartureDateDefaults.clamped( stored )
        }
        else
        {
            range = DepartureDateDefaults.defaultRange()
        }
        self.rangeStart = range.start
        self.rangeEnd = range.end
    }

    private func save()
    {
        let search = SavedSearch(
            kind: .oneWay,
            origin: self.origin.uppercased(),
            destination: self.destination.uppercased(),
            rangeStart: self.rangeStart,
            rangeEnd: self.rangeEnd,
            cabinClass: self.cabinClass,
            directOnly: self.directOnly,
            carryOnIncluded: self.carryOnIncluded,
            checkedBagIncluded: self.checkedBagIncluded,
            passengers: self.passengers
        )
        self.modelContext.insert( search )
        self.dateSession.recordRange( SearchDateSession.DateRange( start: self.rangeStart, end: self.rangeEnd ), for: .oneWay )
        self.onCreate( search )
        self.dismiss()
    }
}
