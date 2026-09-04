/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "RefreshState" )
struct RefreshStateTests
{
    @Test( "A search isn't loading and has no error before any refresh" )
    func defaults()
    {
        let state = RefreshState()
        let id    = UUID()

        #expect( state.isLoading( id ) == false )
        #expect( state.errorMessage( for: id ) == nil )
    }

    @Test( "beginRefresh marks a search as loading and clears any prior error" )
    func beginRefreshStartsLoading()
    {
        let state = RefreshState()
        let id    = UUID()
        state.setError( "boom", for: id )

        let started = state.beginRefresh( for: id )

        #expect( started )
        #expect( state.isLoading( id ) )
        #expect( state.errorMessage( for: id ) == nil )
    }

    @Test( "beginRefresh refuses to start a second refresh for a search already in flight" )
    func beginRefreshRefusesDuplicate()
    {
        let state = RefreshState()
        let id    = UUID()

        #expect( state.beginRefresh( for: id ) )
        #expect( state.beginRefresh( for: id ) == false )
        #expect( state.isLoading( id ) )
    }

    @Test( "endRefresh clears loading and records the outcome's error message" )
    func endRefreshStoresError()
    {
        let state = RefreshState()
        let id    = UUID()
        _ = state.beginRefresh( for: id )

        state.endRefresh( for: id, errorMessage: "no flights" )

        #expect( state.isLoading( id ) == false )
        #expect( state.errorMessage( for: id ) == "no flights" )
    }

    @Test( "endRefresh with a nil error clears any previous error" )
    func endRefreshClearsError()
    {
        let state = RefreshState()
        let id    = UUID()
        _ = state.beginRefresh( for: id )
        state.endRefresh( for: id, errorMessage: "first failure" )

        _ = state.beginRefresh( for: id )
        state.endRefresh( for: id, errorMessage: nil )

        #expect( state.errorMessage( for: id ) == nil )
    }

    @Test( "Different searches track loading and errors independently" )
    func tracksSearchesIndependently()
    {
        let state = RefreshState()
        let a      = UUID()
        let b      = UUID()

        _ = state.beginRefresh( for: a )
        state.setError( "b failed", for: b )

        #expect( state.isLoading( a ) )
        #expect( state.isLoading( b ) == false )
        #expect( state.errorMessage( for: a ) == nil )
        #expect( state.errorMessage( for: b ) == "b failed" )
    }

    @Test( "beginRefresh after a prior run has ended is allowed again" )
    func allowsRefreshAfterCompletion()
    {
        let state = RefreshState()
        let id    = UUID()
        _ = state.beginRefresh( for: id )
        state.endRefresh( for: id, errorMessage: nil )

        #expect( state.beginRefresh( for: id ) )
    }

    // MARK: - Progress

    @Test( "A search has no progress before any refresh" )
    func progressDefaultsToNothing()
    {
        let state = RefreshState()
        let id    = UUID()

        #expect( state.progress( for: id ) == nil )
    }

    @Test( "Progress reported during a refresh is visible" )
    func recordsProgressWhileLoading()
    {
        let state = RefreshState()
        let id    = UUID()
        _ = state.beginRefresh( for: id )

        state.updateProgress( SearchProgress( completed: 0, total: 24 ), for: id )
        state.updateProgress( SearchProgress( completed: 7, total: 24 ), for: id )

        #expect( state.progress( for: id ) == SearchProgress( completed: 7, total: 24 ) )
    }

    @Test( "Progress reported for a search that isn't refreshing is dropped" )
    func ignoresProgressWhenNotLoading()
    {
        let state = RefreshState()
        let id    = UUID()

        state.updateProgress( SearchProgress( completed: 7, total: 24 ), for: id )

        #expect( state.progress( for: id ) == nil )
    }

    @Test( "A late emission can't resurrect a finished refresh's progress" )
    func ignoresProgressAfterEndRefresh()
    {
        let state = RefreshState()
        let id    = UUID()
        _ = state.beginRefresh( for: id )
        state.updateProgress( SearchProgress( completed: 7, total: 24 ), for: id )
        state.endRefresh( for: id, errorMessage: nil )

        state.updateProgress( SearchProgress( completed: 8, total: 24 ), for: id )

        #expect( state.progress( for: id ) == nil )
    }

    @Test( "Progress never walks backwards within a sweep" )
    func ignoresProgressThatGoesBackwards()
    {
        let state = RefreshState()
        let id    = UUID()
        _ = state.beginRefresh( for: id )
        state.updateProgress( SearchProgress( completed: 7, total: 24 ), for: id )

        state.updateProgress( SearchProgress( completed: 3, total: 24 ), for: id )

        #expect( state.progress( for: id ) == SearchProgress( completed: 7, total: 24 ) )

        // Rejecting one emission doesn't wedge the search — the next one forward still lands.
        state.updateProgress( SearchProgress( completed: 9, total: 24 ), for: id )

        #expect( state.progress( for: id ) == SearchProgress( completed: 9, total: 24 ) )
    }

    @Test( "endRefresh drops the search's progress" )
    func endRefreshClearsProgress()
    {
        let state = RefreshState()
        let id    = UUID()
        _ = state.beginRefresh( for: id )
        state.updateProgress( SearchProgress( completed: 24, total: 24 ), for: id )

        state.endRefresh( for: id, errorMessage: nil )

        #expect( state.progress( for: id ) == nil )
    }

    @Test( "A failed refresh drops its progress too" )
    func endRefreshWithErrorClearsProgress()
    {
        let state = RefreshState()
        let id    = UUID()
        _ = state.beginRefresh( for: id )
        state.updateProgress( SearchProgress( completed: 2, total: 24 ), for: id )

        state.endRefresh( for: id, errorMessage: "Add your Ignav API key." )

        #expect( state.progress( for: id ) == nil )
        #expect( state.errorMessage( for: id ) == "Add your Ignav API key." )
    }

    @Test( "A new refresh starts from no progress" )
    func beginRefreshClearsStaleProgress()
    {
        let state = RefreshState()
        let id    = UUID()
        _ = state.beginRefresh( for: id )
        state.updateProgress( SearchProgress( completed: 24, total: 24 ), for: id )
        state.endRefresh( for: id, errorMessage: nil )

        _ = state.beginRefresh( for: id )

        #expect( state.progress( for: id ) == nil )
        state.updateProgress( SearchProgress( completed: 1, total: 5 ), for: id )
        #expect( state.progress( for: id ) == SearchProgress( completed: 1, total: 5 ) )
    }

    @Test( "Different searches track progress independently" )
    func tracksProgressIndependently()
    {
        let state = RefreshState()
        let a     = UUID()
        let b     = UUID()
        _ = state.beginRefresh( for: a )
        _ = state.beginRefresh( for: b )

        state.updateProgress( SearchProgress( completed: 7, total: 24 ), for: a )
        state.updateProgress( SearchProgress( completed: 2, total: 3 ), for: b )

        #expect( state.progress( for: a ) == SearchProgress( completed: 7, total: 24 ) )
        #expect( state.progress( for: b ) == SearchProgress( completed: 2, total: 3 ) )
    }

    @Test( "One search finishing doesn't stop another one still sweeping" )
    func oneSearchEndingLeavesTheOtherReporting()
    {
        let state = RefreshState()
        let a     = UUID()
        let b     = UUID()
        _ = state.beginRefresh( for: a )
        _ = state.beginRefresh( for: b )
        state.updateProgress( SearchProgress( completed: 1, total: 24 ), for: a )

        state.endRefresh( for: a, errorMessage: nil )
        state.updateProgress( SearchProgress( completed: 2, total: 24 ), for: a )
        state.updateProgress( SearchProgress( completed: 5, total: 24 ), for: b )

        #expect( state.progress( for: a ) == nil )
        #expect( state.progress( for: b ) == SearchProgress( completed: 5, total: 24 ) )
    }
}
