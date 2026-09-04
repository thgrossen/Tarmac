/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftUI

@Observable
final class SearchViewModel
{
    static let apiKeyDefaultsKey = "ignav_api_key"

    @ObservationIgnored private let defaults: UserDefaults

    init( defaults: UserDefaults = .standard )
    {
        self.defaults = defaults
    }

    /**
     * Ignav API key, persisted in user preferences.
     */
    var apiKey: String
    {
        get
        {
            self.access( keyPath: \.apiKey )
            return self.defaults.string( forKey: Self.apiKeyDefaultsKey ) ?? ""
        }
        set
        {
            self.withMutation( keyPath: \.apiKey )
            {
                self.defaults.set( newValue, forKey: Self.apiKeyDefaultsKey )
            }
        }
    }

    var origin = ""
    var destination = ""
    var departure = Date().addingTimeInterval( 60 * 86_400 )
    var returnDate = Date().addingTimeInterval( 63 * 86_400 )
    var cabin = "business"
    var directOnly = true

    var isLoading = false
    var itineraries: [ Itinerary ] = []
    var rawJSON = ""
    var errorMessage: String?

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone( identifier: "UTC" )
        f.locale = Locale( identifier: "en_US_POSIX" )
        return f
    }()

    func search() async
    {
        guard !self.apiKey.isEmpty
        else
        {
            self.errorMessage = "Add your Ignav API key."
            return
        }
        self.isLoading = true
        self.errorMessage = nil
        self.itineraries = []
        self.rawJSON = ""

        let body = RoundTripRequest(
            origin: origin.uppercased(),
            destination: self.destination.uppercased(),
            departure_date: self.fmt.string( from: self.departure ),
            return_date: self.fmt.string( from: self.returnDate ),
            cabin_class: self.cabin,
            max_stops: self.directOnly ? 0 : 2,
            airlines_include: AirlinePreference.currentAirlinesInclude( defaults: self.defaults ),
            market: MarketPreference.currentMarket( defaults: self.defaults )
        )

        do
        {
            let ( result, raw ) = try await IgnavClient( apiKey: apiKey ).roundTrip( body )
            self.itineraries = result.itineraries.sorted { $0.price.amount < $1.price.amount }
            self.rawJSON = raw
            if self.itineraries.isEmpty
            {
                self.errorMessage = "No flights for these filters (request valid… and billed)."
            }
        }
        catch
        {
            self.errorMessage = error.localizedDescription
        }
        self.isLoading = false
    }

    func copyJSON()
    {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString( self.rawJSON, forType: .string )
    }
}
