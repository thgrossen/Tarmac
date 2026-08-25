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
}
