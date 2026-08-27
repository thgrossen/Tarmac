/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "OneWaySweepPreference" )
struct OneWaySweepPreferenceTests
{
    private static func freshDefaults() -> UserDefaults
    {
        UserDefaults( suiteName: "OneWaySweepPreferenceTests.\( UUID().uuidString )" )!
    }

    @Test( "Defaults to 25 when nothing has been persisted yet" )
    func currentCapDefaults()
    {
        let defaults = Self.freshDefaults()
        #expect( OneWaySweepPreference.currentCap( defaults: defaults ) == 25 )
    }

    @Test( "Reflects a persisted cap" )
    func currentCapPersisted()
    {
        let defaults = Self.freshDefaults()
        defaults.set( 10, forKey: OneWaySweepPreference.capDefaultsKey )
        #expect( OneWaySweepPreference.currentCap( defaults: defaults ) == 10 )
    }
}
