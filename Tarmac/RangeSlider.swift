/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import SwiftUI

/**
 * A two-thumb slider selecting a closed range within `bounds`.
 *
 * AppKit has no two-thumb control, so this is drawn by hand: a track, a tinted span between the
 * thumbs, and two draggable thumbs. Dragging one past the other pushes it along instead of
 * inverting the range.
 *
 * Callers work in whatever unit suits them — prices, minutes since midnight, seconds since epoch —
 * and supply `format` to label the two ends.
 */
struct RangeSlider: View
{
    var bounds: ClosedRange< Double >
    var step: Double = 1
    var format: ( Double ) -> String
    @Binding var lowerValue: Double
    @Binding var upperValue: Double

    private static let thumbDiameter: CGFloat = 16
    private static let trackHeight: CGFloat = 4

    /**
     * Converts a horizontal position on the track into a value, snapped to `step` and clamped to
     * `bounds`.
     *
     * @param x Position along the track, measured from its leading edge.
     * @param width The track's full width.
     * @param bounds The range the track spans.
     * @param step Granularity to snap the result to; values of 0 or less snap to nothing.
     * @return The value at that position.
     */
    static func value( atX x: CGFloat, width: CGFloat, bounds: ClosedRange< Double >, step: Double ) -> Double
    {
        guard width > 0
        else
        {
            return bounds.lowerBound
        }

        let fraction = min( max( Double( x / width ), 0 ), 1 )
        let raw      = bounds.lowerBound + fraction * ( bounds.upperBound - bounds.lowerBound )
        guard step > 0
        else
        {
            return raw
        }

        let snapped = ( raw / step ).rounded() * step
        return min( max( snapped, bounds.lowerBound ), bounds.upperBound )
    }

    /**
     * Converts a value into its horizontal position on the track.
     *
     * @param value Value to place.
     * @param width The track's full width.
     * @param bounds The range the track spans.
     * @return The position along the track, measured from its leading edge.
     */
    static func x( for value: Double, width: CGFloat, bounds: ClosedRange< Double > ) -> CGFloat
    {
        let span = bounds.upperBound - bounds.lowerBound
        guard span > 0
        else
        {
            return 0
        }

        let fraction = min( max( ( value - bounds.lowerBound ) / span, 0 ), 1 )
        return width * CGFloat( fraction )
    }

    /**
     * Keeps a pair of thumb values inside `bounds` and in order, so dragging one thumb past the
     * other pushes it along rather than inverting the range.
     *
     * @param lower Proposed lower value.
     * @param upper Proposed upper value.
     * @param bounds The range the track spans.
     * @return The corrected pair.
     */
    static func clamped( lower: Double, upper: Double, bounds: ClosedRange< Double > ) -> ( lower: Double, upper: Double )
    {
        let clampedLower = min( max( lower, bounds.lowerBound ), bounds.upperBound )
        let clampedUpper = min( max( upper, bounds.lowerBound ), bounds.upperBound )
        return ( min( clampedLower, clampedUpper ), max( clampedLower, clampedUpper ) )
    }

    // Which thumb the in-flight drag grabbed, decided once when it starts so that dragging one
    // thumb across the other doesn't hand the drag over to its neighbour mid-gesture.
    @State private var draggingThumb: Thumb?

    private enum Thumb
    {
        case lower
        case upper
    }

    /**
     * Picks the thumb a drag starting at `x` should move: the nearer one, resolving a tie towards
     * whichever thumb has room to move.
     *
     * @param x Position the drag started at, measured from the track's leading edge.
     * @param lowerX The lower thumb's position on the track.
     * @param upperX The upper thumb's position on the track.
     * @return The thumb to drag.
     */
    private static func thumb( grabbedAt x: CGFloat, lowerX: CGFloat, upperX: CGFloat ) -> Thumb
    {
        let lowerDistance = abs( x - lowerX )
        let upperDistance = abs( x - upperX )
        if lowerDistance == upperDistance
        {
            return x < lowerX ? .lower : .upper
        }
        return lowerDistance < upperDistance ? .lower : .upper
    }

    var body: some View
    {
        VStack( spacing: 4 )
        {
            GeometryReader
            { geometry in
                let width  = max( geometry.size.width - Self.thumbDiameter, 1 )
                let lowerX = Self.x( for: self.lowerValue, width: width, bounds: self.bounds )
                let upperX = Self.x( for: self.upperValue, width: width, bounds: self.bounds )

                ZStack( alignment: .leading )
                {
                    Capsule()
                        .fill( Color( nsColor: .unemphasizedSelectedContentBackgroundColor ) )
                        .frame( height: Self.trackHeight )

                    Capsule()
                        .fill( Color.accentColor )
                        .frame( width: max( upperX - lowerX, 0 ), height: Self.trackHeight )
                        .offset( x: lowerX )

                    self.thumb( at: lowerX )
                    self.thumb( at: upperX )
                }
                .frame( maxHeight: .infinity )
                .padding( .horizontal, Self.thumbDiameter / 2 )
                .contentShape( Rectangle() )
                .gesture( self.drag( width: width, lowerX: lowerX, upperX: upperX ) )
            }
            .frame( height: Self.thumbDiameter )

            HStack
            {
                Text( self.format( self.lowerValue ) )
                Spacer()
                Text( self.format( self.upperValue ) )
            }
            .font( .caption )
            .foregroundStyle( .secondary )
            .monospacedDigit()
        }
    }

    private func thumb( at x: CGFloat ) -> some View
    {
        Circle()
            .fill( Color( nsColor: .controlBackgroundColor ) )
            .overlay( Circle().stroke( Color.accentColor, lineWidth: 2 ) )
            .frame( width: Self.thumbDiameter, height: Self.thumbDiameter )
            .offset( x: x - Self.thumbDiameter / 2 )
    }

    /**
     * The drag driving both thumbs. It's attached to the whole track rather than to the thumbs
     * themselves so that clicking anywhere on the track moves the nearer thumb there, and so the
     * reported positions stay in one coordinate space.
     *
     * @param width The track's full width.
     * @param lowerX The lower thumb's current position on the track.
     * @param upperX The upper thumb's current position on the track.
     * @return The configured gesture.
     */
    private func drag( width: CGFloat, lowerX: CGFloat, upperX: CGFloat ) -> some Gesture
    {
        DragGesture( minimumDistance: 0 )
            .onChanged
            { drag in
                // The track is inset by half a thumb so the thumbs stay inside the control's
                // bounds; shifting back puts the drag on the track's own scale.
                let startX = drag.startLocation.x - Self.thumbDiameter / 2
                let thumb  = self.draggingThumb ?? Self.thumb( grabbedAt: startX, lowerX: lowerX, upperX: upperX )
                self.draggingThumb = thumb

                let value = Self.value(
                    atX: drag.location.x - Self.thumbDiameter / 2,
                    width: width,
                    bounds: self.bounds,
                    step: self.step
                )
                let clamped = Self.clamped(
                    lower: thumb == .lower ? value : self.lowerValue,
                    upper: thumb == .lower ? self.upperValue : value,
                    bounds: self.bounds
                )
                self.lowerValue = clamped.lower
                self.upperValue = clamped.upper
            }
            .onEnded
            { _ in
                self.draggingThumb = nil
            }
    }
}
