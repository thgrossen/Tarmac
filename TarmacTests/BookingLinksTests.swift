/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData
@testable import Tarmac
import Testing

@Suite( "BookingLinks" )
struct BookingLinksTests
{
    @Test( "Decodes a booking-links response with several providers" )
    func decodesDocumentedResponse() throws
    {
        let json = """
            {
                "itinerary": {
                    "price": { "amount": 488, "currency": "USD", "status": "verified" },
                    "cabin_class": "economy",
                    "requires_self_transfer": false
                },
                "booking_options": [
                    {
                        "legs": [ "outbound" ],
                        "links": [
                            {
                                "provider_name": "American Airlines",
                                "provider_type": "airline",
                                "fare_name": "Main Cabin",
                                "price": { "amount": 488, "currency": "USD", "status": "verified" },
                                "url": "aa.com/booking/abc"
                            },
                            {
                                "provider_name": "Expedia",
                                "provider_type": "third_party",
                                "price": { "amount": 502, "currency": "USD", "status": "verified" },
                                "url": "https://expedia.com/flights/abc"
                            }
                        ]
                    }
                ]
            }
            """.data( using: .utf8 )!

        let decoded = try JSONDecoder().decode( BookingLinksResponse.self, from: json )
        #expect( decoded.booking_options.count == 1 )

        let option = try #require( decoded.booking_options.first )
        #expect( option.legs == [ "outbound" ] )
        #expect( option.links.count == 2 )
        #expect( option.links.first?.provider_name == "American Airlines" )
        #expect( option.links.first?.fare_name == "Main Cabin" )
        #expect( option.links.first?.price?.amount == 488 )
        #expect( option.links.first?.price?.currency == "USD" )
        #expect( option.links.last?.url == "https://expedia.com/flights/abc" )
    }

    @Test( "A link without a fare name or price still decodes" )
    func decodesLinkWithoutOptionalFields() throws
    {
        let json = """
            {
                "booking_options": [
                    { "legs": [ "outbound" ], "links": [ { "provider_name": "SWISS", "url": "swiss.com/x" } ] }
                ]
            }
            """.data( using: .utf8 )!

        let decoded = try JSONDecoder().decode( BookingLinksResponse.self, from: json )
        let link = try #require( decoded.booking_options.first?.links.first )

        #expect( link.provider_name == "SWISS" )
        #expect( link.fare_name == nil )
        #expect( link.price == nil )
        #expect( link.url == "swiss.com/x" )
    }

    @Test( "An empty booking_options array decodes as an empty array, not a failure" )
    func decodesEmptyBookingOptions() throws
    {
        let json = """
            { "itinerary": { "cabin_class": "economy" }, "booking_options": [] }
            """.data( using: .utf8 )!

        let decoded = try JSONDecoder().decode( BookingLinksResponse.self, from: json )
        #expect( decoded.booking_options.isEmpty )
    }

    @Test( "A response missing booking_options entirely decodes as empty" )
    func decodesMissingBookingOptions() throws
    {
        let json = """
            { "itinerary": { "cabin_class": "economy" } }
            """.data( using: .utf8 )!

        let decoded = try JSONDecoder().decode( BookingLinksResponse.self, from: json )
        #expect( decoded.booking_options.isEmpty )
    }

    @Test( "A resolved choice survives a coding round trip" )
    func choiceRoundTripsThroughCoding() throws
    {
        let choice = BookingLinkChoice(
            provider: "SWISS",
            detail: "Economy Light",
            priceLabel: "397 CHF",
            url: URL( string: "https://swiss.com/a" )!
        )

        let decoded = try JSONDecoder().decode( BookingLinkChoice.self, from: try JSONEncoder().encode( choice ) )
        #expect( decoded == choice )
    }

    @Test( "Resolved links are stored on the fare, so they outlive the app session" )
    func resolvedLinksPersistOnTheSnapshot() throws
    {
        let context  = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )
        let snapshot = PriceSnapshot( amount: 397, currency: "CHF", ignavID: "abc123" )
        context.insert( snapshot )

        #expect( snapshot.bookingLinks.isEmpty )

        snapshot.bookingLinks = [
            BookingLinkChoice( provider: "SWISS", detail: nil, priceLabel: "397 CHF", url: URL( string: "https://swiss.com/a" )! )
        ]
        try context.save()

        let fetched = try context.fetch( FetchDescriptor< PriceSnapshot >() )
        #expect( fetched.count == 1 )
        #expect( fetched.first?.bookingLinks.first?.provider == "SWISS" )
        #expect( fetched.first?.bookingLinks.first?.url.absoluteString == "https://swiss.com/a" )
    }
}
