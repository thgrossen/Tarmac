/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
@testable import Tarmac
import Testing

@Suite( "RangeSlider" )
struct RangeSliderTests
{
    @Test( "a position maps to the value at that fraction of the track" )
    func valueAtPosition()
    {
        #expect( RangeSlider.value( atX: 0, width: 200, bounds: 100 ... 300, step: 1 ) == 100 )
        #expect( RangeSlider.value( atX: 100, width: 200, bounds: 100 ... 300, step: 1 ) == 200 )
        #expect( RangeSlider.value( atX: 200, width: 200, bounds: 100 ... 300, step: 1 ) == 300 )
    }

    @Test( "positions outside the track clamp to its ends" )
    func valueClampsOutsideTrack()
    {
        #expect( RangeSlider.value( atX: -50, width: 200, bounds: 100 ... 300, step: 1 ) == 100 )
        #expect( RangeSlider.value( atX: 400, width: 200, bounds: 100 ... 300, step: 1 ) == 300 )
    }

    @Test( "values snap to the step" )
    func valueSnapsToStep()
    {
        // 62 / 200 of 0...1439, i.e. ~446, snapped to the nearest 5.
        #expect( RangeSlider.value( atX: 62, width: 200, bounds: 0 ... 1439, step: 5 ) == 445 )
        #expect( RangeSlider.value( atX: 51, width: 200, bounds: 0 ... 100, step: 10 ) == 30 )
    }

    @Test( "a zero-width track has nothing to map onto, so it reports its lower bound" )
    func zeroWidthTrack()
    {
        #expect( RangeSlider.value( atX: 20, width: 0, bounds: 100 ... 300, step: 1 ) == 100 )
    }

    @Test( "a value maps back to its position on the track" )
    func positionForValue()
    {
        #expect( RangeSlider.x( for: 100, width: 200, bounds: 100 ... 300 ) == 0 )
        #expect( RangeSlider.x( for: 200, width: 200, bounds: 100 ... 300 ) == 100 )
        #expect( RangeSlider.x( for: 300, width: 200, bounds: 100 ... 300 ) == 200 )
    }

    @Test( "values outside the bounds map to the track's ends" )
    func positionClampsOutsideBounds()
    {
        #expect( RangeSlider.x( for: 0, width: 200, bounds: 100 ... 300 ) == 0 )
        #expect( RangeSlider.x( for: 900, width: 200, bounds: 100 ... 300 ) == 200 )
    }

    @Test( "a value and its position round-trip" )
    func positionAndValueRoundTrip()
    {
        let x = RangeSlider.x( for: 250, width: 200, bounds: 100 ... 300 )

        #expect( RangeSlider.value( atX: x, width: 200, bounds: 100 ... 300, step: 1 ) == 250 )
    }

    @Test( "thumbs dragged past each other swap rather than inverting the range" )
    func thumbsDoNotCross()
    {
        let clamped = RangeSlider.clamped( lower: 400, upper: 200, bounds: 100 ... 500 )

        #expect( clamped.lower == 200 )
        #expect( clamped.upper == 400 )
    }

    @Test( "thumbs stay inside the bounds" )
    func thumbsStayInBounds()
    {
        let clamped = RangeSlider.clamped( lower: -10, upper: 900, bounds: 100 ... 500 )

        #expect( clamped.lower == 100 )
        #expect( clamped.upper == 500 )
    }
}
