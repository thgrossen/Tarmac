/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "SearchProgress" )
struct SearchProgressTests
{
    @Test( "A sweep with nothing planned is indeterminate and doesn't divide by zero" )
    func emptySweep()
    {
        let progress = SearchProgress( completed: 0, total: 0 )

        #expect( progress.fraction == 0 )
        #expect( progress.isDeterminate == false )
        #expect( progress.percentText == "0%" )
        #expect( progress.countText == "0 of 0 requests" )
    }

    @Test( "A negative total is treated as nothing planned" )
    func negativeTotal()
    {
        let progress = SearchProgress( completed: 3, total: -5 )

        #expect( progress.total == 0 )
        #expect( progress.completed == 0 )
        #expect( progress.fraction == 0 )
    }

    @Test( "Two requests stay indeterminate, three earn a bar" )
    func determinateThreshold()
    {
        #expect( SearchProgress( completed: 0, total: 1 ).isDeterminate == false )
        #expect( SearchProgress( completed: 0, total: 2 ).isDeterminate == false )
        #expect( SearchProgress( completed: 0, total: 3 ).isDeterminate )
        #expect( SearchProgress( completed: 0, total: 24 ).isDeterminate )
    }

    @Test( "Progress reads as a percentage and counts" )
    func detailWording()
    {
        let progress = SearchProgress( completed: 7, total: 24 )

        #expect( abs( progress.fraction - ( 7.0 / 24.0 ) ) < 0.000_001 )
        #expect( progress.percentText == "29%" )
        #expect( progress.countText == "7 of 24 requests" )
        #expect( progress.detailText == "29% (7 of 24 requests)" )
    }

    @Test( "A single planned request is worded in the singular" )
    func singularWording()
    {
        #expect( SearchProgress( completed: 0, total: 1 ).countText == "0 of 1 request" )
        #expect( SearchProgress( completed: 1, total: 1 ).countText == "1 of 1 request" )
    }

    @Test( "The percentage holds at 99% until the last request lands" )
    func percentageHoldsBelowComplete()
    {
        #expect( SearchProgress( completed: 999, total: 1_000 ).percentText == "99%" )
        #expect( SearchProgress( completed: 1_000, total: 1_000 ).percentText == "100%" )

        // The bar itself isn't held back — only the wording is.
        #expect( SearchProgress( completed: 999, total: 1_000 ).fraction > 0.99 )
    }

    @Test( "A finished sweep is complete" )
    func completedSweep()
    {
        let progress = SearchProgress( completed: 24, total: 24 )

        #expect( progress.fraction == 1 )
        #expect( progress.detailText == "100% (24 of 24 requests)" )
    }

    @Test( "Completed counts are clamped to the planned total" )
    func clampsCompleted()
    {
        #expect( SearchProgress( completed: -3, total: 24 ).completed == 0 )
        #expect( SearchProgress( completed: 30, total: 24 ).completed == 24 )
        #expect( SearchProgress( completed: 30, total: 24 ).fraction == 1 )

        // Clamping in the initializer makes a redundant over-count equal to the finished value,
        // so a repeated emission can't churn the UI.
        #expect( SearchProgress( completed: 30, total: 24 ) == SearchProgress( completed: 24, total: 24 ) )
    }

    @Test( "Nothing done yet reads as zero" )
    func startOfSweep()
    {
        let progress = SearchProgress( completed: 0, total: 24 )

        #expect( progress.fraction == 0 )
        #expect( progress.detailText == "0% (0 of 24 requests)" )
    }
}
