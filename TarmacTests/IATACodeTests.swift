/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

@testable import Tarmac
import Testing

@Suite( "IATACode" )
struct IATACodeTests
{
    @Test( "Three-letter codes are valid, regardless of case" )
    func validCodes()
    {
        #expect( IATACode.isValid( "GVA" ) == true )
        #expect( IATACode.isValid( "lis" ) == true )
    }

    @Test( "Empty, wrong-length or non-letter input is invalid" )
    func invalidCodes()
    {
        #expect( IATACode.isValid( "" ) == false )
        #expect( IATACode.isValid( "GV" ) == false )
        #expect( IATACode.isValid( "GVAA" ) == false )
        #expect( IATACode.isValid( "GV1" ) == false )
        #expect( IATACode.isValid( "   " ) == false )
    }
}
