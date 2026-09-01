/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftUI

struct NewSearchSheet: View
{
    @Environment( \.dismiss ) private var dismiss
    var kind: SearchKind
    var onCreate: ( SavedSearch ) -> Void

    var body: some View
    {
        VStack( spacing: 0 )
        {
            HStack
            {
                Spacer()

                Button( "Cancel" )
                {
                    self.dismiss()
                }
            }
            .padding()

            Divider()

            switch self.kind
            {
                case .oneWay:
                    OneWaySearchForm( onCreate: self.onCreate )

                case .roundTrip:
                    RoundTripSearchForm( onCreate: self.onCreate )
            }
        }
        .frame( width: 420, height: 480 )
    }
}
