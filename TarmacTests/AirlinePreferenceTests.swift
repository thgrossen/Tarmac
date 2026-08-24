/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "AirlinePreference" )
struct AirlinePreferenceTests
{
    private static func freshDefaults() -> UserDefaults
    {
        UserDefaults( suiteName: "AirlinePreferenceTests.\( UUID().uuidString )" )!
    }

    @Test( "Parses, trims, uppercases and drops empty codes" )
    func parseCodes()
    {
        #expect( AirlinePreference.parseCodes( "lx, tp" ) == [ "LX", "TP" ] )
        #expect( AirlinePreference.parseCodes( "  lx ,, tp  " ) == [ "LX", "TP" ] )
        #expect( AirlinePreference.parseCodes( "" ) == [] )
    }

    @Test( "No restriction when disabled, regardless of codes" )
    func airlinesIncludeDisabled()
    {
        #expect( AirlinePreference.airlinesInclude( restrictAirlines: false, rawCodes: "LX, TP" ) == nil )
    }

    @Test( "Restriction list when enabled with codes" )
    func airlinesIncludeEnabled()
    {
        #expect( AirlinePreference.airlinesInclude( restrictAirlines: true, rawCodes: "LX, TP" ) == [ "LX", "TP" ] )
    }

    @Test( "No restriction when enabled but codes are empty" )
    func airlinesIncludeEnabledNoCodes()
    {
        #expect( AirlinePreference.airlinesInclude( restrictAirlines: true, rawCodes: "   " ) == nil )
    }

    @Test( "Defaults to restricted LX/TP when nothing has been persisted yet" )
    func currentAirlinesIncludeDefaults()
    {
        let defaults = Self.freshDefaults()
        #expect( AirlinePreference.currentAirlinesInclude( defaults: defaults ) == [ "LX", "TP" ] )
    }

    @Test( "Reflects a persisted disabled restriction" )
    func currentAirlinesIncludeDisabled()
    {
        let defaults = Self.freshDefaults()
        defaults.set( false, forKey: AirlinePreference.restrictAirlinesDefaultsKey )
        #expect( AirlinePreference.currentAirlinesInclude( defaults: defaults ) == nil )
    }

    @Test( "Reflects persisted custom codes" )
    func currentAirlinesIncludeCustomCodes()
    {
        let defaults = Self.freshDefaults()
        defaults.set( true, forKey: AirlinePreference.restrictAirlinesDefaultsKey )
        defaults.set( "AF, KL", forKey: AirlinePreference.airlineCodesDefaultsKey )
        #expect( AirlinePreference.currentAirlinesInclude( defaults: defaults ) == [ "AF", "KL" ] )
    }
}
