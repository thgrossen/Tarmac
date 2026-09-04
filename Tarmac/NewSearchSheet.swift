/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftData
import SwiftUI

struct NewSearchSheet: View
{
    @Query( sort: \SavedSearch.createdAt, order: .reverse ) private var recentSearches: [ SavedSearch ]
    @State private var kind: SearchKind = .oneWay
    var onCreate: ( SavedSearch ) -> Void

    // Fields shared between both search kinds, lifted up here (rather than owned locally by
    // each form) so switching the kind picker doesn't discard what the user already entered —
    // `OneWaySearchForm`/`RoundTripSearchForm` are different concrete types, so SwiftUI tears
    // down and recreates whichever one loses focus, along with any of its own local `@State`.
    @State private var origin = ""
    @State private var destination = ""
    @State private var cabinClass = SearchPrefill.defaultCabinClass
    @State private var directOnly = SearchPrefill.defaultDirectOnly
    @State private var carryOnIncluded = SearchPrefill.defaultCarryOnIncluded
    @State private var checkedBagIncluded = SearchPrefill.defaultCheckedBagIncluded
    @State private var passengers = SearchPrefill.defaultPassengers

    var body: some View
    {
        VStack( spacing: 0 )
        {
            Picker( "", selection: self.$kind )
            {
                Text( "One-way" ).tag( SearchKind.oneWay )
                Text( "Round trip" ).tag( SearchKind.roundTrip )
            }
            .pickerStyle( .segmented )
            .labelsHidden()
            .padding( [ .horizontal, .top ] )

            switch self.kind
            {
                case .oneWay:
                    OneWaySearchForm(
                        origin: $origin,
                        destination: $destination,
                        cabinClass: $cabinClass,
                        directOnly: $directOnly,
                        carryOnIncluded: $carryOnIncluded,
                        checkedBagIncluded: $checkedBagIncluded,
                        passengers: $passengers,
                        onCreate: self.onCreate
                    )

                case .roundTrip:
                    RoundTripSearchForm(
                        origin: $origin,
                        destination: $destination,
                        cabinClass: $cabinClass,
                        directOnly: $directOnly,
                        carryOnIncluded: $carryOnIncluded,
                        checkedBagIncluded: $checkedBagIncluded,
                        passengers: $passengers,
                        onCreate: self.onCreate
                    )
            }
        }
        // Fixed regardless of which kind is selected, so switching doesn't resize the window —
        // sized for the taller Round form, leaving One-way empty space above its buttons.
        .frame( width: 420, height: 620 )
        .onAppear
        {
            let fields = SearchPrefill.sharedFields( from: SearchPrefill.mostRecentReal( in: self.recentSearches ) )
            self.origin = fields.origin
            self.destination = fields.destination
            self.cabinClass = fields.cabinClass
            self.directOnly = fields.directOnly
            self.carryOnIncluded = fields.carryOnIncluded
            self.checkedBagIncluded = fields.checkedBagIncluded
            self.passengers = fields.passengers
        }
    }
}
