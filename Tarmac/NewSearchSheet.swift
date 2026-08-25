/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftUI

struct NewSearchSheet: View
{
    @Environment( \.dismiss ) private var dismiss
    @State private var chosenKind: SearchKind?
    var onCreate: ( SavedSearch ) -> Void

    var body: some View
    {
        VStack( spacing: 0 )
        {
            HStack
            {
                if self.chosenKind != nil
                {
                    Button( "Back" )
                    {
                        self.chosenKind = nil
                    }
                }

                Spacer()

                Button( "Cancel" )
                {
                    self.dismiss()
                }
            }
            .padding()

            Divider()

            switch self.chosenKind
            {
                case .oneWay:
                    OneWaySearchForm( onCreate: self.onCreate )

                case .roundTrip:
                    RoundTripSearchForm( onCreate: self.onCreate )

                case nil:
                    NewSearchKindChooser
                    {
                        self.chosenKind = $0
                    }
            }
        }
        .frame( width: 420, height: 480 )
    }
}

private struct NewSearchKindChooser: View
{
    var onChoose: ( SearchKind ) -> Void

    var body: some View
    {
        VStack( spacing: 16 )
        {
            Text( "New Search" )
                .font( .title2 )
                .fontWeight( .semibold )
            Text( "What kind of trip are you looking for?" )
                .foregroundStyle( .secondary )

            HStack( spacing: 12 )
            {
                Button( "One-way" )
                {
                    self.onChoose( .oneWay )
                }
                .buttonStyle( .bordered )
                .controlSize( .large )

                Button( "Round Trip" )
                {
                    self.onChoose( .roundTrip )
                }
                .buttonStyle( .bordered )
                .controlSize( .large )
            }
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .padding()
    }
}
