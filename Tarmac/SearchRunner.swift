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
     * per departure/return candidate via the shape search.
     *
     * @param search Saved search to run.
     * @param apiKey Ignav API key.
     * @param defaults UserDefaults suite to read the airline restriction / cap preferences from.
     * @param cap Maximum number of Ignav calls a round-trip shape search may make; ignored for one-way.
     * @param oneWayFetch Override for the one-way network call, used by tests.
     * @param roundTripFetch Override for the round-trip network call, used by tests.
     * @return The newly created SearchRun, already appended to `search.runs`.
     */
    @discardableResult
    static func run(
        for search: SavedSearch,
        apiKey: String,
        defaults: UserDefaults = .standard,
        cap: Int = RoundTripShapeSearch.defaultCallCap,
        oneWayFetch: ( ( OneWayRequest ) async throws -> ( FaresResponse, String ) )? = nil,
        roundTripFetch: ( ( RoundTripRequest ) async throws -> ( FaresResponse, String ) )? = nil
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
                    )

                case .roundTrip:
                    return await self.runRoundTrip(
                        id: runID,
                        for: search,
                        apiKey: apiKey,
                        defaults: defaults,
                        cap: cap,
                        fetch: roundTripFetch,
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
        fetch: ( ( OneWayRequest ) async throws -> ( FaresResponse, String ) )?
    ) async -> SearchRun
    {
        let result = await OneWayDateSweep.run(
            for: search,
            apiKey: apiKey,
            cap: OneWaySweepPreference.currentCap( defaults: defaults ),
            defaults: defaults,
            fetch: fetch
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
        cap: Int,
        fetch: ( ( RoundTripRequest ) async throws -> ( FaresResponse, String ) )?
    ) async -> SearchRun
    {
        let result = await RoundTripShapeSearch.run(
            for: search,
            apiKey: apiKey,
            cap: cap,
            defaults: defaults,
            fetch: fetch
        )

        let errorMessage = result.errorMessage ?? ( result.itineraries.isEmpty ? self.noFaresMessage : nil )
        let run = SearchRun(
            id: id,
            rawJSON: result.rawJSON,
            errorMessage: errorMessage,
            requestCount: result.requestCount
        )
        run.itineraries = result.itineraries.map { self.snapshot( for: $0, run: run ) }
        return run
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
            run: run
        )
    }

    private static func legSummary( _ leg: Leg? ) -> String?
    {
        guard let segments = leg?.segments,
              segments.isEmpty == false
        else
        {
            return nil
        }
        return segments
            .map { "\( $0.marketing_carrier_code ?? $0.carrier_code ?? "" ) \( $0.flight_number ?? "" )" }
            .joined( separator: " → " )
    }
}
