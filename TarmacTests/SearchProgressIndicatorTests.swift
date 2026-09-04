/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "SearchProgressIndicator" )
struct SearchProgressIndicatorTests
{
    @Test( "A sweep that hasn't reported yet just says it's searching" )
    func labelWithoutProgress()
    {
        #expect( SearchProgressIndicator.label( for: nil ) == "Searching…" )
    }

    @Test( "A sweep too short to count says nothing more than before" )
    func labelBelowTheThreshold()
    {
        // Both sweeps really do emit a 0-of-0 for a range with nothing to search.
        #expect( SearchProgressIndicator.label( for: SearchProgress( completed: 0, total: 0 ) ) == "Searching…" )
        #expect( SearchProgressIndicator.label( for: SearchProgress( completed: 0, total: 1 ) ) == "Searching…" )
        #expect( SearchProgressIndicator.label( for: SearchProgress( completed: 1, total: 2 ) ) == "Searching…" )
    }

    @Test( "A countable sweep carries the percentage and the counts" )
    func labelWithProgress()
    {
        #expect( SearchProgressIndicator.label( for: SearchProgress( completed: 0, total: 3 ) ) == "Searching… 0% (0 of 3 requests)" )
        #expect( SearchProgressIndicator.label( for: SearchProgress( completed: 0, total: 24 ) ) == "Searching… 0% (0 of 24 requests)" )
        #expect( SearchProgressIndicator.label( for: SearchProgress( completed: 7, total: 24 ) ) == "Searching… 29% (7 of 24 requests)" )
        #expect( SearchProgressIndicator.label( for: SearchProgress( completed: 24, total: 24 ) ) == "Searching… 100% (24 of 24 requests)" )
    }

    @Test( "Only a countable sweep is drawn as a bar" )
    func determinateProgressPicksTheBar()
    {
        #expect( SearchProgressIndicator.determinateProgress( for: nil ) == nil )
        #expect( SearchProgressIndicator.determinateProgress( for: SearchProgress( completed: 0, total: 0 ) ) == nil )
        #expect( SearchProgressIndicator.determinateProgress( for: SearchProgress( completed: 1, total: 2 ) ) == nil )
        #expect( SearchProgressIndicator.determinateProgress( for: SearchProgress( completed: 1, total: 3 ) ) == SearchProgress( completed: 1, total: 3 ) )
    }
}
