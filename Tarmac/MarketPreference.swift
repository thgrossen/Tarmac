/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

enum MarketPreference
{
    static let marketDefaultsKey = "market"
    static let defaultMarket = "CH"
    static let allMarkets = [ "CH", "FR", "DE", "GB", "US" ]

    /**
     * Reads the current market preference.
     *
     * @param defaults UserDefaults suite to read the preference from.
     * @return The persisted market code, or `defaultMarket` if none is set.
     */
    static func currentMarket( defaults: UserDefaults = .standard ) -> String
    {
        defaults.string( forKey: Self.marketDefaultsKey ) ?? Self.defaultMarket
    }
}
