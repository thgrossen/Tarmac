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
    @Query( sort: \SavedSearch.createdAt, order: .reverse ) private var recentSearches: [ SavedSearch ]
    var onCreate: ( SavedSearch ) -> Void

    @State private var origin = ""
    @State private var destination = ""
    @State private var rangeStart = DepartureDateDefaults.defaultRange().start
    @State private var rangeEnd = DepartureDateDefaults.defaultRange().end
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
        let fields = SearchPrefill.sharedFields( from: SearchPrefill.mostRecentReal( in: self.recentSearches ) )
        self.origin = fields.origin
        self.destination = fields.destination
        self.cabinClass = fields.cabinClass
        self.directOnly = fields.directOnly
        self.luggageIncluded = fields.luggageIncluded
        self.passengers = fields.passengers
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
            luggageIncluded: self.luggageIncluded,
            passengers: self.passengers
        )
        self.modelContext.insert( search )
        self.dateSession.recordRange( SearchDateSession.DateRange( start: self.rangeStart, end: self.rangeEnd ), for: .oneWay )
        self.onCreate( search )
        self.dismiss()
    }
}
