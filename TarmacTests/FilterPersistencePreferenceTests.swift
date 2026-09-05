/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData
@testable import Tarmac
import Testing

@Suite( "FilterPersistencePreference" )
struct FilterPersistencePreferenceTests
{
    private static func freshDefaults() -> UserDefaults
    {
        UserDefaults( suiteName: "FilterPersistencePreferenceTests.\( UUID().uuidString )" )!
    }

    private static func utcDate( _ year: Int, _ month: Int, _ day: Int ) -> Date
    {
        var calendar = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!

        return calendar.date( from: DateComponents( year: year, month: month, day: day ) )!
    }

    private static func makeFilteredSearch( in context: ModelContext, kind: SearchKind = .oneWay ) -> SavedSearch
    {
        let search = SavedSearch(
            kind: kind,
            origin: "GVA",
            destination: "LIS",
            rangeStart: self.utcDate( 2026, 10, 5 ),
            rangeEnd: self.utcDate( 2026, 10, 12 ),
            cabinClass: "economy"
        )
        search.resultFilters = ResultFilters( maxPrice: 400 )
        context.insert( search )

        return search
    }

    @Test( "Filters are cleared on launch by default" )
    func filtersAreClearedByDefault() throws
    {
        let context = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )
        let search  = Self.makeFilteredSearch( in: context )

        #expect( FilterPersistencePreference.keepsOnLaunch( defaults: Self.freshDefaults() ) == false )

        FilterPersistencePreference.clearFiltersIfNeeded( in: context, defaults: Self.freshDefaults() )
        #expect( search.resultFilters == nil )
    }

    @Test( "A round trip's filters are cleared and kept on the same terms as a one-way search's" )
    func roundTripFiltersFollowTheSamePreference() throws
    {
        let context   = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )
        let roundTrip = Self.makeFilteredSearch( in: context, kind: .roundTrip )

        FilterPersistencePreference.clearFiltersIfNeeded( in: context, defaults: Self.freshDefaults() )
        #expect( roundTrip.resultFilters == nil )

        let defaults = Self.freshDefaults()
        defaults.set( true, forKey: FilterPersistencePreference.keepOnLaunchDefaultsKey )
        roundTrip.resultFilters = ResultFilters( maxPrice: 400 )

        FilterPersistencePreference.clearFiltersIfNeeded( in: context, defaults: defaults )
        #expect( roundTrip.resultFilters != nil )
    }

    @Test( "Filters survive a launch once the preference is turned on" )
    func filtersAreKeptWhenPreferred() throws
    {
        let defaults = Self.freshDefaults()
        defaults.set( true, forKey: FilterPersistencePreference.keepOnLaunchDefaultsKey )

        let context = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )
        let search  = Self.makeFilteredSearch( in: context )

        #expect( FilterPersistencePreference.keepsOnLaunch( defaults: defaults ) )

        FilterPersistencePreference.clearFiltersIfNeeded( in: context, defaults: defaults )
        #expect( search.resultFilters != nil )
    }

    @Test( "Explicitly turning the preference off clears filters again" )
    func filtersAreClearedWhenPreferenceIsOff() throws
    {
        let defaults = Self.freshDefaults()
        defaults.set( false, forKey: FilterPersistencePreference.keepOnLaunchDefaultsKey )

        let context = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )
        let search  = Self.makeFilteredSearch( in: context )

        FilterPersistencePreference.clearFiltersIfNeeded( in: context, defaults: defaults )
        #expect( search.resultFilters == nil )
    }
}
