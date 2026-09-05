/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

/**
 * The flexibility values a round-trip search form offers, and how they read.
 *
 * Flexibility widens the trip duration either side of the chosen number of nights, so the
 * useful range is small; the list stops at a week.
 */
enum FlexibilityOptions
{
    static let maximumDays = 7

    /**
     * Selectable flexibility values, in ascending order.
     *
     * A stored search can hold a value beyond the maximum. Rather than silently rewriting it,
     * the list widens to include it, so reopening such a search shows what it actually
     * searches.
     *
     * @param prefilled Value the form currently holds, which the list must be able to show.
     * @return Every offered day count, ascending and without duplicates, always including
     *         `prefilled` when it is a selectable value — pass a stored one through
     *         `selectable( from: )` first.
     */
    static func days( including prefilled: Int ) -> [ Int ]
    {
        let offered = Array( 0 ... Self.maximumDays )
        if prefilled > Self.maximumDays
        {
            return offered + [ prefilled ]
        }
        return offered
    }

    /**
     * A stored flexibility as the picker can select it.
     *
     * A negative value is meaningless as a flexibility — and offering one would give the picker a
     * second entry also reading "None" — so it normalises to no flexibility rather than widening
     * the list downwards. Values above the maximum are genuine searches and are left alone for
     * `days( including: )` to widen around.
     *
     * @param stored Value read from a saved search.
     * @return `stored`, or zero when it is negative.
     */
    static func selectable( from stored: Int ) -> Int
    {
        max( 0, stored )
    }

    /**
     * How a flexibility value reads in the picker.
     *
     * @param days Flexibility in days, either side of the trip duration.
     * @return "None" for no flexibility, otherwise a singular or plural day count.
     */
    static func label( forDays days: Int ) -> String
    {
        guard days > 0
        else
        {
            return "None"
        }
        return "\( days ) day\( days == 1 ? "" : "s" )"
    }
}
