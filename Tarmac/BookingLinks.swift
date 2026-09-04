/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

// MARK: - Request

struct BookingLinksRequest: Encodable
{
    var ignav_id: String
}

// MARK: - Response

struct BookingLinksResponse: Decodable
{
    let booking_options: [ BookingOption ]

    enum CodingKeys: String, CodingKey { case booking_options }

    init( from decoder: Decoder ) throws
    {
        let c = try decoder.container( keyedBy: CodingKeys.self )
        self.booking_options = ( try? c.decode( [ BookingOption ].self, forKey: .booking_options ) ) ?? []
    }
}

struct BookingOption: Decodable
{
    let legs: [ String ]?
    let leg_indexes: [ Int ]?
    let links: [ BookingLink ]

    enum CodingKeys: String, CodingKey { case legs, leg_indexes, links }

    init( from decoder: Decoder ) throws
    {
        let c = try decoder.container( keyedBy: CodingKeys.self )
        self.legs        = try? c.decode( [ String ].self, forKey: .legs )
        self.leg_indexes = try? c.decode( [ Int ].self, forKey: .leg_indexes )
        self.links       = ( try? c.decode( [ BookingLink ].self, forKey: .links ) ) ?? []
    }
}

struct BookingLink: Decodable
{
    let provider_name: String?
    let provider_type: String?
    let fare_name: String?
    let price: Price?
    let url: String?

    enum CodingKeys: String, CodingKey { case provider_name, provider_type, fare_name, price, url }

    init( from decoder: Decoder ) throws
    {
        let c = try decoder.container( keyedBy: CodingKeys.self )
        self.provider_name = try? c.decode( String.self, forKey: .provider_name )
        self.provider_type = try? c.decode( String.self, forKey: .provider_type )
        self.fare_name     = try? c.decode( String.self, forKey: .fare_name )
        self.price         = try? c.decode( Price.self, forKey: .price )
        self.url           = try? c.decode( String.self, forKey: .url )
    }
}

// MARK: - Presentation

/**
 * One purchasable offer, ready to show in the booking-link picker: a provider, the fare it sells,
 * its price, and a URL already validated as openable.
 */
struct BookingLinkChoice: Identifiable, Equatable, Codable
{
    let id: String
    let provider: String
    let detail: String?
    let priceLabel: String?
    let url: URL

    init( provider: String, detail: String?, priceLabel: String?, url: URL )
    {
        self.id         = "\( provider )|\( url.absoluteString )"
        self.provider   = provider
        self.detail     = detail
        self.priceLabel = priceLabel
        self.url        = url
    }
}
