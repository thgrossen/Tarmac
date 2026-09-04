/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Thomas Grossen
 ******************************************************************************/

import Foundation

/**
 * Where `IgnavClient` hands every captured call. The app installs a sink at launch that forwards
 * to the `APILog` the inspector window shows; with nothing installed, recording is a no-op, which
 * is what tests that don't care about the log get.
 */
enum APIRecording
{
    private static let lock = NSLock()
    nonisolated( unsafe ) private static var sink: ( @Sendable ( APITransaction ) -> Void )?

    /**
     * Installs the sink every recorded call is forwarded to, replacing any previous one.
     *
     * @param sink Receives each transaction, on whatever thread the call finished on.
     */
    static func install( _ sink: @escaping @Sendable ( APITransaction ) -> Void )
    {
        self.lock.lock()
        defer { self.lock.unlock() }

        self.sink = sink
    }

    /**
     * Removes the installed sink, so recording goes back to being a no-op.
     */
    static func uninstall()
    {
        self.lock.lock()
        defer { self.lock.unlock() }

        self.sink = nil
    }

    /**
     * Forwards one captured call to the installed sink, if there is one.
     *
     * @param transaction Call to record.
     */
    static func record( _ transaction: APITransaction )
    {
        self.lock.lock()
        let sink = self.sink
        self.lock.unlock()

        sink?( transaction )
    }
}

/**
 * Context the search code establishes around its network calls so recorded transactions can be
 * attributed to the run that caused them, without threading an identifier through every fetch
 * signature. Task-locals propagate across `await` within a task, which is how the sequential
 * sweep loops run.
 */
enum APICallContext
{
    struct Info: Sendable
    {
        var runID: UUID?
    }

    @TaskLocal static var current = Info()
}
