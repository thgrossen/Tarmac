/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "BookingLinkExpiryPreference" )
struct BookingLinkExpiryPreferenceTests
{
    private static func freshDefaults() -> UserDefaults
    {
        UserDefaults( suiteName: "BookingLinkExpiryPreferenceTests.\( UUID().uuidString )" )!
    }

    @Test( "An unset preference falls back to the default lifetime" )
    func unsetPreferenceUsesDefault()
    {
        let defaults = Self.freshDefaults()

        #expect( BookingLinkExpiryPreference.currentHours( defaults: defaults ) == BookingLinkExpiryPreference.defaultHours )
        #expect( BookingLinkExpiryPreference.currentMaxRunAge( defaults: defaults ) == 24 * 3600 )
    }

    @Test( "A stored lifetime is read back in seconds" )
    func storedPreferenceIsRead()
    {
        let defaults = Self.freshDefaults()
        defaults.set( 6, forKey: BookingLinkExpiryPreference.maxRunAgeHoursDefaultsKey )

        #expect( BookingLinkExpiryPreference.currentHours( defaults: defaults ) == 6 )
        #expect( BookingLinkExpiryPreference.currentMaxRunAge( defaults: defaults ) == 6 * 3600 )
    }

    @Test( "A value that isn't offered falls back to the default" )
    func unofferedValueFallsBack()
    {
        let defaults = Self.freshDefaults()
        defaults.set( 7, forKey: BookingLinkExpiryPreference.maxRunAgeHoursDefaultsKey )

        #expect( BookingLinkExpiryPreference.currentHours( defaults: defaults ) == BookingLinkExpiryPreference.defaultHours )
    }

    @Test( "Every offered lifetime has a readable label" )
    func labelsReadNaturally()
    {
        #expect( BookingLinkExpiryPreference.allHours == [ 1, 3, 6, 12, 24 ] )
        #expect( BookingLinkExpiryPreference.label( forHours: 1 ) == "1 hour" )
        #expect( BookingLinkExpiryPreference.label( forHours: 12 ) == "12 hours" )
    }
}
