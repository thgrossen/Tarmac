/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

enum FieldSwap
{
    /**
     * Exchanges origin and destination.
     *
     * @param origin Current origin.
     * @param destination Current destination.
     * @return The two values with origin and destination swapped.
     */
    static func swapped( origin: String, destination: String ) -> ( origin: String, destination: String )
    {
        ( origin: destination, destination: origin )
    }

    /**
     * Whether swapping origin and destination is meaningful.
     *
     * @param origin Current origin.
     * @param destination Current destination.
     * @return false when both fields are empty, since there is nothing useful to swap.
     */
    static func isEnabled( origin: String, destination: String ) -> Bool
    {
        origin.isEmpty == false || destination.isEmpty == false
    }
}
