/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import SwiftData
@testable import Tarmac
import Testing

@Suite( "PriceSnapshot" )
struct PriceSnapshotTests
{
    @Test( "Defaults for optional display fields" )
    func defaults()
    {
        let snapshot = PriceSnapshot( amount: 542.0, currency: "CHF" )

        #expect( snapshot.ignavID == nil )
        #expect( snapshot.outboundSummary == nil )
        #expect( snapshot.inboundSummary == nil )
        #expect( snapshot.outboundDuration == nil )
        #expect( snapshot.run == nil )
    }

    @Test( "Stores required and display fields" )
    func storesFields()
    {
        let snapshot = PriceSnapshot(
            amount: 542.0,
            currency: "CHF",
            ignavID: "abc123",
            outboundSummary: "GVA → LIS, LX1234",
            inboundSummary: "LIS → GVA, TP987",
            outboundDuration: "2h35"
        )

        #expect( snapshot.amount == 542.0 )
        #expect( snapshot.currency == "CHF" )
        #expect( snapshot.ignavID == "abc123" )
        #expect( snapshot.outboundSummary == "GVA → LIS, LX1234" )
        #expect( snapshot.inboundSummary == "LIS → GVA, TP987" )
        #expect( snapshot.outboundDuration == "2h35" )
    }
}
