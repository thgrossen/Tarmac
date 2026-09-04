/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "BookingLinkFetcher" )
struct BookingLinkFetcherTests
{
    private struct StubError: LocalizedError
    {
        var errorDescription: String? { "stub network failure" }
    }

    private static func response( options json: String ) throws -> ( BookingLinksResponse, String )
    {
        let data     = "{ \"booking_options\": [ \( json ) ] }".data( using: .utf8 )!
        let response = try JSONDecoder().decode( BookingLinksResponse.self, from: data )

        return ( response, String( data: data, encoding: .utf8 )! )
    }

    // MARK: - URL validation

    @Test( "An absolute https URL passes through unchanged" )
    func acceptsAbsoluteURL() throws
    {
        let url = try #require( BookingLinkFetcher.url( from: "https://aa.com/booking/x?a=1" ) )
        #expect( url.absoluteString == "https://aa.com/booking/x?a=1" )
    }

    @Test( "A scheme-less URL is upgraded to https" )
    func upgradesSchemeLessURL() throws
    {
        let url = try #require( BookingLinkFetcher.url( from: " aa.com/booking/x " ) )
        #expect( url.absoluteString == "https://aa.com/booking/x" )
    }

    @Test( "A non-web or empty URL is rejected" )
    func rejectsUnusableURLs()
    {
        #expect( BookingLinkFetcher.url( from: "javascript:alert(1)" ) == nil )
        #expect( BookingLinkFetcher.url( from: "ftp://files.example.com/x" ) == nil )
        #expect( BookingLinkFetcher.url( from: "" ) == nil )
        #expect( BookingLinkFetcher.url( from: "   " ) == nil )
    }

    // MARK: - Choices

    @Test( "A single option keeps the API's order and carries no leg label" )
    func choicesFromSingleOption() throws
    {
        let ( response, _ ) = try Self.response( options: """
            {
                "legs": [ "outbound" ],
                "links": [
                    { "provider_name": "SWISS", "fare_name": "Economy Light",
                      "price": { "amount": 397, "currency": "CHF" }, "url": "swiss.com/a" },
                    { "provider_name": "Expedia",
                      "price": { "amount": 412, "currency": "CHF" }, "url": "https://expedia.com/b" }
                ]
            }
            """ )

        let choices = BookingLinkFetcher.choices( from: response )
        #expect( choices.count == 2 )
        #expect( choices[ 0 ].provider == "SWISS" )
        #expect( choices[ 0 ].detail == "Economy Light" )
        #expect( choices[ 0 ].priceLabel == "397 CHF" )
        #expect( choices[ 0 ].url.absoluteString == "https://swiss.com/a" )
        #expect( choices[ 1 ].provider == "Expedia" )
        #expect( choices[ 1 ].detail == nil )
        #expect( choices[ 1 ].priceLabel == "412 CHF" )
    }

    @Test( "Split options label each choice with the legs it covers" )
    func choicesFromSplitOptions() throws
    {
        let ( response, _ ) = try Self.response( options: """
            { "legs": [ "outbound" ], "links": [ { "provider_name": "SWISS", "url": "swiss.com/out" } ] },
            { "legs": [ "inbound" ], "links": [ { "provider_name": "SWISS", "fare_name": "Economy", "url": "swiss.com/in" } ] }
            """ )

        let choices = BookingLinkFetcher.choices( from: response )
        #expect( choices.count == 2 )
        #expect( choices[ 0 ].detail == "Outbound" )
        #expect( choices[ 1 ].detail == "Return · Economy" )
    }

    @Test( "Links with an unusable URL are dropped" )
    func choicesDropUnusableLinks() throws
    {
        let ( response, _ ) = try Self.response( options: """
            {
                "legs": [ "outbound" ],
                "links": [
                    { "provider_name": "Broken", "url": "javascript:alert(1)" },
                    { "provider_name": "Missing" },
                    { "provider_name": "SWISS", "url": "swiss.com/a" }
                ]
            }
            """ )

        let choices = BookingLinkFetcher.choices( from: response )
        #expect( choices.count == 1 )
        #expect( choices[ 0 ].provider == "SWISS" )
    }

    // MARK: - Outcomes

    @Test( "A response with one usable link yields that link" )
    func outcomeWithOneLink() async throws
    {
        let stub = try Self.response( options: """
            { "legs": [ "outbound" ], "links": [ { "provider_name": "SWISS", "url": "swiss.com/a" } ] }
            """ )

        let outcome = await BookingLinkFetcher.links( forIgnavID: "abc123", apiKey: "k", fetch: { request in
            #expect( request.ignav_id == "abc123" )
            return stub
        } )

        guard case .links( let choices ) = outcome
        else
        {
            Issue.record( "expected .links, got \( outcome )" )
            return
        }
        #expect( choices.count == 1 )
    }

    @Test( "An empty booking_options array reports that no link is available" )
    func outcomeWithNoOptions() async throws
    {
        let data     = "{ \"booking_options\": [] }".data( using: .utf8 )!
        let response = try JSONDecoder().decode( BookingLinksResponse.self, from: data )

        let outcome = await BookingLinkFetcher.links( forIgnavID: "abc123", apiKey: "k", fetch: { _ in
            ( response, "" )
        } )

        #expect( outcome == .noneAvailable )
    }

    @Test( "An expired handoff token reports expiry, carrying the API's own message" )
    func outcomeWithExpiredToken() async
    {
        let outcome = await BookingLinkFetcher.links( forIgnavID: "abc123", apiKey: "k", fetch: { _ in
            throw IgnavError.api( status: 404, code: "ignav_id_not_found", message: "The ignav_id was not found." )
        } )

        #expect( outcome == .expired( "The ignav_id was not found." ) )
    }

    @Test( "An unresolvable itinerary is treated as expiry too" )
    func outcomeWithMissingItinerary() async
    {
        let outcome = await BookingLinkFetcher.links( forIgnavID: "abc123", apiKey: "k", fetch: { _ in
            throw IgnavError.api( status: 404, code: "itinerary_not_found", message: "Could not find the specified itinerary." )
        } )

        #expect( outcome == .expired( "Could not find the specified itinerary." ) )
    }

    @Test( "Any other error is reported with its message" )
    func outcomeWithOtherError() async
    {
        let billing = await BookingLinkFetcher.links( forIgnavID: "abc123", apiKey: "k", fetch: { _ in
            throw IgnavError.api( status: 402, code: "billing_required", message: "Billing setup is required." )
        } )
        #expect( billing == .failure( "Billing setup is required." ) )

        let network = await BookingLinkFetcher.links( forIgnavID: "abc123", apiKey: "k", fetch: { _ in
            throw StubError()
        } )
        #expect( network == .failure( "stub network failure" ) )
    }
}
