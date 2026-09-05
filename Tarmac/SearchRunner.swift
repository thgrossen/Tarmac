/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

enum SearchRunner
{
    private static let noFaresMessage = "No flights for these filters (request valid… and billed)."

    /**
     * Runs a saved search — dispatching to the one-way date sweep or to the round-trip
     * shape search based on `search.kind` — and records the outcome as a new SearchRun
     * appended to `search.runs`. Earlier runs are never modified or removed, so history
     * accumulates across refreshes.
     *
     * Both kinds sweep their whole date range: one-way issues one Ignav
     * `IgnavClient.oneWay(_:)` call per day in `search.rangeStart...search.rangeEnd`
     * (capped and sampled per `OneWaySweepPreference`), and round-trip issues one call
     * per departure/return candidate via the shape search (capped and sampled per
     * `RoundTripSweepPreference`).
     *
     * @param search Saved search to run.
     * @param apiKey Ignav API key.
     * @param defaults UserDefaults suite to read the airline restriction / cap preferences from.
     * @param oneWayFetch Override for the one-way network call, used by tests.
     * @param roundTripFetch Override for the round-trip network call, used by tests.
     * @param onProgress Called with the sweep's planned request count before the first call, then
     *                   once after every request — including one that failed, since it has been
     *                   spent all the same — whichever kind the search is. A search with nothing
     *                   planned emits a single 0-of-0 and nothing else. Emissions arrive
     *                   synchronously, in order, on the main actor these functions are isolated
     *                   to under the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
     * @return The newly created SearchRun, already appended to `search.runs`.
     */
    @discardableResult
    static func run(
        for search: SavedSearch,
        apiKey: String,
        defaults: UserDefaults = .standard,
        oneWayFetch: ( ( OneWayRequest ) async throws -> ( FaresResponse, String ) )? = nil,
        roundTripFetch: ( ( RoundTripRequest ) async throws -> ( FaresResponse, String ) )? = nil,
        onProgress: ( ( SearchProgress ) -> Void )? = nil
    ) async -> SearchRun
    {
        // The run's identity is settled up front so every request it makes can be attributed to it
        // while it is still in flight, which is what lets the API inspector scope to one run.
        let runID = UUID()

        let run = await APICallContext.$current.withValue( APICallContext.Info( runID: runID ) )
        {
            switch search.kind
            {
                case .oneWay:
                    return await self.runOneWay(
                        id: runID,
                        for: search,
                        apiKey: apiKey,
                        defaults: defaults,
                        fetch: oneWayFetch,
                        onProgress: onProgress
                    )

                case .roundTrip:
                    return await self.runRoundTrip(
                        id: runID,
                        for: search,
                        apiKey: apiKey,
                        defaults: defaults,
                        fetch: roundTripFetch,
                        onProgress: onProgress
                    )
            }
        }

        run.savedSearch = search
        search.runs.append( run )
        return run
    }

    private static func runOneWay(
        id: UUID,
        for search: SavedSearch,
        apiKey: String,
        defaults: UserDefaults,
        fetch: ( ( OneWayRequest ) async throws -> ( FaresResponse, String ) )?,
        onProgress: ( ( SearchProgress ) -> Void )?
    ) async -> SearchRun
    {
        let result = await OneWayDateSweep.run(
            for: search,
            apiKey: apiKey,
            cap: OneWaySweepPreference.currentCap( defaults: defaults ),
            defaults: defaults,
            fetch: fetch,
            onProgress: onProgress
        )

        let isAllRequestsFailed = result.failedRequestCount == result.requestCount && result.requestCount > 0
        let errorMessage = result.itineraries.isEmpty
            ? ( isAllRequestsFailed ? result.errorMessage : self.noFaresMessage )
            : nil
        let partialFailureMessage = result.failedRequestCount > 0 && isAllRequestsFailed == false
            ? "\( result.failedRequestCount ) of \( result.requestCount ) day requests failed."
            : nil

        let run = SearchRun(
            id: id,
            rawJSON: result.rawJSON,
            errorMessage: errorMessage,
            partialFailureMessage: partialFailureMessage,
            requestCount: result.requestCount
        )
        run.itineraries = result.itineraries.map { self.snapshot( for: $0, run: run ) }
        return run
    }

    private static func runRoundTrip(
        id: UUID,
        for search: SavedSearch,
        apiKey: String,
        defaults: UserDefaults,
        fetch: ( ( RoundTripRequest ) async throws -> ( FaresResponse, String ) )?,
        onProgress: ( ( SearchProgress ) -> Void )?
    ) async -> SearchRun
    {
        let result = await RoundTripShapeSearch.run(
            for: search,
            apiKey: apiKey,
            cap: RoundTripSweepPreference.currentCap( defaults: defaults ),
            defaults: defaults,
            fetch: fetch,
            onProgress: onProgress
        )

        let errorMessage = result.errorMessage ?? ( result.itineraries.isEmpty ? self.noFaresMessage : nil )
        let run = SearchRun(
            id: id,
            rawJSON: result.rawJSON,
            errorMessage: errorMessage,
            truncationMessage: self.truncationMessage(
                candidateCount: result.candidateCount,
                requestCount: result.requestCount
            ),
            requestCount: result.requestCount
        )
        run.itineraries = result.itineraries.map { self.snapshot( for: $0, run: run ) }
        return run
    }

    /**
     * Describes a round-trip sweep the cap kept from covering its whole matrix, pointing at the
     * preference that widens it.
     *
     * @param candidateCount Number of date pairs the search covers.
     * @param requestCount Number of them actually requested, once the cap was applied.
     * @return The notice to show alongside the run's results, or nil when nothing was dropped.
     *         Worded for a round-trip sweep — a one-way sweep would need its own copy.
     */
    static func truncationMessage( candidateCount: Int, requestCount: Int ) -> String?
    {
        guard requestCount < candidateCount
        else
        {
            return nil
        }

        // A cap of 1 takes the first pair rather than spreading, so the even-sampling claim only
        // holds from two upwards.
        let coverage = requestCount == 1
            ? "Searched 1 of \( candidateCount ) possible date pairs"
            : "Searched \( requestCount ) of \( candidateCount ) possible date pairs, spread evenly across the range"

        return coverage + ". Raise the round-trip sweep cap in Settings › Limits to search more."
    }

    private static func snapshot( for itinerary: Itinerary, run: SearchRun ) -> PriceSnapshot
    {
        PriceSnapshot(
            amount: itinerary.price.amount,
            currency: itinerary.price.currency,
            ignavID: itinerary.ignav_id,
            outboundSummary: self.legSummary( itinerary.outbound ),
            inboundSummary: self.legSummary( itinerary.inbound ),
            outboundDuration: itinerary.outbound?.duration,
            carrier: itinerary.outbound?.carrier,
            departureTime: itinerary.outbound?.segments?.first?.departure_time,
            arrivalTime: itinerary.outbound?.segments?.last?.arrival_time,
            departureDate: itinerary.outbound?.segments?.first?.departure_date,
            inboundDepartureTime: itinerary.inbound?.segments?.first?.departure_time,
            inboundDepartureDate: itinerary.inbound?.segments?.first?.departure_date,
            outboundStopCount: itinerary.outbound?.segments.map { max( $0.count - 1, 0 ) },
            outboundFlightNumbers: self.flightNumbers( itinerary.outbound ),
            run: run
        )
    }

    private static func legSummary( _ leg: Leg? ) -> String?
    {
        let flightNumbers = self.flightNumbers( leg )
        guard flightNumbers.isEmpty == false
        else
        {
            return nil
        }
        return flightNumbers.joined( separator: PriceSnapshotBackfill.flightNumberSeparator )
    }

    /**
     * Each of a leg's segments as a carrier-and-flight-number pair, e.g. [ "LX 1234", "TP 5678" ],
     * preferring the marketing carrier over the operating one.
     *
     * @param leg Leg to describe, or nil.
     * @return One entry per segment, in order; empty when the leg is missing or has no segments.
     */
    private static func flightNumbers( _ leg: Leg? ) -> [ String ]
    {
        guard let segments = leg?.segments
        else
        {
            return []
        }
        return segments.map { "\( $0.marketing_carrier_code ?? $0.carrier_code ?? "" ) \( $0.flight_number ?? "" )" }
    }
}
