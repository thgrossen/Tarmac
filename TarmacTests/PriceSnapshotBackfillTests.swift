/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData
@testable import Tarmac
import Testing

@Suite( "PriceSnapshotBackfill" )
struct PriceSnapshotBackfillTests
{
    @Test( "Recovers each segment from a multi-segment summary" )
    func recoversMultipleSegments()
    {
        #expect( PriceSnapshotBackfill.flightNumbers( from: "LX 1234 → TP 5678" ) == [ "LX 1234", "TP 5678" ] )
    }

    @Test( "Recovers the single segment of a direct flight" )
    func recoversSingleSegment()
    {
        #expect( PriceSnapshotBackfill.flightNumbers( from: "LX 1234" ) == [ "LX 1234" ] )
    }

    @Test( "A missing or blank summary yields no segments" )
    func recoversNothingFromEmptySummary()
    {
        #expect( PriceSnapshotBackfill.flightNumbers( from: nil ).isEmpty )
        #expect( PriceSnapshotBackfill.flightNumbers( from: "" ).isEmpty )
        #expect( PriceSnapshotBackfill.flightNumbers( from: "   " ).isEmpty )
    }

    @Test( "Fills in the stop count and flight numbers of fares recorded before they were stored" )
    func backfillsExistingFares() throws
    {
        let context = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )

        let direct    = PriceSnapshot( amount: 300, currency: "CHF", outboundSummary: "LX 1234" )
        let connecting = PriceSnapshot( amount: 500, currency: "CHF", outboundSummary: "LX 1234 → TP 5678" )
        context.insert( direct )
        context.insert( connecting )
        try context.save()

        PriceSnapshotBackfill.backfillIfNeeded( in: context )

        #expect( direct.outboundStopCount == 0 )
        #expect( direct.outboundFlightNumbers == [ "LX 1234" ] )
        #expect( connecting.outboundStopCount == 1 )
        #expect( connecting.outboundFlightNumbers == [ "LX 1234", "TP 5678" ] )
    }

    @Test( "A fare with no summary keeps an unknown stop count rather than looking direct" )
    func leavesUnknownFaresAlone() throws
    {
        let context = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )

        let snapshot = PriceSnapshot( amount: 300, currency: "CHF" )
        context.insert( snapshot )
        try context.save()

        PriceSnapshotBackfill.backfillIfNeeded( in: context )

        #expect( snapshot.outboundStopCount == nil )
        #expect( snapshot.outboundFlightNumbers.isEmpty )
    }

    @Test( "Fares that already carry a stop count are left untouched" )
    func skipsAlreadyBackfilledFares() throws
    {
        let context = try TestSupport.makeInMemoryContext( for: SavedSearch.self, SearchRun.self, PriceSnapshot.self )

        let snapshot = PriceSnapshot(
            amount: 300,
            currency: "CHF",
            outboundSummary: "LX 1234 → TP 5678",
            outboundStopCount: 0,
            outboundFlightNumbers: [ "LX 9999" ]
        )
        context.insert( snapshot )
        try context.save()

        PriceSnapshotBackfill.backfillIfNeeded( in: context )

        #expect( snapshot.outboundStopCount == 0 )
        #expect( snapshot.outboundFlightNumbers == [ "LX 9999" ] )
    }
}
