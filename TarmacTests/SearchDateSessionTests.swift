/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "SearchDateSession" )
struct SearchDateSessionTests
{
    @Test( "A kind with no recorded range returns nil" )
    func defaultsToNil()
    {
        let session = SearchDateSession()

        #expect( session.range( for: .oneWay ) == nil )
        #expect( session.range( for: .roundTrip ) == nil )
    }

    @Test( "Recording a range makes it available for that kind" )
    func recordsRange()
    {
        let session = SearchDateSession()
        let range   = SearchDateSession.DateRange( start: .now, end: .now.addingTimeInterval( 86_400 ) )

        session.recordRange( range, for: .oneWay )

        #expect( session.range( for: .oneWay ) == range )
    }

    @Test( "Recording a range for one kind doesn't affect the other kind" )
    func tracksKindsIndependently()
    {
        let session   = SearchDateSession()
        let oneWay    = SearchDateSession.DateRange( start: .now, end: .now.addingTimeInterval( 86_400 ) )
        let roundTrip = SearchDateSession.DateRange( start: .now.addingTimeInterval( 172_800 ), end: .now.addingTimeInterval( 259_200 ) )

        session.recordRange( oneWay, for: .oneWay )

        #expect( session.range( for: .oneWay ) == oneWay )
        #expect( session.range( for: .roundTrip ) == nil )

        session.recordRange( roundTrip, for: .roundTrip )

        #expect( session.range( for: .oneWay ) == oneWay )
        #expect( session.range( for: .roundTrip ) == roundTrip )
    }

    @Test( "Recording a new range for a kind replaces the previous one" )
    func replacesPreviousRange()
    {
        let session = SearchDateSession()
        let first   = SearchDateSession.DateRange( start: .now, end: .now.addingTimeInterval( 86_400 ) )
        let second  = SearchDateSession.DateRange( start: .now.addingTimeInterval( 172_800 ), end: .now.addingTimeInterval( 259_200 ) )

        session.recordRange( first, for: .oneWay )
        session.recordRange( second, for: .oneWay )

        #expect( session.range( for: .oneWay ) == second )
    }
}
