/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import AppKit
import SwiftUI

struct PreferencesView: View
{
    var body: some View
    {
        TabView
        {
            APIKeyPane()
                .tabItem { Label( "API Key", systemImage: "key" ) }

            MarketPane()
                .tabItem { Label( "Market", systemImage: "globe" ) }

            AirlinesPane()
                .tabItem { Label( "Airlines", systemImage: "airplane" ) }

            FiltersPane()
                .tabItem { Label( "Filters", systemImage: "line.3.horizontal.decrease.circle" ) }

            LimitsPane()
                .tabItem { Label( "Limits", systemImage: "gauge" ) }
        }
        .frame( width: 420 )
        .background
        {
            // TabView/Settings doesn't forward Escape to close the window on its own.
            // `@Environment(\.dismiss)` isn't documented to affect a Settings scene's
            // window (it's scoped to sheets/NavigationStack/openWindow-opened windows),
            // so this closes the key window directly instead, via a hidden button with
            // the cancel-action shortcut, which doesn't affect layout.
            Button( "Close" ) { NSApplication.shared.keyWindow?.close() }
                .keyboardShortcut( .cancelAction )
                .hidden()
        }
    }
}

private struct APIKeyPane: View
{
    @AppStorage( SearchViewModel.apiKeyDefaultsKey ) private var apiKey = ""

    var body: some View
    {
        Form
        {
            Section
            {
                SecureField( "X-Api-Key", text: $apiKey )
                    .textFieldStyle( .roundedBorder )
                    .autocorrectionDisabled()
            }
        }
        .formStyle( .grouped )
    }
}

private struct MarketPane: View
{
    @AppStorage( MarketPreference.marketDefaultsKey ) private var market = MarketPreference.defaultMarket

    var body: some View
    {
        Form
        {
            Section
            {
                Picker( "Market", selection: $market )
                {
                    ForEach( MarketPreference.allMarkets, id: \.self )
                    { code in
                        Text( code ).tag( code )
                    }
                }
            }
        }
        .formStyle( .grouped )
    }
}

private struct AirlinesPane: View
{
    @AppStorage( AirlinePreference.restrictAirlinesDefaultsKey ) private var restrictAirlines = true
    @AppStorage( AirlinePreference.airlineCodesDefaultsKey ) private var airlineCodes = AirlinePreference.defaultAirlineCodes

    var body: some View
    {
        Form
        {
            Section
            {
                Toggle( "Restrict to specific carriers", isOn: $restrictAirlines )
                TextField( "IATA codes (comma-separated)", text: $airlineCodes )
                    .textFieldStyle( .roundedBorder )
                    .autocorrectionDisabled()
                    .disabled( self.restrictAirlines == false )
            }
        }
        .formStyle( .grouped )
    }
}

private struct FiltersPane: View
{
    @AppStorage( FilterPersistencePreference.keepOnLaunchDefaultsKey ) private var keepFiltersOnLaunch = FilterPersistencePreference.defaultKeepOnLaunch

    var body: some View
    {
        Form
        {
            Section
            {
                Toggle( "Keep results filters between launches", isOn: $keepFiltersOnLaunch )
            } footer: {
                Text( "When off, every search starts unfiltered after the app is relaunched." )
                    .font( .caption )
                    .foregroundStyle( .secondary )
            }
        }
        .formStyle( .grouped )
    }
}

private struct LimitsPane: View
{
    @AppStorage( OneWaySweepPreference.capDefaultsKey ) private var oneWaySweepCap = OneWaySweepPreference.defaultCap
    @AppStorage( RoundTripSweepPreference.capDefaultsKey ) private var roundTripSweepCap = RoundTripSweepPreference.defaultCap
    @AppStorage( BookingLinkExpiryPreference.maxRunAgeHoursDefaultsKey ) private var bookingLinkHours = BookingLinkExpiryPreference.defaultHours

    var body: some View
    {
        Form
        {
            Section
            {
                Stepper( "One-way sweep cap: \( self.oneWaySweepCap )", value: $oneWaySweepCap, in: 1 ... 100 )
                Stepper( "Round-trip sweep cap: \( self.roundTripSweepCap )", value: $roundTripSweepCap, in: 1 ... 500 )
            } footer: {
                Text( "A sweep spends one billed API call per request, so a cap is also a ceiling on what one update costs." )
                    .font( .caption )
                    .foregroundStyle( .secondary )
            }

            Section
            {
                Picker( "Booking links valid for", selection: $bookingLinkHours )
                {
                    ForEach( BookingLinkExpiryPreference.allHours, id: \.self )
                    { hours in
                        Text( BookingLinkExpiryPreference.label( forHours: hours ) ).tag( hours )
                    }
                }
            }
        }
        .formStyle( .grouped )
    }
}
