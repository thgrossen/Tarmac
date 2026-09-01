/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

@testable import Tarmac
import Testing

@Suite( "FieldSwap" )
struct FieldSwapTests
{
    @Test( "Swapping exchanges origin and destination" )
    func swaps()
    {
        let result = FieldSwap.swapped( origin: "GVA", destination: "LIS" )
        #expect( result.origin == "LIS" )
        #expect( result.destination == "GVA" )
    }

    @Test( "Swapping is its own inverse" )
    func swapIsInvertible()
    {
        let once = FieldSwap.swapped( origin: "GVA", destination: "LIS" )
        let twice = FieldSwap.swapped( origin: once.origin, destination: once.destination )
        #expect( twice.origin == "GVA" )
        #expect( twice.destination == "LIS" )
    }

    @Test( "Enabled when at least one field is non-empty" )
    func enabledWhenNotBothEmpty()
    {
        #expect( FieldSwap.isEnabled( origin: "GVA", destination: "" ) == true )
        #expect( FieldSwap.isEnabled( origin: "", destination: "LIS" ) == true )
        #expect( FieldSwap.isEnabled( origin: "GVA", destination: "LIS" ) == true )
    }

    @Test( "Disabled when both fields are empty" )
    func disabledWhenBothEmpty()
    {
        #expect( FieldSwap.isEnabled( origin: "", destination: "" ) == false )
    }
}
