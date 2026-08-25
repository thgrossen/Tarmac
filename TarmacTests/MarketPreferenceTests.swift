/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "MarketPreference" )
struct MarketPreferenceTests
{
    private static func freshDefaults() -> UserDefaults
    {
        UserDefaults( suiteName: "MarketPreferenceTests.\( UUID().uuidString )" )!
    }

    @Test( "Defaults to CH when nothing has been persisted yet" )
    func currentMarketDefaults()
    {
        let defaults = Self.freshDefaults()
        #expect( MarketPreference.currentMarket( defaults: defaults ) == "CH" )
    }

    @Test( "Reflects a persisted market" )
    func currentMarketPersisted()
    {
        let defaults = Self.freshDefaults()
        defaults.set( "US", forKey: MarketPreference.marketDefaultsKey )
        #expect( MarketPreference.currentMarket( defaults: defaults ) == "US" )
    }

    @Test( "Offers the fixed list of markets, CH first" )
    func allMarkets()
    {
        #expect( MarketPreference.allMarkets == [ "CH", "FR", "DE", "GB", "US" ] )
    }
}
