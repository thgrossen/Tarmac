/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

/**
 * Decides whether a result's booking links can still be requested. An `ignav_id` is a short-lived
 * handoff token: updating a search replaces it, and it goes stale on its own soon after. Checking
 * here keeps dead results from spending a billed request that can only fail.
 */
enum BookingLinkAvailability
{
    enum Availability: Equatable
    {
        case available
        case missingID
        case superseded
        case expiredByAge
    }

    /**
     * Whether booking links can be requested for one result — and whether links already fetched
     * for it are still worth offering.
     *
     * @param snapshot Result to check.
     * @param now Current date, overridable by tests.
     * @param defaults UserDefaults suite to read the lifetime preference from.
     * @return `.available`, or the reason the result can't be booked.
     */
    static func availability(
        for snapshot: PriceSnapshot,
        now: Date = .now,
        defaults: UserDefaults = .standard
    ) -> Availability
    {
        guard let ignavID = snapshot.ignavID,
              ignavID.isEmpty == false,
              let run = snapshot.run
        else
        {
            return .missingID
        }

        if let newestRun = run.savedSearch?.runsNewestFirst.first,
           newestRun.id != run.id
        {
            return .superseded
        }

        if now.timeIntervalSince( run.runAt ) >= BookingLinkExpiryPreference.currentMaxRunAge( defaults: defaults )
        {
            return .expiredByAge
        }

        return .available
    }

    /**
     * Why a result can't be booked, for the disabled button's tooltip.
     *
     * @param availability Availability to explain.
     * @return The explanation, or nil when the result is bookable.
     */
    static func unavailableReason( _ availability: Availability ) -> String?
    {
        switch availability
        {
            case .available:    return nil
            case .missingID:    return "No booking reference"
            case .superseded:   return "Expired"
            case .expiredByAge: return "Expired"
        }
    }
}
