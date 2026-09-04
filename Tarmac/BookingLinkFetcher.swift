/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

enum BookingLinkFetcher
{
    /// Error codes that mean the handoff token no longer resolves to an itinerary.
    private static let expiryCodes: Set< String > = [ "ignav_id_not_found", "itinerary_not_found" ]

    enum Outcome: Equatable
    {
        case links( [ BookingLinkChoice ] )
        case expired( String )
        case noneAvailable
        case failure( String )
    }

    /**
     * Asks Ignav for the booking links of one itinerary. Every successful lookup is billed, so
     * only call this from an explicit user action, and don't repeat it for a result already
     * resolved.
     *
     * @param ignavID Handoff token of the itinerary to resolve, from a previous fare search.
     * @param apiKey Ignav API key.
     * @param fetch Override for the network call, used by tests.
     * @return The usable offers, or why none can be shown.
     */
    static func links(
        forIgnavID ignavID: String,
        apiKey: String,
        fetch: ( ( BookingLinksRequest ) async throws -> ( BookingLinksResponse, String ) )? = nil
    ) async -> Outcome
    {
        let performFetch = fetch ?? { request in try await IgnavClient( apiKey: apiKey ).bookingLinks( request ) }

        do
        {
            let ( response, _ ) = try await performFetch( BookingLinksRequest( ignav_id: ignavID ) )
            let choices = self.choices( from: response )

            return choices.isEmpty ? .noneAvailable : .links( choices )
        }
        catch let error as IgnavError
        {
            if let code = error.apiCode,
               self.expiryCodes.contains( code )
            {
                return .expired( error.localizedDescription )
            }
            return .failure( error.localizedDescription )
        }
        catch
        {
            return .failure( error.localizedDescription )
        }
    }

    /**
     * Flattens a booking-links response into the offers worth showing, in the order the API
     * returned them. Links whose URL can't be opened are dropped. When the response splits the
     * trip into several separately bookable options, each offer is labelled with the legs it
     * covers so it's clear more than one purchase is needed.
     *
     * @param response Decoded booking-links response.
     * @return One choice per usable link; empty when none is usable.
     */
    static func choices( from response: BookingLinksResponse ) -> [ BookingLinkChoice ]
    {
        let isSplit = response.booking_options.count > 1

        return response.booking_options.flatMap
        { option -> [ BookingLinkChoice ] in
            let legLabel = isSplit ? self.legLabel( for: option ) : nil

            return option.links.compactMap
            { link -> BookingLinkChoice? in
                guard let raw = link.url,
                      let url = self.url( from: raw )
                else
                {
                    return nil
                }

                return BookingLinkChoice(
                    provider: link.provider_name ?? "Booking link",
                    detail: self.detail( fareName: link.fare_name, legLabel: legLabel ),
                    priceLabel: self.priceLabel( link.price ),
                    url: url
                )
            }
        }
    }

    /**
     * Validates a booking URL before anything is opened. Ignav's links are sometimes returned
     * without a scheme, which `URL` would otherwise turn into a relative path.
     *
     * @param raw URL string as returned by the API.
     * @return An http(s) URL with a host, or nil when the string can't be opened.
     */
    static func url( from raw: String ) -> URL?
    {
        let trimmed = raw.trimmingCharacters( in: .whitespacesAndNewlines )
        guard trimmed.isEmpty == false
        else
        {
            return nil
        }

        let candidate = trimmed.contains( "://" ) ? trimmed : "https://\( trimmed )"
        guard let url = URL( string: candidate ),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host,
              host.isEmpty == false
        else
        {
            return nil
        }

        return url
    }

    private static func detail( fareName: String?, legLabel: String? ) -> String?
    {
        let parts = [ legLabel, fareName ].compactMap { $0 }.filter { $0.isEmpty == false }

        return parts.isEmpty ? nil : parts.joined( separator: " · " )
    }

    private static func priceLabel( _ price: Price? ) -> String?
    {
        guard let price,
              price.amount.isFinite
        else
        {
            return nil
        }

        return "\( Int( price.amount )) \( price.currency )"
    }

    /**
     * Names the legs one booking option covers, e.g. "Outbound + return" for a combined purchase
     * or "Outbound" for a leg that must be bought on its own.
     *
     * @param option Booking option to describe.
     * @return A display label, or nil when the option names no legs.
     */
    private static func legLabel( for option: BookingOption ) -> String?
    {
        if let legs = option.legs,
           legs.isEmpty == false
        {
            return self.sentenceCased( legs.map { $0 == "inbound" ? "return" : $0 } )
        }

        if let indexes = option.leg_indexes,
           indexes.isEmpty == false
        {
            return self.sentenceCased( indexes.map { "leg \( $0 + 1 )" } )
        }

        return nil
    }

    private static func sentenceCased( _ names: [ String ] ) -> String
    {
        let joined = names.joined( separator: " + " )

        return joined.prefix( 1 ).uppercased() + joined.dropFirst()
    }
}
