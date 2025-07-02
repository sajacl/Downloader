import Foundation
import OSLog

public typealias DownloadManager = Downloader.Manager

extension Downloader {
    /// Download manager.
    /// Object is responsible for categorising sessions and updating tasks.
    /// - Discussion: Session and manager relationship is many to one.
    public final class Manager: @unchecked Sendable {
        /// Manager's name/purpose.
        private let name: String

        private let sessionsLock = NSLock()
        /// List of sessions that has been categorised based on ``Session.Kind``.
        private var sessions: [Session.Kind: Session] = [:]

        private let logger: Logger

        public init(name: String) {
            self.name = name

            logger = Logger(subsystem: "Downloader.Manager", category: name)
        }

        @discardableResult
        public func register(
            _ request: Request,
            intercepting completionHandler: (
                @Sendable (URL?, Result<URLResponse, Error>?) -> Void
            )? = nil
        ) -> Downloader.Task {
            logger.trace("[\(self.name)] Registering request \(request) for download.")

            // kind
            let kind: Session.Kind

            if request.keepAlive {
                kind = .background(
                    .default
                    // cache miss request.identifier
//                    Session.Kind.Background(
//                        identifier: request.identifier,
//                        isDiscretionary: false, // priority
//                        sessionSendsLaunchEvents: true
//                    )
                )
            } else {
                kind = .foreground(isEphemeral: request.shouldPersist)
            }

            // session
            let session: Session

            // cache
            if let cache = sessionsLock.withLock({ sessions[kind] }) {
                logger.trace("[\(self.name)] Retrieving session from cache")

                session = cache
            }
            // new session
            else {
                logger.trace("[\(self.name)] Creating new session for '\(kind)'")

                let downloadDelegateCoordinator = URLSessionDownloadDelegateCoordinator(
                    manager: self
                )

                // move out with better naming
                let delegateQueue: OperationQueue = {
                    let queue = OperationQueue()
                    queue.maxConcurrentOperationCount = 1
                    return queue
                }()

                let configuration = Self.createURLSessionConfiguration(
                    for: request,
                    basedOn: kind
                )

                let urlSession = URLSession(
                    configuration: configuration,
                    delegate: downloadDelegateCoordinator,
                    delegateQueue: delegateQueue
                )

                session = Session(
                    urlSession,
                    kind: kind
                )

                sessionsLock.withLock {
                    sessions[kind] = session
                }
            }

            return session.enqueue(request: request, intercepting: completionHandler)
        }

        private static func createURLSessionConfiguration(
            for request: Request,
            basedOn kind: Session.Kind
        ) -> URLSessionConfiguration {
            let configuration: URLSessionConfiguration

            switch kind {
                case let .foreground(isEphemeral):
                    configuration = isEphemeral ? .ephemeral: .default

                case let .background(task):
                    configuration = .background(withIdentifier: task.identifier)
                    configuration.isDiscretionary = task.isDiscretionary
                    configuration.sessionSendsLaunchEvents = task.sessionSendsLaunchEvents
            }

            configuration.allowsCellularAccess = request.allowsCellularAccess
            configuration.waitsForConnectivity = request.waitsForConnectivity

            return configuration
        }

        public func cancelAll() {
            logger.trace("[\(self.name)] Trying to cancel downloads.")

            let _sessions = sessionsLock.withLock { sessions }

            _sessions.values.forEach { session in
                session.cancelAll()
            }
        }

        public func pauseAll() {
            logger.trace("[\(self.name)] Trying to pause downloads.")

            let _sessions = sessionsLock.withLock { sessions }

            _sessions.values.forEach { session in
                session.pauseAll()
            }
        }

        public func resumeAll() {
            logger.trace("[\(self.name)] Trying to resume downloads.")

            let _sessions = sessionsLock.withLock { sessions }

            _sessions.values.forEach { session in
                session.resumeAll()
            }
        }

        func sessionUpdated(
            _ session: URLSession,
            task: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL
        ) {
            let _sessions = sessionsLock.withLock { sessions.values }

            let session = _sessions.first { _session in
                _session == session
            }

            guard let session else {
                logger.error(
                    "[\(self.name)] Session updated without having it in cache."
                )

                return
            }

            logger.trace("[\(self.name)] [\(session)] Finished Downloading task '\(task)'.")

            session.taskUpdated(task, didFinishDownloadingTo: location)
        }

        func sessionUpdated(
            _ session: URLSession,
            task: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            let _sessions = sessionsLock.withLock { sessions.values }

            let session = _sessions.first { _session in
                _session == session
            }

            guard let session else {
                logger.error(
                    "[\(self.name)] Session updated without having it in cache."
                )

                return
            }

            session.taskUpdated(
                task,
                didWriteData: bytesWritten,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpectedToWrite: totalBytesExpectedToWrite
            )

            logger.trace("[\(self.name)] [\(session)] Task progressed '\(task)'.")
        }

        func sessionUpdated(
            _ session: URLSession,
            task: URLSessionDownloadTask,
            didResumeAtOffset fileOffset: Int64,
            expectedTotalBytes: Int64
        ) {
            let _sessions = sessionsLock.withLock { sessions.values }

            let session = _sessions.first { _session in
                _session == session
            }

            guard let session else {
                logger.error(
                    "[\(self.name)] Session updated without having it in cache."
                )

                return
            }

            session.taskUpdated(
                task,
                didResumeAtOffset: fileOffset,
                expectedTotalBytes: expectedTotalBytes
            )

            logger.trace(
                "[\(self.name)] [\(session)] Task '\(task)' resumed at offset \(fileOffset)."
            )
        }

        func sessionUpdated(
            _ session: URLSession,
            task: URLSessionTask,
            didCompleteWithError error: Error
        ) {
            let _sessions = sessionsLock.withLock { sessions.values }

            let session = _sessions.first { _session in
                _session == session
            }

            guard let session else {
                logger.error(
                    "[\(self.name)] Session updated without having it in cache."
                )

                return
            }

            session.taskUpdated(
                task as! URLSessionDownloadTask,
                didCompleteWithError: error
            )

            logger.trace(
                "[\(self.name)] [\(session)] Task failed with error.\n'\(error.localizedDescription)'."
            )
        }

        func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            let _sessions = sessionsLock.withLock { sessions.values }

            let _session = _sessions.first { _session in
                _session == session
            }

            guard let _session else {
                logger.error(
                    "[\(self.name)] Session finished in background without having it in cache."
                )

                return
            }

            logger.trace(
                "[\(self.name)] [\(_session)] Session did finish events in background."
            )

            _session.sessionDidFinishEvents(forBackgroundURLSession: session)
        }
    }

    private final class URLSessionDownloadDelegateCoordinator: NSObject,
                                                               URLSessionDownloadDelegate {
        private unowned let manager: Downloader.Manager

        init(manager: Downloader.Manager) {
            self.manager = manager
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL
        ) {
            manager.sessionUpdated(session, task: downloadTask, didFinishDownloadingTo: location)
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            manager.sessionUpdated(
                session,
                task: downloadTask,
                didWriteData: bytesWritten,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpectedToWrite: totalBytesExpectedToWrite
            )
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didResumeAtOffset fileOffset: Int64,
            expectedTotalBytes: Int64
        ) {
            manager.sessionUpdated(
                session,
                task: downloadTask,
                didResumeAtOffset: fileOffset,
                expectedTotalBytes: expectedTotalBytes
            )
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didCompleteWithError error: Error?
        ) {
            guard let error else {
                // no-op
                return
            }

            manager.sessionUpdated(session, task: task, didCompleteWithError: error)
        }

        func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            manager.urlSessionDidFinishEvents(forBackgroundURLSession: session)
        }
    }
}
