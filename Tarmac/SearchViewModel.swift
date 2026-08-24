/*******************************************************************************
 * Copyright (c) 2026, DigiDNA
 * All rights reserved
 *
 * Unauthorised copying of this copyrighted work, via any medium is strictly
 * prohibited.
 * Proprietary and confidential.
 ******************************************************************************/

import SwiftUI

@Observable
final class SearchViewModel
{
    private static let apiKeyDefaultsKey = "ignav_api_key"

    /**
     * Clé API Ignav, persistée dans les préférences utilisateur.
     */
    var apiKey: String
    {
        get
        {
            self.access( keyPath: \.apiKey )
            return self.storedAPIKey
        }
        set
        {
            self.withMutation( keyPath: \.apiKey )
            {
                self.storedAPIKey = newValue
                UserDefaults.standard.set( newValue, forKey: Self.apiKeyDefaultsKey )
            }
        }
    }

    @ObservationIgnored     private var storedAPIKey = UserDefaults.standard.string( forKey: SearchViewModel.apiKeyDefaultsKey ) ?? ""

    var origin = "GVA"
    var destination = "LIS"
    var departure = Date().addingTimeInterval( 60 * 86_400 )
    var returnDate = Date().addingTimeInterval( 63 * 86_400 )
    var cabin = "business"
    var directOnly = true
    var onlyLXTP = true

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
            self.errorMessage = "Ajoute ta clé API Ignav."
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
            airlines_include: self.onlyLXTP ? [ "LX", "TP" ] : nil,
            market: "CH"
        )

        do
        {
            let ( result, raw ) = try await IgnavClient( apiKey: apiKey ).roundTrip( body )
            self.itineraries = result.itineraries.sorted { $0.price.amount < $1.price.amount }
            self.rawJSON = raw
            if self.itineraries.isEmpty
            {
                self.errorMessage = "Aucun vol pour ces filtres (requête valide… et facturée)."
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
