import Foundation
import OSLog

extension Downloader {
    // Request -> Queue -> UninitializedTask -> Manager -> InProgressTask

    /// Object that describes a download task.
    public final class Task: Equatable,
                             @unchecked Sendable,
                             CustomStringConvertible, CustomDebugStringConvertible {
        /// Task's identifier.
        let identifier: String

        /// Resource's request.
        private let request: Request

        private unowned let session: URLSession

        /// Systems token for download task.
        private let taskLock = NSLock()
        private var downloadTask: URLSessionDownloadTask?

        private let stateLock = NSLock()
        private var _state: State

        /// State of the current task.
        var state: State {
            get {
                stateLock.withLock { _state }
            }

            set {
                stateLock.withLock { _state = newValue }
            }
        }

        private let logger: Logger

        init(
            session: URLSession,
            request: Request
        ) {
            self.session = session
            self.identifier = Self.getTaskIdentifier(name: request.identifier)
            self.request = request

            _state = .queued(nil)

            logger = Logger(subsystem: "Downloader.Task", category: "\(request)")

            logger.trace("[identifier: '\(self.identifier)'] Created task.")
        }

        init(
            session: URLSession,
            request: Request,
            resumingFrom data: Data
        ) {
            self.session = session
            self.identifier = request.identifier
            self.request = request

            _state = .queued(data)

            logger = Logger(subsystem: "Downloader.Task", category: "\(request)")

            logger.trace("[identifier: '\(self.identifier)'] Created task.")
        }

        public static func == (lhs: Downloader.Task, rhs: Downloader.Task) -> Bool {
            let identifierComparison = lhs.identifier == rhs.identifier
            lazy var stateComparison = lhs.state == rhs.state

            return identifierComparison && stateComparison
        }

        public static func == (lhs: Downloader.Task, rhs: URLSessionDownloadTask) -> Bool {
            lhs.downloadTask == rhs
        }

        func resume(
            intercepting completionHandler: (
                @Sendable (URL?, Result<URLResponse, Error>?) -> Void
            )? = nil
        ) {
            switch state {
                case let .queued(resumableData):
                    if let resumableData {
                        tryResumeTask(from: resumableData, intercepting: completionHandler)
                    } else {
                        tryStartNewTask(intercepting: completionHandler)
                    }

                case let .suspended(resumableData):
                    tryResumeTask(from: resumableData, intercepting: completionHandler)

                case .downloading, .completed, .finished:
                    // no-op
                    return

                case .canceled, .failed:
                    // retry logic
                    break
            }
        }

        private func tryStartNewTask(
            intercepting completionHandler: (
                @Sendable (URL?, Result<URLResponse, Error>?) -> Void
            )? = nil
        ) {
            logger.trace("[identifier: '\(self.identifier)'] Starting task.")

            let dataTask: URLSessionDownloadTask

            if let completionHandler {
                dataTask = session.downloadTask(
                    with: request.makeURLRequest(),
                    completionHandler: { url, response, error in
                        let result: Result<URLResponse, Error>?

                        if let error {
                            result = .failure(error)
                        } else if let response {
                            result = .success(response)
                        } else {
                            result = nil
                        }

                        completionHandler(url, result)
                    }
                )
            } else {
                dataTask = session.downloadTask(with: request.makeURLRequest())
            }

            dataTask.resume()

            taskLock.withLock {
                downloadTask = dataTask
            }
        }

        private func tryResumeTask(
            from resumableData: Data,
            intercepting completionHandler: (@Sendable (URL?, Result<URLResponse, Error>?) -> Void)?
        ) {
            logger.trace("[identifier: '\(self.identifier)'] Resuming task.")

            let newTask: URLSessionDownloadTask

            if let completionHandler {
                newTask = session.downloadTask(
                    withResumeData: resumableData,
                    completionHandler: { url, response, error in
                        let result: Result<URLResponse, Error>?

                        if let error {
                            result = .failure(error)
                        } else if let response {
                            result = .success(response)
                        } else {
                            result = nil
                        }

                        completionHandler(url, result)
                    }
                )
            } else {
                newTask = session.downloadTask(
                    withResumeData: resumableData
                )
            }

            newTask.resume()

            // precondition(!(downloadTask == newTask))

            downloadTask = newTask
        }

        func pause() {
            logger.trace("[identifier: '\(self.identifier)'] Trying to pause task.")

            downloadTask!.cancel(byProducingResumeData: { [weak self] resumableData in
                guard let self else {
                    // no-op
                    return
                }

                self._pause(with: resumableData)
            })
        }

        func pause() async {
            logger.trace("[identifier: '\(self.identifier)'] Trying to pause task.")

            let resumableData = await downloadTask!.cancelByProducingResumeData()

            _pause(with: resumableData)
        }

        func _pause(with resumableData: Data?) {
            if let resumableData {
                state = .suspended(resumableData)

                logger.trace("[identifier: '\(self.identifier)'] Task paused.")
            } else {
                state = .failed(URLError(.cancelled))
                downloadTask!.cancel()

                logger.trace("[identifier: '\(self.identifier)'] Failed to pause task, canceled.")
            }
        }

        func cancel() {
            state = .canceled

            downloadTask!.cancel()

            logger.trace("[identifier: '\(self.identifier)'] Task canceled")
        }

        func taskUpdated(didFinishDownloadingTo location: URL) {
            logger.trace("[identifier: '\(self.identifier)'] Task finished downloading.")

            state = .completed(tempPath: location)

            let fileManager = FileManager.default

            // Determine the base file name (fallback to source filename)
            let fileName = request.destination?.fileName ?? request.source.lastPathComponent

            // Start with the temporary directory
            var persistencePath = fileManager.temporaryDirectory

            if let destinationDirectory = request.destination?.path {
                let customDirectory = persistencePath.appending(path: destinationDirectory.absoluteString)

                // Ensure the directory exists, or try to create it
                var isDirectory: ObjCBool = false
                let fileExists = fileManager.fileExists(
                    atPath: customDirectory.path,
                    isDirectory: &isDirectory
                )

                if !fileExists {
                    do {
                        try fileManager.createDirectory(
                            at: customDirectory,
                            withIntermediateDirectories: true
                        )

                        persistencePath = customDirectory
                    } catch {
                        // Fallback to temp directory if creation fails
                    }

                } else if isDirectory.boolValue {
                    persistencePath = customDirectory
                }
            }

            // Append the filename
            persistencePath = persistencePath.appendingPathComponent(fileName)

            do {
                // If a file already exists, remove it to avoid a crash
                if fileManager.fileExists(atPath: persistencePath.path) {
                    try fileManager.removeItem(at: persistencePath)
                }

                try fileManager.moveItem(at: location, to: persistencePath)

                logger.debug(
                    "[identifier: '\(self.identifier)'] Resource successfully moved file to '\(persistencePath.path)'."
                )

                state = .finished(finalPath: location)
            } catch {
                logger.error(
                    "[identifier: '\(self.identifier)'] Failed to move downloaded file: \(error.localizedDescription)"
                )

                state = .failed(error)
            }
        }

        func taskUpdated(
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            let progress = Progress(
                totalBytesWritten: UInt64(bytesWritten),
                totalBytesExpectedToWrite: UInt64(clamping: totalBytesExpectedToWrite)
            )

            state = .downloading(progress)

            logger.trace(
                "[identifier: '\(self.identifier)'] Task updated with progress: \(progress)."
            )
        }

        // not sure
        func taskUpdated(
            didResumeAtOffset fileOffset: Int64,
            expectedTotalBytes: Int64
        ) {
            let progress = Progress(
                totalBytesWritten: UInt64(fileOffset),
                totalBytesExpectedToWrite: UInt64(expectedTotalBytes)
            )

            state = .downloading(progress)

            logger.trace(
                "[identifier: '\(self.identifier)'] Task resumed offset: \(fileOffset), progress: \(progress)"
            )
        }

        func taskUpdated(didCompleteWithError error: Error) {
            if (error as? CancellationError) != nil {
                // no-op
                return
            }

            state = .failed(error)

            logger.trace(
                "[identifier: '\(self.identifier)'] Task failed with error: \(error.localizedDescription)"
            )
        }

        public var description: String {
            "Task"
        }

        public var debugDescription: String {
            "Task"
        }
    }
}

extension Downloader.Task {
    private static let nslock = NSLock()
    nonisolated(unsafe) private static var taskCount: UInt32 = 0

    fileprivate static func getTaskIdentifier(name: String) -> String {
        nslock.lock()
        defer { nslock.unlock() }

        let (partialValue, isOverflow) = taskCount.addingReportingOverflow(1)
        let nextValue = isOverflow ? 1 : partialValue
        taskCount = nextValue

        return "\(name).\(nextValue)"
    }
}
