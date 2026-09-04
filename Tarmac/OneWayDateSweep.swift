/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

struct OneWaySweepResult
{
    var itineraries: [ Itinerary ] = []
    var requestCount = 0
    var failedRequestCount = 0
    var rawJSON: String?
    var errorMessage: String?
}

enum OneWayDateSweep
{
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
     * Enumerates every day in a one-way SavedSearch's date range, inclusive of both ends.
     *
     * @param search One-way SavedSearch to enumerate dates for.
     * @return Every day from the earliest to the latest of `rangeStart`/`rangeEnd`, in order.
     */
    static func dates( for search: SavedSearch ) -> [ Date ]
    {
        let rangeStart = self.calendar.startOfDay( for: min( search.rangeStart, search.rangeEnd ) )
        let rangeEnd   = self.calendar.startOfDay( for: max( search.rangeStart, search.rangeEnd ) )
        let dayCount   = ( self.calendar.dateComponents( [ .day ], from: rangeStart, to: rangeEnd ).day ?? 0 ) + 1

        var result: [ Date ] = []
        for dayOffset in 0 ..< dayCount
        {
            guard let day = self.calendar.date( byAdding: .day, value: dayOffset, to: rangeStart )
            else
            {
                continue
            }
            result.append( day )
        }
        return result
    }

    /**
     * Runs a one-way date-range sweep: enumerates and caps the search's date range, fires
     * one Ignav one-way request per sampled date, and aggregates the results.
     *
     * @param search One-way SavedSearch to run.
     * @param apiKey Ignav API key.
     * @param cap Maximum number of Ignav calls to make; defaults to `OneWaySweepPreference.defaultCap`.
     * @param defaults UserDefaults suite to read the airline restriction preference from.
     * @param fetch Override for the network call, used by tests; defaults to a real IgnavClient.
     * @param onProgress Called with the planned request count before the first call, then once
     *                   after every request — including one that failed, since it has been spent
     *                   all the same. A sweep with nothing planned emits a single 0-of-0 and
     *                   nothing else. Called synchronously on the main actor, which this sweep
     *                   runs on, so emissions arrive in order.
     * @return The aggregated, deduplicated, price-sorted itineraries and sweep metadata.
     */
    static func run(
        for search: SavedSearch,
        apiKey: String,
        cap: Int = OneWaySweepPreference.defaultCap,
        defaults: UserDefaults = .standard,
        fetch: ( ( OneWayRequest ) async throws -> ( FaresResponse, String ) )? = nil,
        onProgress: ( ( SearchProgress ) -> Void )? = nil
    ) async -> OneWaySweepResult
    {
        let performFetch = fetch ?? { request in
            try await IgnavClient( apiKey: apiKey ).oneWay( request )
        }

        let sampled = self.dates( for: search ).sampled( cap: cap )
        let airlinesInclude = AirlinePreference.currentAirlinesInclude( defaults: defaults )
        let market = MarketPreference.currentMarket( defaults: defaults )

        var itineraries: [ Itinerary ] = []
        var seenIDs = Set< String >()
        var cheapestAmount: Double?
        var rawJSONOfCheapest: String?
        var lastError: Error?
        var failedRequestCount = 0
        var completedRequestCount = 0

        onProgress?( SearchProgress( completed: 0, total: sampled.count ) )

        for date in sampled
        {
            let body = OneWayRequest(
                origin: search.origin.uppercased(),
                destination: search.destination.uppercased(),
                departure_date: self.dateFormatter.string( from: date ),
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
                failedRequestCount += 1
            }

            completedRequestCount += 1
            onProgress?( SearchProgress( completed: completedRequestCount, total: sampled.count ) )
        }

        itineraries.sort { $0.price.amount < $1.price.amount }

        return OneWaySweepResult(
            itineraries: itineraries,
            requestCount: sampled.count,
            failedRequestCount: failedRequestCount,
            rawJSON: rawJSONOfCheapest,
            errorMessage: itineraries.isEmpty ? lastError?.localizedDescription : nil
        )
    }
}
