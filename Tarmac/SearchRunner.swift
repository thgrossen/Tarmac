/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

enum SearchRunner
{
    private static let noFaresMessage = "No flights for these filters (request valid… and billed)."

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone( identifier: "UTC" )
        f.locale = Locale( identifier: "en_US_POSIX" )
        return f
    }()

    /**
     * Runs a saved search — dispatching to a single Ignav one-way call or to the
     * round-trip shape search based on `search.kind` — and records the outcome as a
     * new SearchRun appended to `search.runs`. Earlier runs are never modified or
     * removed, so history accumulates across refreshes.
     *
     * A one-way search only ever checks `search.rangeStart`: unlike round-trip, which
     * sweeps its whole date range via the shape search, this dispatches a single
     * `IgnavClient.oneWay(_:)` call and does not sweep through `search.rangeEnd`.
     * Sweeping the one-way range the same way is a possible future improvement.
     *
     * @param search Saved search to run.
     * @param apiKey Ignav API key.
     * @param defaults UserDefaults suite to read the airline restriction preference from.
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
        let run: SearchRun
        switch search.kind
        {
            case .oneWay:
                run = await self.runOneWay( for: search, apiKey: apiKey, defaults: defaults, fetch: oneWayFetch )

            case .roundTrip:
                run = await self.runRoundTrip( for: search, apiKey: apiKey, defaults: defaults, cap: cap, fetch: roundTripFetch )
        }

        run.savedSearch = search
        search.runs.append( run )
        return run
    }

    private static func runOneWay(
        for search: SavedSearch,
        apiKey: String,
        defaults: UserDefaults,
        fetch: ( ( OneWayRequest ) async throws -> ( FaresResponse, String ) )?
    ) async -> SearchRun
    {
        let performFetch = fetch ?? { request in
            try await IgnavClient( apiKey: apiKey ).oneWay( request )
        }

        let body = OneWayRequest(
            origin: search.origin.uppercased(),
            destination: search.destination.uppercased(),
            departure_date: self.dateFormatter.string( from: search.rangeStart ),
            cabin_class: search.cabinClass,
            max_stops: search.directOnly ? 0 : 2,
            airlines_include: AirlinePreference.currentAirlinesInclude( defaults: defaults ),
            market: MarketPreference.currentMarket( defaults: defaults )
        )

        do
        {
            let ( response, raw ) = try await performFetch( body )
            let itineraries = response.itineraries.sorted { $0.price.amount < $1.price.amount }
            let run = SearchRun(
                rawJSON: raw,
                errorMessage: itineraries.isEmpty ? self.noFaresMessage : nil,
                requestCount: 1
            )
            run.itineraries = itineraries.map { self.snapshot( for: $0, run: run ) }
            return run
        }
        catch
        {
            return SearchRun( errorMessage: error.localizedDescription, requestCount: 1 )
        }
    }

    private static func runRoundTrip(
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
            .map { "\( $0.carrier_code ?? "" )\( $0.flight_number ?? "" )" }
            .joined( separator: " → " )
    }
}
