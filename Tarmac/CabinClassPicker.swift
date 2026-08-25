/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftUI

struct CabinClassPicker: View
{
    @Binding var selection: String

    var body: some View
    {
        Picker( "Cabin", selection: $selection )
        {
            Text( "Economy" ).tag( "economy" )
            Text( "Premium" ).tag( "premium_economy" )
            Text( "Business" ).tag( "business" )
            Text( "First" ).tag( "first" )
        }
    }
}
