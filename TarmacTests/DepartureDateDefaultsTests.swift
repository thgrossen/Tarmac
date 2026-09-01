/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "DepartureDateDefaults" )
struct DepartureDateDefaultsTests
{
    private static func utcDate( _ year: Int, _ month: Int, _ day: Int, hour: Int = 0 ) -> Date
    {
        var calendar    = Calendar( identifier: .gregorian )
        calendar.timeZone = TimeZone( identifier: "UTC" )!
        let components  = DateComponents( year: year, month: month, day: day, hour: hour )
        return calendar.date( from: components )!
    }

    @Test( "Earliest departure is midnight UTC the day after the reference date" )
    func earliestDepartureIsTomorrow()
    {
        let reference = Self.utcDate( 2026, 10, 5, hour: 14 )
        let earliest  = DepartureDateDefaults.earliestDeparture( referenceDate: reference )

        #expect( earliest == Self.utcDate( 2026, 10, 6 ) )
    }

    @Test( "Earliest departure crosses a month boundary correctly" )
    func earliestDepartureCrossesMonthBoundary()
    {
        let reference = Self.utcDate( 2026, 10, 31, hour: 23 )
        let earliest  = DepartureDateDefaults.earliestDeparture( referenceDate: reference )

        #expect( earliest == Self.utcDate( 2026, 11, 1 ) )
    }

    @Test( "Default range is a 1-day window starting tomorrow" )
    func defaultRangeIsOneDayFromTomorrow()
    {
        let reference = Self.utcDate( 2026, 10, 5, hour: 9 )
        let range     = DepartureDateDefaults.defaultRange( referenceDate: reference )

        #expect( range.start == Self.utcDate( 2026, 10, 6 ) )
        #expect( range.end == Self.utcDate( 2026, 10, 7 ) )
    }

    @Test( "Clamping leaves an already-valid range unchanged" )
    func clampingLeavesValidRangeUnchanged()
    {
        let reference = Self.utcDate( 2026, 10, 5 )
        let range     = SearchDateSession.DateRange( start: Self.utcDate( 2026, 10, 20 ), end: Self.utcDate( 2026, 10, 25 ) )

        let clamped = DepartureDateDefaults.clamped( range, referenceDate: reference )
        #expect( clamped == range )
    }

    @Test( "Clamping pulls a stale start forward to the earliest selectable date" )
    func clampingPullsStaleStartForward()
    {
        let reference = Self.utcDate( 2026, 10, 5 )
        let stale     = SearchDateSession.DateRange( start: Self.utcDate( 2026, 9, 1 ), end: Self.utcDate( 2026, 9, 2 ) )

        let clamped = DepartureDateDefaults.clamped( stale, referenceDate: reference )
        #expect( clamped.start == Self.utcDate( 2026, 10, 6 ) )
        #expect( clamped.end == Self.utcDate( 2026, 10, 6 ) )
    }

    @Test( "Clamping never produces an end before the (possibly adjusted) start" )
    func clampingKeepsEndAtOrAfterStart()
    {
        let reference = Self.utcDate( 2026, 10, 5 )
        let inverted  = SearchDateSession.DateRange( start: Self.utcDate( 2026, 10, 20 ), end: Self.utcDate( 2026, 10, 10 ) )

        let clamped = DepartureDateDefaults.clamped( inverted, referenceDate: reference )
        #expect( clamped.start == Self.utcDate( 2026, 10, 20 ) )
        #expect( clamped.end == Self.utcDate( 2026, 10, 20 ) )
    }
}
