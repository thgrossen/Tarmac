/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftData
import SwiftUI

struct RoundTripSearchForm: View
{
    @Environment( \.modelContext ) private var modelContext
    @Environment( \.dismiss ) private var dismiss
    var onCreate: ( SavedSearch ) -> Void

    @State private var origin = ""
    @State private var destination = ""
    @State private var rangeStart = Date().addingTimeInterval( 60 * 86_400 )
    @State private var rangeEnd = Date().addingTimeInterval( 67 * 86_400 )
    @State private var tripDurationDays = 3
    @State private var flexibilityDays = 0
    @State private var mustIncludeWeekend = false
    @State private var cabinClass = "business"
    @State private var directOnly = true
    @State private var luggageIncluded = false

    private var isValid: Bool
    {
        IATACode.isValid( self.origin ) && IATACode.isValid( self.destination )
    }

    var body: some View
    {
        VStack( spacing: 0 )
        {
            Form
            {
                Section( "Trip" )
                {
                    TextField( "Origin (IATA)", text: $origin )
                    TextField( "Destination (IATA)", text: $destination )
                    DatePicker( "Earliest departure", selection: $rangeStart, displayedComponents: .date )
                    DatePicker( "Latest departure", selection: $rangeEnd, in: rangeStart..., displayedComponents: .date )

                    Stepper(
                        "Trip duration: \( tripDurationDays ) night\( tripDurationDays == 1 ? "" : "s" )",
                        value: $tripDurationDays,
                        in: 1 ... 30
                    )
                    Stepper(
                        "Flexibility: ±\( flexibilityDays ) day\( flexibilityDays == 1 ? "" : "s" )",
                        value: $flexibilityDays,
                        in: 0 ... 14
                    )
                    Toggle( "Must include a weekend", isOn: $mustIncludeWeekend )

                    CabinClassPicker( selection: $cabinClass )
                    Toggle( "Direct flights only", isOn: $directOnly )
                    Toggle( "Luggage included", isOn: $luggageIncluded )
                }
            }
            .formStyle( .grouped )
            .autocorrectionDisabled()

            Divider()

            HStack
            {
                Spacer()
                Button( "Save" )
                {
                    self.save()
                }
                .keyboardShortcut( .defaultAction )
                .disabled( self.isValid == false )
            }
            .padding()
        }
    }

    private func save()
    {
        let search = SavedSearch(
            kind: .roundTrip,
            origin: self.origin.uppercased(),
            destination: self.destination.uppercased(),
            rangeStart: self.rangeStart,
            rangeEnd: self.rangeEnd,
            cabinClass: self.cabinClass,
            directOnly: self.directOnly,
            luggageIncluded: self.luggageIncluded,
            tripDurationDays: self.tripDurationDays,
            flexibilityDays: self.flexibilityDays,
            mustIncludeWeekend: self.mustIncludeWeekend
        )
        self.modelContext.insert( search )
        self.onCreate( search )
        self.dismiss()
    }
}
