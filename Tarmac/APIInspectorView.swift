/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/**
 * Lists every Ignav call the app has made this launch and shows the full request and response for
 * whichever is selected. Rows appear as calls complete, so a multi-day sweep can be watched while
 * it runs.
 */
struct APIInspectorView: View
{
    @Environment( APILog.self ) private var log
    @Environment( APIInspectorState.self ) private var state

    var body: some View
    {
        @Bindable var state = self.state

        NavigationSplitView
        {
            self.transactionList
                .navigationSplitViewColumnWidth( min: 220, ideal: 260, max: 360 )
        }
        detail:
        {
            self.detail
        }
        .searchable( text: $state.query, placement: .sidebar, prompt: "Filter requests" )
        .toolbar
        {
            ToolbarItem( placement: .navigation )
            {
                Picker( "Scope", selection: $state.scope )
                {
                    ForEach( APIInspectorState.Scope.allCases )
                    {
                        Text( $0.label ).tag( $0 )
                    }
                }
                .pickerStyle( .segmented )
                .disabled( self.state.run == nil )
                .help( "Show only the selected run's calls, or every call this launch." )
            }

            ToolbarItem
            {
                Toggle( isOn: $state.failuresOnly )
                {
                    Label( "Failures Only", systemImage: "exclamationmark.triangle" )
                }
                .help( "Show only calls that failed." )
            }

            ToolbarItem
            {
                Button( "Export…", systemImage: "square.and.arrow.up" )
                {
                    self.export()
                }
                .disabled( self.transactions.isEmpty )
                .help( "Save the listed calls as a JSON file." )
            }

            ToolbarItem
            {
                Button( "Clear", systemImage: "trash" )
                {
                    self.log.clear()
                    self.state.selection = nil
                }
                .disabled( self.log.transactions.isEmpty )
                .help( "Discard every recorded call." )
            }
        }
        .frame( minWidth: 720, minHeight: 420 )
    }

    /**
     * The calls the list should currently show, newest first.
     */
    private var transactions: [ APITransaction ]
    {
        APILog.filtered(
            self.log.transactions,
            runID: self.state.scopedRunID,
            query: self.state.query,
            failuresOnly: self.state.failuresOnly
        )
    }

    /**
     * The response a run recorded before this launch, shown when the log has nothing live for it.
     * Runs made this launch are listed call by call instead, so this only fills the gap left by the
     * log being session-only.
     */
    private var archivedJSON: String?
    {
        guard self.state.scope == .thisRun,
              self.transactions.isEmpty,
              self.state.failuresOnly == false,
              let rawJSON = self.state.run?.rawJSON,
              rawJSON.isEmpty == false
        else
        {
            return nil
        }
        return rawJSON
    }

    private var selectedTransaction: APITransaction?
    {
        guard let selection = self.state.selection
        else
        {
            return nil
        }
        return self.transactions.first { $0.id == selection }
    }

    @ViewBuilder private var transactionList: some View
    {
        @Bindable var state = self.state

        let transactions = self.transactions

        if transactions.isEmpty
        {
            self.emptyList
        }
        else
        {
            List( transactions, selection: $state.selection )
            {
                TransactionRow( transaction: $0 )
            }
            .onChange( of: transactions.first?.id )
            {
                // Follow the sweep as it runs, but never steal a row the user picked themselves.
                if self.state.selection == nil
                {
                    self.state.selection = transactions.first?.id
                }
            }
        }
    }

    @ViewBuilder private var emptyList: some View
    {
        let message = self.log.transactions.isEmpty
            ? "No API calls yet this launch."
            : "No calls match the current filter."

        VStack
        {
            Text( message )
                .foregroundStyle( .secondary )
                .multilineTextAlignment( .center )
                .padding()
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
    }

    @ViewBuilder private var detail: some View
    {
        if let transaction = self.selectedTransaction
        {
            TransactionDetailView( transaction: transaction )
        }
        else if let archivedJSON = self.archivedJSON
        {
            ArchivedResponseView( rawJSON: archivedJSON )
        }
        else
        {
            Text( "Select a request." )
                .foregroundStyle( .secondary )
                .frame( maxWidth: .infinity, maxHeight: .infinity )
        }
    }

    /**
     * Writes the listed calls to a file the user picks.
     */
    private func export()
    {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "tarmac-api-log.json"
        panel.allowedContentTypes  = [ .json ]

        guard panel.runModal() == .OK,
              let url = panel.url
        else
        {
            return
        }

        do
        {
            try APILog.exportData( self.transactions ).write( to: url )
        }
        catch
        {
            NSAlert( error: error ).runModal()
        }
    }
}

// MARK: - List row

private struct TransactionRow: View
{
    var transaction: APITransaction

    var body: some View
    {
        HStack( alignment: .top, spacing: 8 )
        {
            Circle()
                .fill( self.transaction.isFailure ? Color.red : Color.green )
                .frame( width: 8, height: 8 )
                .padding( .top, 4 )

            VStack( alignment: .leading, spacing: 2 )
            {
                HStack
                {
                    Text( self.transaction.endpoint )
                        .font( .body.monospaced() )
                    Spacer()
                    Text( Self.timeFormatter.string( from: self.transaction.startedAt ) )
                        .font( .caption )
                        .foregroundStyle( .secondary )
                }

                if let label = self.transaction.label
                {
                    Text( label )
                        .font( .caption )
                        .foregroundStyle( .secondary )
                        .lineLimit( 1 )
                }

                Text( APIInspectorFormat.summary( for: self.transaction ) )
                    .font( .caption )
                    .foregroundStyle( self.transaction.isFailure ? Color.red : .secondary )
            }
        }
        .padding( .vertical, 2 )
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

// MARK: - Detail

private struct TransactionDetailView: View
{
    var transaction: APITransaction

    private enum Pane: String, CaseIterable, Identifiable
    {
        case request
        case response

        var id: String { self.rawValue }

        var label: String
        {
            switch self
            {
                case .request:  return "Request"
                case .response: return "Response"
            }
        }
    }

    @State private var pane: Pane = .response

    var body: some View
    {
        VStack( alignment: .leading, spacing: 0 )
        {
            self.header
            Divider()
            self.panePicker
            Divider()
            JSONTextView( text: self.paneText )
        }
        .onChange( of: self.transaction.id )
        {
            self.pane = .response
        }
    }

    private var paneText: String
    {
        switch self.pane
        {
            case .request:  return self.transaction.requestBody
            case .response: return self.transaction.responseBody ?? "No response — the request never reached the server."
        }
    }

    @ViewBuilder private var header: some View
    {
        VStack( alignment: .leading, spacing: 4 )
        {
            Text( "\( self.transaction.method ) \( self.transaction.url.absoluteString )" )
                .font( .system( size: 11, design: .monospaced ) )
                .textSelection( .enabled )
                .lineLimit( 1 )
                .truncationMode( .middle )

            Text( APIInspectorFormat.summary( for: self.transaction ) )
                .font( .caption )
                .foregroundStyle( self.transaction.isFailure ? Color.red : .secondary )

            if let failureDetail = self.transaction.failureDetail
            {
                Text( failureDetail )
                    .font( .caption )
                    .foregroundStyle( .red )
                    .textSelection( .enabled )
            }
        }
        .frame( maxWidth: .infinity, alignment: .leading )
        .padding( 10 )
    }

    @ViewBuilder private var panePicker: some View
    {
        HStack
        {
            Picker( "", selection: self.$pane )
            {
                ForEach( Pane.allCases )
                {
                    Text( $0.label ).tag( $0 )
                }
            }
            .pickerStyle( .segmented )
            .labelsHidden()
            .frame( width: 200 )

            Spacer()

            Button( "Copy", systemImage: "doc.on.doc" )
            {
                Self.copyToPasteboard( self.paneText )
            }

            Menu( "Copy as curl" )
            {
                Button( "With $IGNAV_API_KEY Placeholder" )
                {
                    Self.copyToPasteboard( self.transaction.curlCommand( apiKey: nil ) )
                }

                Button( "With API Key" )
                {
                    let apiKey = UserDefaults.standard.string( forKey: SearchViewModel.apiKeyDefaultsKey ) ?? ""
                    Self.copyToPasteboard( self.transaction.curlCommand( apiKey: apiKey ) )
                }
            }
            .fixedSize()
        }
        .padding( .horizontal, 10 )
        .padding( .vertical, 6 )
    }

    private static func copyToPasteboard( _ text: String )
    {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString( text, forType: .string )
    }
}

// MARK: - Archived response

private struct ArchivedResponseView: View
{
    var rawJSON: String

    var body: some View
    {
        VStack( alignment: .leading, spacing: 0 )
        {
            Text( "Archived response · recorded before this launch" )
                .font( .caption )
                .foregroundStyle( .secondary )
                .frame( maxWidth: .infinity, alignment: .leading )
                .padding( 10 )

            Divider()

            JSONTextView( text: self.rawJSON )
        }
    }
}

// MARK: - Shared pieces

private struct JSONTextView: View
{
    var text: String

    var body: some View
    {
        ScrollView( [ .vertical, .horizontal ] )
        {
            Text( self.text )
                .font( .system( size: 11, design: .monospaced ) )
                .textSelection( .enabled )
                .padding( 10 )
                .frame( maxWidth: .infinity, alignment: .leading )
        }
    }
}

enum APIInspectorFormat
{
    /**
     * The one-line status of a call, e.g. "200 · 412 ms · 84 KB".
     *
     * @param transaction Call to describe.
     * @return Status, duration and response size, separated by middots.
     */
    static func summary( for transaction: APITransaction ) -> String
    {
        [
            transaction.statusLabel,
            self.duration( transaction.duration ),
            self.byteCount( transaction.responseByteCount )
        ]
        .joined( separator: " · " )
    }

    /**
     * Formats a duration for display, in milliseconds under ten seconds and in seconds above.
     *
     * @param duration Duration in seconds.
     * @return A short display string, e.g. "412 ms" or "12.4 s".
     */
    static func duration( _ duration: TimeInterval ) -> String
    {
        guard duration >= 10
        else
        {
            return "\( Int( ( duration * 1_000 ).rounded() )) ms"
        }
        return String( format: "%.1f s", duration )
    }

    /**
     * Formats a response size for display.
     *
     * @param byteCount Size in bytes.
     * @return A short display string, e.g. "84 KB".
     */
    static func byteCount( _ byteCount: Int ) -> String
    {
        ByteCountFormatter.string( fromByteCount: Int64( byteCount ), countStyle: .file )
    }
}
