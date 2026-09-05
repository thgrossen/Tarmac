/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

@testable import Tarmac
import Testing

@Suite( "FlexibilityOptions" )
struct FlexibilityOptionsTests
{
    @Test( "No flexibility reads as None rather than a day count" )
    func labelForNone()
    {
        #expect( FlexibilityOptions.label( forDays: 0 ) == "None" )
    }

    @Test( "A single day is singular" )
    func labelForOneDay()
    {
        #expect( FlexibilityOptions.label( forDays: 1 ) == "1 day" )
    }

    @Test( "Every other count is plural" )
    func labelForSeveralDays()
    {
        #expect( FlexibilityOptions.label( forDays: 2 ) == "2 days" )
        #expect( FlexibilityOptions.label( forDays: 7 ) == "7 days" )
        #expect( FlexibilityOptions.label( forDays: 10 ) == "10 days" )
    }

    @Test( "The form's default is offered, and reads as None" )
    func daysOfferNoneByDefault()
    {
        #expect( FlexibilityOptions.days( including: SearchPrefill.defaultFlexibilityDays ) == Array( 0 ... 7 ) )
        #expect( FlexibilityOptions.label( forDays: SearchPrefill.defaultFlexibilityDays ) == "None" )
    }

    @Test( "The list runs from none up to a week" )
    func maximumIsAWeek()
    {
        #expect( FlexibilityOptions.maximumDays == 7 )
        #expect( FlexibilityOptions.days( including: 0 ).count == 8 )
    }

    @Test( "A value already on the list doesn't duplicate it" )
    func daysDoNotDuplicateAnOfferedValue()
    {
        #expect( FlexibilityOptions.days( including: 3 ) == Array( 0 ... 7 ) )
        #expect( FlexibilityOptions.days( including: 7 ) == Array( 0 ... 7 ) )
    }

    @Test( "A prefilled value above the maximum widens the list rather than being rewritten" )
    func daysWidenForAPrefilledValueAboveTheMaximum()
    {
        #expect( FlexibilityOptions.days( including: 10 ) == [ 0, 1, 2, 3, 4, 5, 6, 7, 10 ] )
        #expect( FlexibilityOptions.days( including: 14 ) == [ 0, 1, 2, 3, 4, 5, 6, 7, 14 ] )
    }

    @Test( "A negative value is left out rather than widening the list downwards" )
    func daysIgnoreANegativeValue()
    {
        // Meaningless as a flexibility, so the list stays the standard one rather than gaining a
        // second entry that would also read "None".
        #expect( FlexibilityOptions.days( including: -1 ) == Array( 0 ... 7 ) )
    }

    @Test( "A stored negative normalises to no flexibility, so the picker always has a match" )
    func selectableNormalisesANegativeStoredValue()
    {
        #expect( FlexibilityOptions.selectable( from: -1 ) == 0 )
        #expect( FlexibilityOptions.selectable( from: 0 ) == 0 )
        #expect( FlexibilityOptions.selectable( from: 3 ) == 3 )
        #expect( FlexibilityOptions.selectable( from: 10 ) == 10 )
    }

    @Test( "Any stored value, once made selectable, appears in the offered list" )
    func selectableValuesAreAlwaysOffered()
    {
        for stored in [ -5, -1, 0, 1, 7, 8, 14 ]
        {
            let selectable = FlexibilityOptions.selectable( from: stored )
            #expect( FlexibilityOptions.days( including: selectable ).contains( selectable ) )
        }
    }
}
