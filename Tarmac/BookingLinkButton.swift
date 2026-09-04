/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

#if os( macOS )
import AppKit
#endif
import SwiftUI

/**
 * The results table's "Book" cell. Asking Ignav for booking links costs a billed request, so
 * nothing is fetched until this button is clicked, and the offers it resolves are kept for the
 * rest of the session rather than re-requested.
 */
struct BookingLinkButton: View
{
    var snapshot: PriceSnapshot

    private enum Phase: Equatable
    {
        case idle
        case loading
        case failed( String )
    }

    @State private var phase: Phase = .idle
    @State private var isShowingDetails = false

    @Environment( \.openURL ) private var openURL

    /// Offers already resolved for this fare, which outlive the view and the app session.
    private var choices: [ BookingLinkChoice ] { self.snapshot.bookingLinks }

    /// Whether hovering has something to show: the resolved offers, or why the lookup failed.
    private var hasDetails: Bool
    {
        if case .failed = self.phase
        {
            return true
        }

        return self.choices.isEmpty == false
    }

    var body: some View
    {
        let availability = BookingLinkAvailability.availability( for: self.snapshot )

        if availability != .available
        {
            Image( systemName: "link" )
                .foregroundStyle( .tertiary )
                .help( BookingLinkAvailability.unavailableReason( availability ) ?? "" )
        }
        else
        {
            Button
            {
                self.act()
            } label: {
                self.icon
            }
            .buttonStyle( .borderless )
            .disabled( self.phase == .loading )
            .help( self.tooltip )
            .onHover
            { isHovering in
                // Offers already paid for, and the reason a lookup failed, are both worth showing
                // without a click — and without waiting on the system tooltip delay.
                if isHovering,
                   self.hasDetails
                {
                    self.isShowingDetails = true
                }
            }
            .popover( isPresented: self.$isShowingDetails, arrowEdge: .bottom )
            {
                self.details
            }
        }
    }

    /**
     * Two distinct icons say whether this fare's links still have to be fetched — which costs a
     * request — or have already been resolved and are one hover away.
     */
    @ViewBuilder     private var icon: some View
    {
        switch self.phase
        {
            case .idle:
                Image( systemName: self.choices.isEmpty ? "link.badge.plus" : "arrow.up.forward.app" )

            case .loading:
                ProgressView().controlSize( .small )

            case .failed:
                Image( systemName: "exclamationmark.triangle" ).foregroundStyle( .orange )
        }
    }

    private var tooltip: String
    {
        switch self.phase
        {
            case .idle where self.choices.isEmpty == false: return "Open booking links"
            case .idle:                                     return "Click to get booking links"
            case .loading:                                  return "Getting booking links…"
            case .failed:                                   return "Booking links unavailable"
        }
    }

    /**
     * What hovering reveals: the resolved offers, or the API's own account of why this fare's
     * lookup failed, so a failure on one row explains itself instead of just going quiet.
     */
    @ViewBuilder     private var details: some View
    {
        if case .failed( let message ) = self.phase
        {
            self.failureDetails( message )
        }
        else
        {
            self.choiceList
        }
    }

    private var choiceList: some View
    {
        VStack( alignment: .leading, spacing: 0 )
        {
            ForEach( self.choices )
            { choice in
                BookingLinkRow( choice: choice )
                {
                    self.isShowingDetails = false
                    self.openURL( choice.url )
                }
            }
        }
        .padding( .vertical, 4 )
        .frame( minWidth: 260 )
    }

    private func failureDetails( _ message: String ) -> some View
    {
        VStack( alignment: .leading, spacing: 10 )
        {
            Label( "Couldn't get booking links", systemImage: "exclamationmark.triangle" )
                .foregroundStyle( .orange )
                .font( .callout.weight( .semibold ) )

            Text( message )
                .font( .callout )
                .textSelection( .enabled )
                .fixedSize( horizontal: false, vertical: true )

            Button( "Try Again" )
            {
                self.isShowingDetails = false
                self.book()
            }
        }
        .padding( 12 )
        .frame( maxWidth: 320, alignment: .leading )
    }

    /**
     * Handles a click: reopens whatever the row already knows — its offers, or the failure that
     * explains why it has none — and otherwise starts the lookup.
     */
    private func act()
    {
        guard self.hasDetails
        else
        {
            self.book()
            return
        }

        self.isShowingDetails = true
    }

    /**
     * Resolves this fare's booking links, at the cost of one billed request. Offers already
     * resolved are reused, so a second click never spends another.
     */
    private func book()
    {
        guard let ignavID = self.snapshot.ignavID
        else
        {
            self.phase = .failed( "This result has no booking reference." )
            return
        }

        let apiKey = UserDefaults.standard.string( forKey: SearchViewModel.apiKeyDefaultsKey ) ?? ""
        guard apiKey.isEmpty == false
        else
        {
            self.phase = .failed( "Add your Ignav API key." )
            return
        }

        self.phase = .loading

        let runID = self.snapshot.run?.id

        Task
        {
            let outcome = await APICallContext.$current.withValue( APICallContext.Info( runID: runID ) )
            {
                await BookingLinkFetcher.links( forIgnavID: ignavID, apiKey: apiKey )
            }

            switch outcome
            {
                case .links( let choices ):
                    self.phase = .idle
                    self.snapshot.bookingLinks = choices
                    self.isShowingDetails = true

                case .noneAvailable:
                    self.phase = .failed( "No booking link is available for this fare." )

                case .expired( let message ):
                    self.phase = .failed( "\( message )\n\nUpdate the search to get fresh links." )

                case .failure( let message ):
                    self.phase = .failed( message )
            }
        }
    }
}

/**
 * One seller's offer in the booking-link popover, styled as a link — accented, underlined and
 * highlighted under the pointer — so it reads as somewhere to click rather than a caption.
 */
private struct BookingLinkRow: View
{
    var choice: BookingLinkChoice
    var open: () -> Void

    @State private var isHovering = false

    var body: some View
    {
        Button( action: self.open )
        {
            HStack( alignment: .firstTextBaseline, spacing: 16 )
            {
                VStack( alignment: .leading, spacing: 2 )
                {
                    HStack( spacing: 4 )
                    {
                        Text( self.choice.provider )
                            .underline( self.isHovering )

                        Image( systemName: "arrow.up.right" )
                            .imageScale( .small )
                    }
                    .foregroundStyle( Color.accentColor )

                    if let detail = self.choice.detail
                    {
                        Text( detail )
                            .font( .caption )
                            .foregroundStyle( .secondary )
                    }
                }

                Spacer( minLength: 0 )

                if let priceLabel = self.choice.priceLabel
                {
                    Text( priceLabel )
                        .monospacedDigit()
                        .foregroundStyle( .secondary )
                }
            }
            .padding( .horizontal, 12 )
            .padding( .vertical, 8 )
            .contentShape( .rect )
        }
        .buttonStyle( .plain )
        .background( self.isHovering ? Color.accentColor.opacity( 0.12 ) : .clear )
        .onHover
        { isHovering in
            self.isHovering = isHovering

            #if os( macOS )
            if isHovering
            {
                NSCursor.pointingHand.set()
            }
            else
            {
                NSCursor.arrow.set()
            }
            #endif
        }
    }
}
