import Foundation
import OSLog

extension Downloader {
    public final class Session: Equatable,
                                @unchecked Sendable,
                                CustomStringConvertible, CustomDebugStringConvertible {
        /// System's session.
        private let underlyingSession: URLSession

        /// Kind/Purpose of the session.
        /// This property will be consumed to categorise the sessions.
        let kind: Kind

        private let taskListLock = NSLock()
        // queue + task lookup?
        /// Task list, used for caching based on the requests.
        private(set) var tasks: [Request: Downloader.Task]

        private let logger: Logger

        init(
            _ session: URLSession,
            kind: Kind
        ) {
            self.underlyingSession = session
            self.kind = kind
            tasks = [:]

            logger = Logger(subsystem: "Downloader.Session", category: "\(kind)")
        }

        public static func == (lhs: Downloader.Session, rhs: Downloader.Session) -> Bool {
            let sessionComparison = lhs.underlyingSession == rhs.underlyingSession
            lazy var kindComparison = lhs.kind == rhs.kind

            return sessionComparison && kindComparison
        }

        public static func == (lhs: Downloader.Session, rhs: URLSession) -> Bool {
            lhs.underlyingSession == rhs
        }

        /// Enqueues a request to fetch an arbitrary resource.
        func enqueue(
            request: Request,
            intercepting completionHandler: (
                @Sendable (URL?, Result<URLResponse, Error>?) -> Void
            )? = nil
        ) {
            if let cached = tasks[request] {
                cached.resume(intercepting: completionHandler)
            } else {
                let task = Downloader.Task(session: underlyingSession, request: request)

                taskListLock.withLock {
                    tasks[request] = task
                }

                task.resume(intercepting: completionHandler)
            }
        }

        /// Cancels all the active tasks.
        func cancelAll() {
            logger.trace("[\(self.kind)] Trying to cancel tasks.")

            let _tasks = taskListLock.withLock { tasks }

            _tasks.values.forEach { $0.cancel() }
        }

        /// Pauses all the active tasks.
        func pauseAll() {
            logger.trace("[\(self.kind)] Trying to pause tasks.")

            let _tasks = taskListLock.withLock { tasks }

            _tasks.values.forEach { $0.pause() }
        }

        /// Resumes the paused tasks.
        func resumeAll() {
            logger.trace("[\(self.kind)] Trying to resume tasks.")

            let _tasks = taskListLock.withLock { tasks }

            _tasks.values.forEach { $0.resume() }
        }

        // Task

        func taskUpdated(_ task: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            let _tasks = taskListLock.withLock { tasks }

            let task = _tasks.first { key, _task in
                _task == task
            }

            guard let task else {
                logger.error("Finished a task without a reference.")
                return
            }

            task.value.taskUpdated(didFinishDownloadingTo: location)

            taskListLock.withLock {
                tasks[task.key] = nil
            }
        }

        func taskUpdated(
            _ task: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            let _tasks = taskListLock.withLock { tasks }

            let task = _tasks.values.first { _task in
                _task == task
            }

            guard let task else {
                logger.error("Task progressed without a reference.")
                return
            }

            task.taskUpdated(
                didWriteData: bytesWritten,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpectedToWrite: totalBytesExpectedToWrite
            )
        }

        func taskUpdated(
            _ task: URLSessionDownloadTask,
            didResumeAtOffset fileOffset: Int64,
            expectedTotalBytes: Int64
        ) {
            let _tasks = taskListLock.withLock { tasks }

            let task = _tasks.values.first { _task in
                _task == task
            }

            guard let task else {
                logger.error("Task resumed without a reference.")
                return
            }

            task.taskUpdated(didResumeAtOffset: fileOffset, expectedTotalBytes: expectedTotalBytes)
        }

        func taskUpdated(
            _ task: URLSessionDownloadTask,
            didCompleteWithError error: Error
        ) {
            let _tasks = taskListLock.withLock { tasks }

            let task = _tasks.values.first { _task in
                _task == task
            }

            guard let task else {
                logger.error("Task failed without a reference.")
                return
            }

            task.taskUpdated(didCompleteWithError: error)
        }

        func sessionDidFinishEvents(forBackgroundURLSession session: URLSession) {

        }

        // Descriptors

        public var description: String {
            "Session of \(kind) kind"
        }

        public var debugDescription: String {
            "Session of \(kind) kind holding reference to underlying session: \(underlyingSession)"
        }
    }
}
