/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

extension Array
{
    /**
     * Samples at most `cap` elements, evenly spaced across the full array, so a large
     * array is thinned out rather than truncated from one end.
     *
     * @param cap Maximum number of elements to return.
     * @return At most `cap` elements, in their original relative order.
     */
    func sampled( cap: Int ) -> [ Element ]
    {
        guard cap > 0, self.isEmpty == false
        else
        {
            return []
        }
        guard self.count > cap
        else
        {
            return self
        }
        guard cap > 1
        else
        {
            return [ self[ 0 ] ]
        }

        var indices: [ Int ] = []
        var seen = Set< Int >()
        for i in 0 ..< cap
        {
            let index = ( i * ( self.count - 1 ) ) / ( cap - 1 )
            if seen.insert( index ).inserted
            {
                indices.append( index )
            }
        }
        return indices.map { self[ $0 ] }
    }
}
