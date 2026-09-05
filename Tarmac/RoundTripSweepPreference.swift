/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

enum RoundTripSweepPreference
{
    static let capDefaultsKey = "round_trip_sweep_cap"
    nonisolated static let defaultCap = 100

    /**
     * Reads the current round-trip sweep call cap preference.
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
