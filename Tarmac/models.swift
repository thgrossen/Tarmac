/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

// MARK: - Request

struct RoundTripRequest: Encodable
{
    var origin: String
    var destination: String
    var departure_date: String   // "YYYY-MM-DD"
    var return_date: String
    var cabin_class: String      // economy | premium_economy | business | first
    var max_stops: Int
    var airlines_include: [ String ]?
    var market: String           // "CH" -> CHF
}

struct OneWayRequest: Encodable
{
    var origin: String
    var destination: String
    var departure_date: String   // "YYYY-MM-DD"
    var cabin_class: String      // economy | premium_economy | business | first
    var max_stops: Int
    var airlines_include: [ String ]?
    var market: String           // "CH" -> CHF
}

// MARK: - Response

struct FaresResponse: Decodable
{
    let itineraries: [ Itinerary ]
}

struct Itinerary: Decodable, Identifiable
{
    let ignav_id: String?
    let price: Price
    let outbound: Leg?
    let inbound: Leg?

    var id: String { self.ignav_id ?? UUID().uuidString }
}

struct Price: Decodable
{
    let amount: Double
    let currency: String
    let status: String?

    enum CodingKeys: String, CodingKey { case amount, currency, status }

    // Tolerates an amount returned as a number OR as a string.
    init( from decoder: Decoder ) throws
    {
        let c = try decoder.container( keyedBy: CodingKeys.self )
        if let d = try? c.decode( Double.self, forKey: .amount )
        {
            self.amount = d
        }
        else
        {
            self.amount = Double(( try? c.decode( String.self, forKey: .amount )) ?? "" ) ?? .nan
        }
        self.currency = ( try? c.decode( String.self, forKey: .currency )) ?? "?"
        self.status   = try? c.decode( String.self, forKey: .status )
    }
}

struct Leg: Decodable
{
    let segments: [ Segment ]?
    let duration: String?
}

struct Segment: Decodable
{
    let carrier_code: String?
    let flight_number: String?
    let origin: String?
    let destination: String?
    let departure_time: String?
    let arrival_time: String?
}
