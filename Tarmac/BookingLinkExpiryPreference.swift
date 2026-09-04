/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

/**
 * How long a run's results stay bookable. Ignav publishes no lifetime for a handoff token beyond
 * "a few hours", so this is a user-tunable guess rather than a contract.
 */
enum BookingLinkExpiryPreference
{
    nonisolated static let maxRunAgeHoursDefaultsKey = "booking_link_max_run_age_hours"
    nonisolated static let defaultHours = 24
    nonisolated static let allHours = [ 1, 3, 6, 12, 24 ]

    /**
     * Reads the configured booking-link lifetime.
     *
     * @param defaults UserDefaults suite to read the preference from.
     * @return The persisted number of hours, or `defaultHours` when none is set or the stored
     *         value is no longer offered.
     */
    static func currentHours( defaults: UserDefaults = .standard ) -> Int
    {
        let persisted = defaults.integer( forKey: Self.maxRunAgeHoursDefaultsKey )

        return Self.allHours.contains( persisted ) ? persisted : Self.defaultHours
    }

    /**
     * The configured booking-link lifetime as an age a run can be compared against.
     *
     * @param defaults UserDefaults suite to read the preference from.
     * @return The lifetime in seconds.
     */
    static func currentMaxRunAge( defaults: UserDefaults = .standard ) -> TimeInterval
    {
        TimeInterval( Self.currentHours( defaults: defaults ) ) * 3600
    }

    /**
     * The menu label for one of the offered lifetimes, e.g. "1 hour" or "12 hours".
     *
     * @param hours Lifetime to describe.
     * @return The label.
     */
    nonisolated static func label( forHours hours: Int ) -> String
    {
        hours == 1 ? "1 hour" : "\( hours ) hours"
    }
}
