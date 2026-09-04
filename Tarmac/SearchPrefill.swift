/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

enum SearchPrefill
{
    static let defaultCabinClass = "business"
    static let defaultDirectOnly = true
    static let defaultCarryOnIncluded = false
    static let defaultCheckedBagIncluded = false
    static let defaultPassengers = 1
    static let defaultTripDurationDays = 3
    static let defaultFlexibilityDays = 0
    static let defaultMustIncludeWeekend = false

    struct SharedFields: Equatable
    {
        var origin: String
        var destination: String
        var cabinClass: String
        var directOnly: Bool
        var carryOnIncluded: Bool
        var checkedBagIncluded: Bool
        var passengers: Int
    }

    struct RoundTripFields: Equatable
    {
        var tripDurationDays: Int
        var flexibilityDays: Int
        var mustIncludeWeekend: Bool
    }

    /**
     * Non-date field values to prefill a new search form with.
     *
     * @param mostRecent The most recently created saved search, of either kind, if any.
     * @return Values copied from `mostRecent`, or empty/default values when there is no prior search.
     */
    static func sharedFields( from mostRecent: SavedSearch? ) -> SharedFields
    {
        guard let mostRecent
        else
        {
            return SharedFields(
                origin: "",
                destination: "",
                cabinClass: self.defaultCabinClass,
                directOnly: self.defaultDirectOnly,
                carryOnIncluded: self.defaultCarryOnIncluded,
                checkedBagIncluded: self.defaultCheckedBagIncluded,
                passengers: self.defaultPassengers
            )
        }

        return SharedFields(
            origin: mostRecent.origin,
            destination: mostRecent.destination,
            cabinClass: mostRecent.cabinClass,
            directOnly: mostRecent.directOnly,
            carryOnIncluded: mostRecent.carryOnIncluded,
            checkedBagIncluded: mostRecent.checkedBagIncluded,
            passengers: mostRecent.passengers
        )
    }

    /**
     * Finds the most recent non-seeded search among a set of searches.
     *
     * Excludes searches the app created on the user's behalf rather than ones they set up
     * themselves, so a route they never chose is never echoed back into a new search form.
     *
     * @param searches Currently available searches, newest first.
     * @return The newest search with `isSeeded == false`, or nil if none exists.
     */
    static func mostRecentReal( in searches: [ SavedSearch ] ) -> SavedSearch?
    {
        searches.first { $0.isSeeded == false }
    }

    /**
     * Finds the most recent non-seeded round-trip search among a set of searches.
     *
     * @param searches Currently available searches, newest first.
     * @return The newest search with `kind == .roundTrip` and `isSeeded == false`, or nil if none exists.
     */
    static func mostRecentRoundTrip( in searches: [ SavedSearch ] ) -> SavedSearch?
    {
        searches.first { $0.kind == .roundTrip && $0.isSeeded == false }
    }

    /**
     * Round-trip-only field values to prefill a new round-trip search form with.
     *
     * @param mostRecentRoundTrip The most recently created round-trip search, if any.
     * @return Values copied from `mostRecentRoundTrip`, or today's hardcoded defaults when none exists yet.
     */
    static func roundTripFields( from mostRecentRoundTrip: SavedSearch? ) -> RoundTripFields
    {
        guard let mostRecentRoundTrip
        else
        {
            return RoundTripFields(
                tripDurationDays: self.defaultTripDurationDays,
                flexibilityDays: self.defaultFlexibilityDays,
                mustIncludeWeekend: self.defaultMustIncludeWeekend
            )
        }

        return RoundTripFields(
            tripDurationDays: mostRecentRoundTrip.tripDurationDays,
            flexibilityDays: mostRecentRoundTrip.flexibilityDays,
            mustIncludeWeekend: mostRecentRoundTrip.mustIncludeWeekend
        )
    }
}
