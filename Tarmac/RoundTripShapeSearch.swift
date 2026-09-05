/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

struct ShapeSearchResult
{
    var itineraries: [ Itinerary ] = []

    /**
     * Number of requests attempted, which is the candidate count narrowed to the sweep's cap.
     * A request that failed still counts, since it was spent all the same.
     */
    var requestCount = 0

    /**
     * Number of date pairs the search could have covered, before the cap thinned them down.
     * Equal to `requestCount` when the cap didn't bite.
     */
    var candidateCount = 0

    var rawJSON: String?
    var errorMessage: String?
}

enum RoundTripShapeSearch
{
    struct Candidate: Equatable
    {
        var departure: Date
        var returnDate: Date
    }

    private static let calendar: Calendar = {
        var calendar = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        return calendar
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone( identifier: "UTC" )
        f.locale = Locale( identifier: "en_US_POSIX" )
        return f
    }()

    /**
     * Enumerates every candidate departure/return date pair implied by a round-trip
     * SavedSearch's date range, trip duration and flexibility, dropping any pair that
     * doesn't include a weekend when the search requires one.
     *
     * @param search Round-trip SavedSearch to enumerate candidates for.
     * @return All matching candidates, in departure-date then duration order.
     */
    static func candidates( for search: SavedSearch ) -> [ Candidate ]
    {
        let rangeStart = self.calendar.startOfDay( for: min( search.rangeStart, search.rangeEnd ) )
        let rangeEnd   = self.calendar.startOfDay( for: max( search.rangeStart, search.rangeEnd ) )
        let dayCount   = ( self.calendar.dateComponents( [ .day ], from: rangeStart, to: rangeEnd ).day ?? 0 ) + 1

        let durations = search.searchedDurationRange

        var result: [ Candidate ] = []
        for dayOffset in 0 ..< dayCount
        {
            guard let departure = self.calendar.date( byAdding: .day, value: dayOffset, to: rangeStart )
            else
            {
                continue
            }

            for duration in durations
            {
                guard let returnDate = self.calendar.date( byAdding: .day, value: duration, to: departure )
                else
                {
                    continue
                }

                if search.mustIncludeWeekend, self.spanIncludesWeekend( from: departure, to: returnDate ) == false
                {
                    continue
                }

                result.append( Candidate( departure: departure, returnDate: returnDate ) )
            }
        }
        return result
    }

    private static func spanIncludesWeekend( from departure: Date, to returnDate: Date ) -> Bool
    {
        let dayCount = self.calendar.dateComponents( [ .day ], from: departure, to: returnDate ).day ?? 0
        for dayOffset in 0 ... max( 0, dayCount )
        {
            guard let day = self.calendar.date( byAdding: .day, value: dayOffset, to: departure )
            else
            {
                continue
            }
            let weekday = self.calendar.component( .weekday, from: day )
            if weekday == 1 || weekday == 7
            {
                return true
            }
        }
        return false
    }

    /**
     * Samples at most `cap` candidates, evenly spaced across the full list, so a large
     * candidate set is thinned out rather than truncated from one end.
     *
     * @param candidates Full candidate list to sample from.
     * @param cap Maximum number of candidates to return.
     * @return At most `cap` candidates, in their original relative order.
     */
    static func sample( _ candidates: [ Candidate ], cap: Int ) -> [ Candidate ]
    {
        candidates.sampled( cap: cap )
    }

    /**
     * Runs a round-trip shape search: enumerates and caps candidate date pairs, fires
     * one Ignav round-trip request per candidate, and aggregates the results.
     *
     * Expects a round-trip SavedSearch (`search.kind == .roundTrip`); the round-trip-only
     * fields it reads (`tripDurationDays`, `flexibilityDays`, `mustIncludeWeekend`) are
     * meaningless for a one-way search.
     *
     * @param search Round-trip SavedSearch to run.
     * @param apiKey Ignav API key.
     * @param cap Maximum number of Ignav calls to make; defaults to `RoundTripSweepPreference.defaultCap`,
     *            which ignores the user's preference — pass
     *            `RoundTripSweepPreference.currentCap( defaults: )` to honour it.
     * @param defaults UserDefaults suite to read the airline restriction preference from.
     * @param fetch Override for the network call, used by tests; defaults to a real IgnavClient.
     * @param onProgress Called with the planned request count before the first call, then once
     *                   after every request — including one that failed, since it has been spent
     *                   all the same. A search with nothing planned emits a single 0-of-0 and
     *                   nothing else. Called synchronously on the main actor, which this sweep
     *                   runs on, so emissions arrive in order.
     * @return The aggregated, deduplicated, price-sorted itineraries and run metadata, including
     *         both the number of candidates the search covers and the number it actually requested.
     */
    static func run(
        for search: SavedSearch,
        apiKey: String,
        cap: Int = RoundTripSweepPreference.defaultCap,
        defaults: UserDefaults = .standard,
        fetch: ( ( RoundTripRequest ) async throws -> ( FaresResponse, String ) )? = nil,
        onProgress: ( ( SearchProgress ) -> Void )? = nil
    ) async -> ShapeSearchResult
    {
        let performFetch = fetch ?? { request in
            try await IgnavClient( apiKey: apiKey ).roundTrip( request )
        }

        let candidates = self.candidates( for: search )
        let sampled    = self.sample( candidates, cap: cap )
        let airlinesInclude = AirlinePreference.currentAirlinesInclude( defaults: defaults )
        let market = MarketPreference.currentMarket( defaults: defaults )

        var itineraries: [ Itinerary ] = []
        var seenIDs = Set< String >()
        var cheapestAmount: Double?
        var rawJSONOfCheapest: String?
        var lastError: Error?
        var completedRequestCount = 0

        onProgress?( SearchProgress( completed: 0, total: sampled.count ) )

        for candidate in sampled
        {
            let body = RoundTripRequest(
                origin: search.origin.uppercased(),
                destination: search.destination.uppercased(),
                departure_date: self.dateFormatter.string( from: candidate.departure ),
                return_date: self.dateFormatter.string( from: candidate.returnDate ),
                cabin_class: search.cabinClass,
                max_stops: search.directOnly ? 0 : 2,
                min_carry_on_bags: search.carryOnIncluded ? 1 : nil,
                min_checked_bags: search.checkedBagIncluded ? 1 : nil,
                airlines_include: airlinesInclude,
                market: market
            )

            do
            {
                let ( response, raw ) = try await performFetch( body )
                for itinerary in response.itineraries
                {
                    if let ignavID = itinerary.ignav_id
                    {
                        if seenIDs.insert( ignavID ).inserted
                        {
                            itineraries.append( itinerary )
                        }
                    }
                    else
                    {
                        itineraries.append( itinerary )
                    }

                    if cheapestAmount == nil || itinerary.price.amount < cheapestAmount!
                    {
                        cheapestAmount = itinerary.price.amount
                        rawJSONOfCheapest = raw
                    }
                }
            }
            catch
            {
                lastError = error
            }

            completedRequestCount += 1
            onProgress?( SearchProgress( completed: completedRequestCount, total: sampled.count ) )
        }

        itineraries.sort { $0.price.amount < $1.price.amount }

        return ShapeSearchResult(
            itineraries: itineraries,
            requestCount: sampled.count,
            candidateCount: candidates.count,
            rawJSON: rawJSONOfCheapest,
            errorMessage: itineraries.isEmpty ? lastError?.localizedDescription : nil
        )
    }
}
