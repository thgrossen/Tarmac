/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

enum IATACode
{
    /**
     * Whether a string looks like a valid IATA airport code: exactly three letters.
     *
     * @param code Code to validate.
     * @return true if code is exactly three letters, regardless of case.
     */
    static func isValid( _ code: String ) -> Bool
    {
        code.count == 3 && code.allSatisfy( \.isLetter )
    }
}
