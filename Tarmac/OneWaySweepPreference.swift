/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

enum OneWaySweepPreference
{
    static let capDefaultsKey = "one_way_sweep_cap"
    static let defaultCap = 25

    /**
     * Reads the current one-way sweep call cap preference.
     *
     * @param defaults UserDefaults suite to read the preference from.
     * @return The persisted cap, or `defaultCap` if none is set.
     */
    static func currentCap( defaults: UserDefaults = .standard ) -> Int
    {
        let persisted = defaults.integer( forKey: Self.capDefaultsKey )
        return persisted > 0 ? persisted : Self.defaultCap
    }
}
