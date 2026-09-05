/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "RoundTripSweepPreference" )
struct RoundTripSweepPreferenceTests
{
    private static func freshDefaults() -> UserDefaults
    {
        UserDefaults( suiteName: "RoundTripSweepPreferenceTests.\( UUID().uuidString )" )!
    }

    @Test( "Defaults to 100 when nothing has been persisted yet" )
    func currentCapDefaults()
    {
        let defaults = Self.freshDefaults()
        #expect( RoundTripSweepPreference.currentCap( defaults: defaults ) == 100 )
    }

    @Test( "Reflects a persisted cap" )
    func currentCapPersisted()
    {
        let defaults = Self.freshDefaults()
        defaults.set( 40, forKey: RoundTripSweepPreference.capDefaultsKey )
        #expect( RoundTripSweepPreference.currentCap( defaults: defaults ) == 40 )
    }

    @Test( "Falls back to the default for a zero or negative persisted cap" )
    func currentCapRejectsNonPositiveValues()
    {
        let defaults = Self.freshDefaults()

        defaults.set( 0, forKey: RoundTripSweepPreference.capDefaultsKey )
        #expect( RoundTripSweepPreference.currentCap( defaults: defaults ) == RoundTripSweepPreference.defaultCap )

        defaults.set( -5, forKey: RoundTripSweepPreference.capDefaultsKey )
        #expect( RoundTripSweepPreference.currentCap( defaults: defaults ) == RoundTripSweepPreference.defaultCap )
    }
}
