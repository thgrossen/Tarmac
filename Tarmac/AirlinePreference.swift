/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

enum AirlinePreference
{
    static let restrictAirlinesDefaultsKey = "restrict_airlines"
    static let airlineCodesDefaultsKey = "airline_codes"
    static let defaultAirlineCodes = "LX, TP"

    /**
     * Splits a comma-separated list of IATA codes into trimmed, uppercased,
     * non-empty codes.
     *
     * @param raw Comma-separated codes as typed by the user.
     * @return The normalized codes, in order, with empty entries dropped.
     */
    static func parseCodes( _ raw: String ) -> [ String ]
    {
        raw
            .split( separator: "," )
            .map { $0.trimmingCharacters( in: .whitespaces ).uppercased() }
            .filter { $0.isEmpty == false }
    }

    /**
     * Computes the `airlines_include` value to send to Ignav.
     *
     * @param restrictAirlines Whether results should be restricted to specific carriers.
     * @param rawCodes Comma-separated IATA codes as typed by the user.
     * @return The normalized codes, or nil if unrestricted or no codes are configured.
     */
    static func airlinesInclude( restrictAirlines: Bool, rawCodes: String ) -> [ String ]?
    {
        guard restrictAirlines
        else
        {
            return nil
        }

        let codes = Self.parseCodes( rawCodes )
        return codes.isEmpty ? nil : codes
    }

    /**
     * Reads the current airline restriction preference and computes the
     * `airlines_include` value to send to Ignav.
     *
     * @param defaults UserDefaults suite to read the preference from.
     * @return The normalized codes, or nil if unrestricted or no codes are configured.
     */
    static func currentAirlinesInclude( defaults: UserDefaults = .standard ) -> [ String ]?
    {
        let restrictAirlines = ( defaults.object( forKey: Self.restrictAirlinesDefaultsKey ) as? Bool ) ?? true
        let rawCodes = defaults.string( forKey: Self.airlineCodesDefaultsKey ) ?? Self.defaultAirlineCodes
        return Self.airlinesInclude( restrictAirlines: restrictAirlines, rawCodes: rawCodes )
    }
}
