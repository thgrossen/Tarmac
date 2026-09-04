/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "BookingLinkAvailability" )
struct BookingLinkAvailabilityTests
{
    private static let now = Date( timeIntervalSince1970: 1_800_000_000 )

    private static func freshDefaults() -> UserDefaults
    {
        UserDefaults( suiteName: "BookingLinkAvailabilityTests.\( UUID().uuidString )" )!
    }

    private static func utcDate( _ year: Int, _ month: Int, _ day: Int ) -> Date
    {
        var calendar = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!

        return calendar.date( from: DateComponents( year: year, month: month, day: day ) )!
    }

    private static func makeOneWaySearch() -> SavedSearch
    {
        SavedSearch(
            kind: .oneWay,
            origin: "GVA",
            destination: "LIS",
            rangeStart: self.utcDate( 2026, 10, 5 ),
            rangeEnd: self.utcDate( 2026, 10, 5 ),
            cabinClass: "economy"
        )
    }

    @discardableResult
    private static func addRun( to search: SavedSearch, runAt: Date, ignavID: String? = "abc123" ) -> SearchRun
    {
        let run = SearchRun( runAt: runAt, requestCount: 1, savedSearch: search )
        run.itineraries = [ PriceSnapshot( amount: 397, currency: "CHF", ignavID: ignavID, run: run ) ]
        search.runs.append( run )

        return run
    }

    @Test( "The newest run's fresh results are bookable" )
    func newestFreshRunIsAvailable() throws
    {
        let search   = Self.makeOneWaySearch()
        let run      = Self.addRun( to: search, runAt: Self.now.addingTimeInterval( -3600 ) )
        let snapshot = try #require( run.itineraries.first )

        #expect( BookingLinkAvailability.availability( for: snapshot, now: Self.now, defaults: Self.freshDefaults() ) == .available )
        #expect( BookingLinkAvailability.unavailableReason( .available ) == nil )
    }

    @Test( "Updating a search makes the previous run's results unbookable" )
    func earlierRunIsSuperseded() throws
    {
        let search   = Self.makeOneWaySearch()
        let older    = Self.addRun( to: search, runAt: Self.now.addingTimeInterval( -3600 ) )
        Self.addRun( to: search, runAt: Self.now )
        let snapshot = try #require( older.itineraries.first )

        #expect( BookingLinkAvailability.availability( for: snapshot, now: Self.now, defaults: Self.freshDefaults() ) == .superseded )
        #expect( BookingLinkAvailability.unavailableReason( .superseded ) != nil )
    }

    @Test( "The newest run stops being bookable once it passes the configured lifetime" )
    func oldRunExpiresByAge() throws
    {
        let search   = Self.makeOneWaySearch()
        let run      = Self.addRun( to: search, runAt: Self.now.addingTimeInterval( -25 * 3600 ) )
        let snapshot = try #require( run.itineraries.first )

        #expect( BookingLinkAvailability.availability( for: snapshot, now: Self.now, defaults: Self.freshDefaults() ) == .expiredByAge )
        #expect( BookingLinkAvailability.unavailableReason( .expiredByAge ) != nil )
    }

    @Test( "A run exactly at the configured lifetime is already expired" )
    func runAtTheAgeBoundaryExpires() throws
    {
        let defaults = Self.freshDefaults()
        let search   = Self.makeOneWaySearch()
        let run      = Self.addRun( to: search, runAt: Self.now.addingTimeInterval( -24 * 3600 ) )
        let snapshot = try #require( run.itineraries.first )

        #expect( BookingLinkAvailability.availability( for: snapshot, now: Self.now, defaults: defaults ) == .expiredByAge )
    }

    @Test( "Shortening the lifetime preference expires a run that a longer one would still allow" )
    func shorterLifetimeExpiresRunSooner() throws
    {
        let defaults = Self.freshDefaults()
        let search   = Self.makeOneWaySearch()
        let run      = Self.addRun( to: search, runAt: Self.now.addingTimeInterval( -4 * 3600 ) )
        let snapshot = try #require( run.itineraries.first )

        #expect( BookingLinkAvailability.availability( for: snapshot, now: Self.now, defaults: defaults ) == .available )

        defaults.set( 3, forKey: BookingLinkExpiryPreference.maxRunAgeHoursDefaultsKey )
        #expect( BookingLinkAvailability.availability( for: snapshot, now: Self.now, defaults: defaults ) == .expiredByAge )
    }

    @Test( "A result without a handoff token is never bookable" )
    func resultWithoutIgnavIDIsUnavailable() throws
    {
        let search   = Self.makeOneWaySearch()
        let run      = Self.addRun( to: search, runAt: Self.now, ignavID: nil )
        let snapshot = try #require( run.itineraries.first )

        #expect( BookingLinkAvailability.availability( for: snapshot, now: Self.now, defaults: Self.freshDefaults() ) == .missingID )
        #expect( BookingLinkAvailability.unavailableReason( .missingID ) != nil )
    }

    @Test( "An empty handoff token counts as missing" )
    func resultWithEmptyIgnavIDIsUnavailable() throws
    {
        let search   = Self.makeOneWaySearch()
        let run      = Self.addRun( to: search, runAt: Self.now, ignavID: "" )
        let snapshot = try #require( run.itineraries.first )

        #expect( BookingLinkAvailability.availability( for: snapshot, now: Self.now, defaults: Self.freshDefaults() ) == .missingID )
    }
}
