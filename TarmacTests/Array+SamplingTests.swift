/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

@testable import Tarmac
import Testing

@Suite( "Array+Sampling" )
struct ArraySamplingTests
{
    @Test( "Returns everything when under the cap" )
    func underCap()
    {
        let items = Array( 0 ..< 5 )
        #expect( items.sampled( cap: 10 ) == items )
    }

    @Test( "Samples evenly across the range, keeping the first and last" )
    func overCap()
    {
        let items = Array( 0 ..< 10 )
        #expect( items.sampled( cap: 4 ) == [ 0, 3, 6, 9 ] )
    }

    @Test( "A cap of 1 returns just the first element" )
    func capOfOne()
    {
        let items = Array( 0 ..< 5 )
        #expect( items.sampled( cap: 1 ) == [ 0 ] )
    }

    @Test( "A cap of zero, or an empty array, returns nothing" )
    func emptyOrZeroCap()
    {
        #expect( [ 1, 2, 3 ].sampled( cap: 0 ) == [] )
        #expect( ( [] as [ Int ] ).sampled( cap: 5 ) == [] )
    }
}
