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
    // Built against `Calendar.current`, because `tripDurationDays` normalises in that same zone.
    private static func localDate( _ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0 ) -> Date
    {
        let components = DateComponents( year: year, month: month, day: day, hour: hour, minute: minute )
        return Calendar.current.date( from: components )!
    }

    private static func roundTrip( outbound: Date?, inbound: Date? ) -> PriceSnapshot
    {
        PriceSnapshot(
            amount: 397.0,
            currency: "CHF",
            departureDate: outbound,
            inboundDepartureDate: inbound
        )
    }

    @Test( "Defaults for optional display fields" )
    func defaults()
    {
        let snapshot = PriceSnapshot( amount: 542.0, currency: "CHF" )

        #expect( snapshot.ignavID == nil )
        #expect( snapshot.outboundSummary == nil )
        #expect( snapshot.inboundSummary == nil )
        #expect( snapshot.outboundDuration == nil )
        #expect( snapshot.carrier == nil )
        #expect( snapshot.departureTime == nil )
        #expect( snapshot.arrivalTime == nil )
        #expect( snapshot.departureDate == nil )
        #expect( snapshot.run == nil )
    }

    @Test( "Stores required and display fields" )
    func storesFields()
    {
        let departureDate = Date( timeIntervalSince1970: 1_759_000_200 )     // 2025-09-27T19:10:00Z
        let snapshot = PriceSnapshot(
            amount: 542.0,
            currency: "CHF",
            ignavID: "abc123",
            outboundSummary: "GVA → LIS, LX1234",
            inboundSummary: "LIS → GVA, TP987",
            outboundDuration: "2h35",
            carrier: "SWISS",
            departureTime: "14:30",
            arrivalTime: "17:55",
            departureDate: departureDate
        )

        #expect( snapshot.amount == 542.0 )
        #expect( snapshot.currency == "CHF" )
        #expect( snapshot.ignavID == "abc123" )
        #expect( snapshot.outboundSummary == "GVA → LIS, LX1234" )
        #expect( snapshot.inboundSummary == "LIS → GVA, TP987" )
        #expect( snapshot.outboundDuration == "2h35" )
        #expect( snapshot.carrier == "SWISS" )
        #expect( snapshot.departureTime == "14:30" )
        #expect( snapshot.arrivalTime == "17:55" )
        #expect( snapshot.departureDate == departureDate )
    }

    @Test( "Formatted amount for a finite price" )
    func formattedAmountFinite()
    {
        let snapshot = PriceSnapshot( amount: 397.0, currency: "CHF" )

        #expect( snapshot.formattedAmount == "397 CHF" )
    }

    @Test( "Formatted amount is nil for a non-finite price" )
    func formattedAmountNonFinite()
    {
        let snapshot = PriceSnapshot( amount: .nan, currency: "CHF" )

        #expect( snapshot.formattedAmount == nil )
    }

    @Test( "Trip duration counts the nights between the two departures" )
    func tripDurationMultiDay()
    {
        let snapshot = Self.roundTrip(
            outbound: Self.localDate( 2026, 10, 5 ),
            inbound: Self.localDate( 2026, 10, 8 )
        )

        #expect( snapshot.tripDurationDays == 3 )
    }

    @Test( "Trip duration is 0 for a same-day return" )
    func tripDurationSameDay()
    {
        let snapshot = Self.roundTrip(
            outbound: Self.localDate( 2026, 10, 5, hour: 6, minute: 40 ),
            inbound: Self.localDate( 2026, 10, 5, hour: 19, minute: 15 )
        )

        #expect( snapshot.tripDurationDays == 0 )
    }

    @Test( "Trip duration ignores the time of day, early outbound to late inbound" )
    func tripDurationIgnoresTimeOfDayEarlyToLate()
    {
        let snapshot = Self.roundTrip(
            outbound: Self.localDate( 2026, 10, 5, hour: 6, minute: 40 ),
            inbound: Self.localDate( 2026, 10, 8, hour: 19, minute: 15 )
        )

        #expect( snapshot.tripDurationDays == 3 )
    }

    @Test( "Trip duration ignores the time of day, late outbound to early inbound" )
    func tripDurationIgnoresTimeOfDayLateToEarly()
    {
        let snapshot = Self.roundTrip(
            outbound: Self.localDate( 2026, 10, 5, hour: 19, minute: 15 ),
            inbound: Self.localDate( 2026, 10, 8, hour: 6, minute: 40 )
        )

        #expect( snapshot.tripDurationDays == 3 )
    }

    @Test( "Trip duration is nil without an inbound date" )
    func tripDurationMissingInbound()
    {
        let snapshot = Self.roundTrip( outbound: Self.localDate( 2026, 10, 5 ), inbound: nil )

        #expect( snapshot.tripDurationDays == nil )
    }

    @Test( "Trip duration is nil without an outbound date" )
    func tripDurationMissingOutbound()
    {
        let snapshot = Self.roundTrip( outbound: nil, inbound: Self.localDate( 2026, 10, 8 ) )

        #expect( snapshot.tripDurationDays == nil )
    }

    @Test( "Trip duration is nil without either date" )
    func tripDurationMissingBoth()
    {
        let snapshot = Self.roundTrip( outbound: nil, inbound: nil )

        #expect( snapshot.tripDurationDays == nil )
    }

    @Test( "Trip duration is nil when the inbound departs before the outbound" )
    func tripDurationInboundBeforeOutbound()
    {
        let snapshot = Self.roundTrip(
            outbound: Self.localDate( 2026, 10, 8 ),
            inbound: Self.localDate( 2026, 10, 5 )
        )

        #expect( snapshot.tripDurationDays == nil )
    }
}
