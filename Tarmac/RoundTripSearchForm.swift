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
    @Environment( SearchDateSession.self ) private var dateSession
    @Query( sort: \SavedSearch.createdAt, order: .reverse ) private var recentSearches: [ SavedSearch ]
    var onCreate: ( SavedSearch ) -> Void

    @State private var origin = ""
    @State private var destination = ""
    @State private var rangeStart = DepartureDateDefaults.defaultRange().start
    @State private var rangeEnd = DepartureDateDefaults.defaultRange().end
    @State private var tripDurationDays = SearchPrefill.defaultTripDurationDays
    @State private var flexibilityDays = SearchPrefill.defaultFlexibilityDays
    @State private var mustIncludeWeekend = SearchPrefill.defaultMustIncludeWeekend
    @State private var cabinClass = SearchPrefill.defaultCabinClass
    @State private var directOnly = SearchPrefill.defaultDirectOnly
    @State private var luggageIncluded = SearchPrefill.defaultLuggageIncluded
    @State private var passengers = SearchPrefill.defaultPassengers

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
                Section( "Trip" )
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
            .autocorrectionDisabled()
            .onAppear
            {
                self.prefillFromMostRecentSearch()
                self.prefillDates()
            }

            Divider()

            HStack
            {
                Spacer()
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

    private func prefillFromMostRecentSearch()
    {
        let shared = SearchPrefill.sharedFields( from: SearchPrefill.mostRecentReal( in: self.recentSearches ) )
        self.origin = shared.origin
        self.destination = shared.destination
        self.cabinClass = shared.cabinClass
        self.directOnly = shared.directOnly
        self.luggageIncluded = shared.luggageIncluded
        self.passengers = shared.passengers

        let mostRecentRoundTrip = SearchPrefill.mostRecentRoundTrip( in: self.recentSearches )
        let roundTrip = SearchPrefill.roundTripFields( from: mostRecentRoundTrip )
        self.tripDurationDays = roundTrip.tripDurationDays
        self.flexibilityDays = roundTrip.flexibilityDays
        self.mustIncludeWeekend = roundTrip.mustIncludeWeekend
    }

    private func prefillDates()
    {
        let range: SearchDateSession.DateRange
        if let stored = self.dateSession.range( for: .roundTrip )
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
            kind: .roundTrip,
            origin: self.origin.uppercased(),
            destination: self.destination.uppercased(),
            rangeStart: self.rangeStart,
            rangeEnd: self.rangeEnd,
            cabinClass: self.cabinClass,
            directOnly: self.directOnly,
            luggageIncluded: self.luggageIncluded,
            passengers: self.passengers,
            tripDurationDays: self.tripDurationDays,
            flexibilityDays: self.flexibilityDays,
            mustIncludeWeekend: self.mustIncludeWeekend
        )
        self.modelContext.insert( search )
        self.dateSession.recordRange( SearchDateSession.DateRange( start: self.rangeStart, end: self.rangeEnd ), for: .roundTrip )
        self.onCreate( search )
        self.dismiss()
    }
}
