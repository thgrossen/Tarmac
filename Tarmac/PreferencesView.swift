/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftUI

struct PreferencesView: View
{
    @AppStorage( SearchViewModel.apiKeyDefaultsKey ) private var apiKey = ""
    @AppStorage( AirlinePreference.restrictAirlinesDefaultsKey ) private var restrictAirlines = true
    @AppStorage( AirlinePreference.airlineCodesDefaultsKey ) private var airlineCodes = AirlinePreference.defaultAirlineCodes

    var body: some View
    {
        Form
        {
            Section( "API Key" )
            {
                SecureField( "X-Api-Key", text: $apiKey )
                    .textFieldStyle( .roundedBorder )
                    .autocorrectionDisabled()
            }

            Section( "Airlines" )
            {
                Toggle( "Restrict to specific carriers", isOn: $restrictAirlines )
                TextField( "IATA codes (comma-separated)", text: $airlineCodes )
                    .textFieldStyle( .roundedBorder )
                    .autocorrectionDisabled()
                    .disabled( self.restrictAirlines == false )
            }
        }
        .formStyle( .grouped )
        .frame( width: 420 )
    }
}
