/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "SearchViewModel" )
struct SearchViewModelTests
{
    private static func freshDefaults() -> UserDefaults
    {
        UserDefaults( suiteName: "SearchViewModelTests.\( UUID().uuidString )" )!
    }

    @Test( "apiKey round-trips through UserDefaults" )
    func apiKeyRoundTrips()
    {
        let defaults = Self.freshDefaults()
        let vm       = SearchViewModel( defaults: defaults )

        vm.apiKey = "s3cr3t"

        #expect( vm.apiKey == "s3cr3t" )
        #expect( defaults.string( forKey: SearchViewModel.apiKeyDefaultsKey ) == "s3cr3t" )
    }

    @Test( "apiKey reflects a value written externally, e.g. from Preferences" )
    func apiKeyReflectsExternalWrite()
    {
        let defaults = Self.freshDefaults()
        let vm       = SearchViewModel( defaults: defaults )
        #expect( vm.apiKey == "" )

        defaults.set( "written-elsewhere", forKey: SearchViewModel.apiKeyDefaultsKey )

        #expect( vm.apiKey == "written-elsewhere" )
    }
}
