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
    var min_carry_on_bags: Int?
    var min_checked_bags: Int?
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
    var min_carry_on_bags: Int?
    var min_checked_bags: Int?
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
    let carrier: String?
    let segments: [ Segment ]?
    let duration: String?

    enum CodingKeys: String, CodingKey { case carrier, segments, duration_minutes }

    init( from decoder: Decoder ) throws
    {
        let c = try decoder.container( keyedBy: CodingKeys.self )
        self.carrier  = try? c.decode( String.self, forKey: .carrier )
        self.segments = try? c.decode( [ Segment ].self, forKey: .segments )
        self.duration = ( try? c.decode( Int.self, forKey: .duration_minutes ) ).map( Self.formatDuration )
    }

    private static func formatDuration( _ minutes: Int ) -> String
    {
        "\( minutes / 60 )h\( String( format: "%02d", minutes % 60 ) )"
    }
}

struct Segment: Decodable
{
    let carrier_code: String?
    let marketing_carrier_code: String?
    let flight_number: String?
    let origin: String?
    let destination: String?
    let departure_time: String?
    let arrival_time: String?
    let departure_date: Date?

    enum CodingKeys: String, CodingKey
    {
        case carrier_code
        case marketing_carrier_code
        case flight_number
        case origin
        case destination
        case departure_time = "departure_time_local"
        case arrival_time = "arrival_time_local"
    }

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale( identifier: "en_US_POSIX" )
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale( identifier: "en_US_POSIX" )
        return f
    }()

    init( from decoder: Decoder ) throws
    {
        let c = try decoder.container( keyedBy: CodingKeys.self )
        self.carrier_code   = try? c.decode( String.self, forKey: .carrier_code )
        self.marketing_carrier_code = try? c.decode( String.self, forKey: .marketing_carrier_code )
        self.flight_number  = try? c.decode( String.self, forKey: .flight_number )
        self.origin         = try? c.decode( String.self, forKey: .origin )
        self.destination    = try? c.decode( String.self, forKey: .destination )

        let departureDate   = Self.parseDate( try? c.decode( String.self, forKey: .departure_time ) )
        self.departure_time = Self.formatTime( departureDate )
        self.departure_date = departureDate
        self.arrival_time   = Self.formatTime( Self.parseDate( try? c.decode( String.self, forKey: .arrival_time ) ) )
    }

    private static func parseDate( _ raw: String? ) -> Date?
    {
        guard let raw
        else
        {
            return nil
        }
        return Self.isoFormatter.date( from: raw )
    }

    private static func formatTime( _ date: Date? ) -> String?
    {
        guard let date
        else
        {
            return nil
        }
        return Self.timeFormatter.string( from: date )
    }
}
