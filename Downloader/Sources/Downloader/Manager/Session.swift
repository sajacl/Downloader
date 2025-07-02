import Foundation
import OSLog

extension Downloader {
    // CachedSession?
    // DownloadSession?!
    final class Session: Equatable,
                         @unchecked Sendable,
                         CustomStringConvertible, CustomDebugStringConvertible {
        /// System's session.
        private let underlyingSession: URLSession

//        private let delegate: (any URLSessionDownloadDelegate)?

//        private let internalQueue = DispatchQueue(label: "Downloader.InternalQueue")

//        private let queue: OperationQueue?
        
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

            logger = Logger(subsystem: "\(kind)", category: "Downloader.Session")
        }

        static func == (lhs: Downloader.Session, rhs: Downloader.Session) -> Bool {
            let sessionComparison = lhs.underlyingSession == rhs.underlyingSession
            lazy var kindComparison = lhs.kind == rhs.kind

            return sessionComparison && kindComparison
        }

        static func == (lhs: Downloader.Session, rhs: URLSession) -> Bool {
            lhs.underlyingSession == rhs
        }
        
        /// Enqueues a request to fetch an arbitrary resource.
        func enqueue(
            request: Request,
            intercepting completionHandler: ((URL?, URLResponse?, (any Error)?) -> Void)?
        ) {
            if let cached = tasks[request] {
                continueOrRetryExistingTask(cached, with: request, intercepting: completionHandler)
            } else {
                generateAndStoreNewTask(for: request, intercepting: completionHandler)
            }
        }

        private func continueOrRetryExistingTask(
            _ task: Downloader.Task,
            with request: Request,
            intercepting completionHandler: ((URL?, URLResponse?, (any Error)?) -> Void)?
        ) {
            switch task.state {
                case .queued(_):
                    return

                case let .suspended(resumableData):
                    if let completionHandler {
                        let newTask = underlyingSession.downloadTask(
                            withResumeData: resumableData,
                            completionHandler: completionHandler
                        )

                        precondition(!(task == newTask))

                        newTask.resume()
                    } else {
                        let newTask = underlyingSession.downloadTask(
                            withResumeData: resumableData
                        )

                        precondition(!(task == newTask))

                        newTask.resume()
                    }

                case .downloading(_):
                    return

                case .completed(_):
                    return

                case .canceled:
                    return

                case .failed(_):
                    // retry
                    // if request.waitsForConnectivity
                    // generateAndStoreNewTask(for: request, intercepting: completionHandler)
                    return
            }
        }

        private func generateAndStoreNewTask(
            for request: Request,
            intercepting completionHandler: ((URL?, URLResponse?, (any Error)?) -> Void)?
        ) {
            let dataTask: URLSessionDownloadTask

            if let completionHandler {
                dataTask = underlyingSession.downloadTask(
                    with: request.makeURLRequest(),
                    completionHandler: completionHandler
                )
            } else {
                dataTask = underlyingSession.downloadTask(with: request.makeURLRequest())
            }

            let task = Downloader.Task(dataTask, request: request)

            taskListLock.withLock {
                tasks[request] = task
            }

            task.resume()
        }
        
        /// Cancels all the active tasks.
        func cancelAll() {
            let _tasks = taskListLock.withLock { tasks }

            _tasks.values.forEach { $0.cancel() }
        }
        
        /// Pauses all the active tasks.
        func pauseAll(persistState: Bool) {
            let _tasks = taskListLock.withLock { tasks }

            _tasks.values.forEach { task in
                task.pause()
            }
        }
        
        /// Resumes the paused tasks.
        func resumeAll() {
            let _tasks = taskListLock.withLock { tasks }

            _tasks.values.forEach { task in
                task.resume()
            }
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

        var description: String {
            "Session"
        }

        var debugDescription: String {
            "Session"
        }
    }
}
