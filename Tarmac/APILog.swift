/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation
import Observation

/**
 * Every Ignav call the app has made this launch, newest first. Session-only: nothing here is
 * persisted, so the log is empty after a relaunch and the inspector falls back to whatever raw
 * response the run itself stored.
 *
 * Bounded two ways — a transaction count and a total response-byte ceiling — because fare
 * responses are large enough that a count alone could pin hundreds of megabytes.
 */
@MainActor
@Observable
final class APILog
{
    nonisolated static let maxTransactions = 200
    nonisolated static let maxResponseBytes = 64 * 1_024 * 1_024

    private( set ) var transactions: [ APITransaction ] = []

    /**
     * Adds a call to the front of the log, evicting the oldest entries that no longer fit.
     *
     * @param transaction Call to record.
     */
    func record( _ transaction: APITransaction )
    {
        self.transactions = Self.evicted( [ transaction ] + self.transactions )
    }

    /**
     * Empties the log.
     */
    func clear()
    {
        self.transactions = []
    }

    /**
     * Records a call from whatever thread it finished on, hopping to the main actor to do it.
     *
     * @param transaction Call to record.
     */
    nonisolated func recordFromAnyIsolation( _ transaction: APITransaction )
    {
        Task { @MainActor in self.record( transaction ) }
    }

    /**
     * Drops the oldest transactions until the list fits within both caps.
     *
     * @param transactions Transactions, newest first.
     * @return The prefix that fits, newest first.
     */
    nonisolated static func evicted( _ transactions: [ APITransaction ] ) -> [ APITransaction ]
    {
        var result: [ APITransaction ] = []
        var byteCount = 0

        for transaction in transactions.prefix( self.maxTransactions )
        {
            let next = byteCount + transaction.responseByteCount
            guard result.isEmpty || next <= self.maxResponseBytes
            else
            {
                break
            }

            result.append( transaction )
            byteCount = next
        }

        return result
    }

    /**
     * Narrows the log to what the inspector should currently list.
     *
     * @param transactions Transactions to filter, newest first.
     * @param runID Run to restrict to, or nil to keep every run's calls.
     * @param query Free text matched against the endpoint, the request label and both bodies;
     *              empty matches everything.
     * @param failuresOnly Whether to drop calls that succeeded.
     * @return The matching transactions, in their given order.
     */
    nonisolated static func filtered(
        _ transactions: [ APITransaction ],
        runID: UUID? = nil,
        query: String = "",
        failuresOnly: Bool = false
    ) -> [ APITransaction ]
    {
        let needle = query.trimmingCharacters( in: .whitespacesAndNewlines ).lowercased()

        return transactions.filter
        { transaction in
            if let runID,
               transaction.runID != runID
            {
                return false
            }

            if failuresOnly,
               transaction.isFailure == false
            {
                return false
            }

            guard needle.isEmpty == false
            else
            {
                return true
            }

            let haystack = [
                transaction.endpoint,
                transaction.label ?? "",
                transaction.statusLabel,
                transaction.requestBody,
                transaction.responseBody ?? ""
            ]

            return haystack.contains { $0.lowercased().contains( needle ) }
        }
    }

    /**
     * Serialises transactions for the export action.
     *
     * @param transactions Transactions to export, newest first.
     * @return Pretty-printed JSON, an array of one object per call.
     */
    nonisolated static func exportData( _ transactions: [ APITransaction ] ) throws -> Data
    {
        try JSONSerialization.data(
            withJSONObject: transactions.map( \.exportRepresentation ),
            options: [ .prettyPrinted, .sortedKeys ]
        )
    }
}
