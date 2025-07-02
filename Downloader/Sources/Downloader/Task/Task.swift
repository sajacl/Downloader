import Foundation
import OSLog

extension Downloader {
    /// Object that describes a download task.
    public final class Task: Equatable,
                             @unchecked Sendable,
                             CustomStringConvertible, CustomDebugStringConvertible {
        /// Task's identifier.
        let identifier: String

        /// Resource's url.
        private let source: URL

        /// Optional destination for the resource.
//        private let destinationLock = NSLock()
        private let destination: Destination?

        /// Systems token for download task.
//        private let taskLock = NSLock()
        private let downloadTask: URLSessionDownloadTask

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
            _ downloadTask: URLSessionDownloadTask,
            request: Request
        ) {
            self.downloadTask = downloadTask
            self.identifier = request.identifier
            self.source = request.source
            self.destination = request.destination

            _state = .queued(nil)

            logger = Logger(subsystem: "Downloader.Task", category: "\(request)")

            logger.trace("[identifier: '\(self.identifier)'] Created task.")
        }

        init(
            _ downloadTask: URLSessionDownloadTask,
            request: Request,
            resumingFrom data: Data
        ) {
            self.downloadTask = downloadTask
            self.identifier = request.identifier
            self.source = request.source
            self.destination = request.destination

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

        func resume() {
            switch state {
                case .downloading:
                    return

                case .completed:
                    return

                default:
                    break
            }

            downloadTask.resume()

            let asd = {
                switch downloadTask.state {
                    case .completed:
                        return "Completed"

                    case .canceling:
                        return "Canceling"

                    case .running:
                        return "Running"

                    case .suspended:
                        return "Suspended"

                    @unknown default:
                        return "Unknown"
                }
            }()

            logger.trace("[identifier: '\(self.identifier)'] Internal State: \(asd).")

            let key: String

            switch state {
                case .queued:
                    key = "Started"

                case .suspended:
                    key = "Resumed"

                case .canceled, .failed:
                    key = "Retried"

                default:
                    key = "_"
            }

            logger.trace("[identifier: '\(self.identifier)'] \(key) task.")
        }

//        func resume() /*-> AsyncStream<Progress>*/ {
//            let _state = stateLock.withLock { state }
//
//            if case let .suspended(resumeData) = _state {
//                if let progress = Self.extractProgress(from: resumeData) {
//                    stateLock.withLock {
//                        state = .downloading(progress)
//                    }
//                } else {
//                    fatalError()
////                    stateLock.withLock {
////                        state = .downloading(.zero)
////                    }
//                }
//
//                downloadTask.resume()
//            } else {
//                downloadTask.resume()
//            }
//        }

        private static func extractProgress(from data: Data) -> Progress? {
            do {
                guard let userInfo = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: Any],
                      let archive = userInfo["NSURLSessionResumeInfo"] as? [String: Any],
                      let totalBytesExpected = archive["NSURLSessionResumeBytesExpected"] as? NSNumber,
                      let currentOffset = archive["NSURLSessionResumeBytesReceived"] as? NSNumber else {
                    return nil
                }

                return Progress(
                    totalBytesWritten: currentOffset.uint64Value,
                    totalBytesExpectedToWrite: totalBytesExpected.uint64Value
                )
            } catch {
                return nil
            }
        }

        func pause(persist: Bool = false) {
            logger.trace("[identifier: '\(self.identifier)'] Trying to pause task.")

            downloadTask.cancel(byProducingResumeData: { [weak self] resumableData in
                guard let self else {
                    // no-op
                    return
                }

                self._pause(with: resumableData)
            })
        }

        func pause(persist: Bool = false) async {
            let resumableData = await downloadTask.cancelByProducingResumeData()

            _pause(with: resumableData)
        }

        func _pause(with resumableData: Data?) {
            if let resumableData {
                state = .suspended(resumableData)

                logger.trace("[identifier: '\(self.identifier)'] Task paused.")
            } else {
                state = .failed(URLError(.cancelled))
                downloadTask.cancel()

                logger.trace("[identifier: '\(self.identifier)'] Failed to pause task, canceled.")
            }
        }

        func cancel() {
            state = .canceled

            downloadTask.cancel()

            logger.trace("[identifier: '\(self.identifier)'] Task canceled")
        }

//        func updateDestination(_ newDestination: Destination) {
//            logger.debug(
//                "[identifier: '\(self.identifier)'] Destination updated for task to new destination '\(newDestination)'."
//            )
//
//            destinationLock.withLock {
//                destination = newDestination
//            }
//        }

        func taskUpdated(didFinishDownloadingTo location: URL) {
            logger.trace("[identifier: '\(self.identifier)'] Task finished downloading.")

            state = .completed(location)

            let location = destination?.fullPath ?? location

//            let tmpPath = location.path
//            let stableURL = FileManager.default.temporaryDirectory.appendingPathComponent("copiedDownload.dat")
//
//            try? FileManager.default.copyItem(atPath: tmpPath, toPath: stableURL.path)

            logger.debug(
                "[identifier: '\(self.identifier)'] Task finished writing to location '\(location)'."
            )
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

        func taskUpdated(didCompleteWithError error: Error?) {
            let error = error ?? URLError(.badServerResponse)

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

 // Request -> Queue -> UninitializedTask -> Manager -> InProgressTask
