/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftUI

/**
 * The strip below the results header showing which filters are currently narrowing the table, so an
 * active filter is visible without opening the popover.
 *
 * Renders nothing at all while no filter is set, keeping the header uncluttered in the common case.
 */
struct FilterChipBar: View
{
    var filters: ResultFilters
    var isRoundTrip: Bool
    var matchingCount: Int
    var totalCount: Int
    var onChange: ( ResultFilters ) -> Void
    var onEdit: () -> Void

    /**
     * Summarizes how much of the selected run's results survive the filters.
     *
     * @param matching Number of fares matching the filters.
     * @param total Number of fares the run returned.
     * @return "12 of 47 fares", singularized for a total of one.
     */
    static func fareCountLabel( matching: Int, total: Int ) -> String
    {
        "\( matching ) of \( total ) fare\( total == 1 ? "" : "s" )"
    }

    var body: some View
    {
        if self.filters.isActive
        {
            VStack( alignment: .leading, spacing: 6 )
            {
                FlowLayout( spacing: 6 )
                {
                    ForEach( self.filters.chips( isRoundTrip: self.isRoundTrip ) )
                    { chip in
                        FilterChip(
                            label: chip.label,
                            onRemove: { self.onChange( chip.cleared ) },
                            onEdit: self.onEdit
                        )
                    }
                }

                HStack
                {
                    Text( Self.fareCountLabel( matching: self.matchingCount, total: self.totalCount ) )
                        .font( .caption )
                        .foregroundStyle( .secondary )
                        .monospacedDigit()

                    Spacer()

                    Button( "Clear Filters" )
                    {
                        self.onChange( ResultFilters() )
                    }
                    .buttonStyle( .link )
                    .font( .caption )
                }
            }
            .padding( .horizontal )
            .padding( .bottom, 10 )
        }
    }
}

/**
 * One active filter: its summary, which reopens the filter popover, and an × clearing just it.
 */
private struct FilterChip: View
{
    var label: String
    var onRemove: () -> Void
    var onEdit: () -> Void

    var body: some View
    {
        HStack( spacing: 4 )
        {
            Button( action: self.onEdit )
            {
                Text( self.label )
                    .font( .caption )
            }
            .buttonStyle( .plain )

            Button( action: self.onRemove )
            {
                Image( systemName: "xmark" )
                    .font( .caption2.weight( .semibold ) )
            }
            .buttonStyle( .plain )
            .foregroundStyle( .secondary )
            .help( "Remove this filter" )
        }
        .padding( .horizontal, 8 )
        .padding( .vertical, 3 )
        .background( Color.accentColor.opacity( 0.14 ), in: Capsule() )
        .overlay( Capsule().stroke( Color.accentColor.opacity( 0.35 ), lineWidth: 1 ) )
    }
}

/**
 * Lays subviews out left to right, wrapping onto a new line whenever the next one wouldn't fit — so
 * a narrowed results pane stacks the chips instead of truncating or clipping them.
 */
struct FlowLayout: Layout
{
    var spacing: CGFloat = 6

    /**
     * Assigns each subview a position within `width`, wrapping when a row runs out of room.
     *
     * @param sizes The subviews' measured sizes, in order.
     * @param width Width available to lay out within.
     * @param spacing Gap between subviews, both horizontally and vertically.
     * @return Each subview's origin relative to the layout's top-left, plus the total size consumed.
     */
    static func arrange( sizes: [ CGSize ], width: CGFloat, spacing: CGFloat ) -> ( origins: [ CGPoint ], size: CGSize )
    {
        var origins: [ CGPoint ] = []
        var x: CGFloat           = 0
        var y: CGFloat           = 0
        var rowHeight: CGFloat   = 0
        var maxX: CGFloat        = 0

        for size in sizes
        {
            if x > 0,
               x + size.width > width
            {
                x         = 0
                y        += rowHeight + spacing
                rowHeight = 0
            }

            origins.append( CGPoint( x: x, y: y ) )
            x        += size.width + spacing
            maxX      = max( maxX, x - spacing )
            rowHeight = max( rowHeight, size.height )
        }

        return ( origins, CGSize( width: maxX, height: y + rowHeight ) )
    }

    func sizeThatFits( proposal: ProposedViewSize, subviews: Subviews, cache: inout Void ) -> CGSize
    {
        let sizes = subviews.map { $0.sizeThatFits( .unspecified ) }
        return Self.arrange( sizes: sizes, width: proposal.width ?? .infinity, spacing: self.spacing ).size
    }

    func placeSubviews( in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void )
    {
        let sizes  = subviews.map { $0.sizeThatFits( .unspecified ) }
        let layout = Self.arrange( sizes: sizes, width: bounds.width, spacing: self.spacing )

        for ( index, subview ) in subviews.enumerated()
        {
            let origin = layout.origins[ index ]
            subview.place(
                at: CGPoint( x: bounds.minX + origin.x, y: bounds.minY + origin.y ),
                proposal: ProposedViewSize( sizes[ index ] )
            )
        }
    }
}
