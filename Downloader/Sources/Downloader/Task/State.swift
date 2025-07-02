import Foundation

extension Downloader.Task {
    /// Object that describes a task's internal state.
    enum State: Equatable, /*Comparable,*/
                Sendable,
                CustomStringConvertible, CustomDebugStringConvertible {
        /// Task is queued and is waiting to be processed.
        case queued(Data?)

        /// Task has been suspended/paused with the needed data to resume.
        case suspended(Data)

        // aka handed over to system
        /// Task is currently running/downloading.
        case downloading(Progress)

        /// Task is completed and resource has been written to the given url.
        case completed(tempPath: URL)

        case finished(finalPath: URL)

        /// Task has been canceled.
        case canceled

        /// Task has been failed with an error.
        case failed(Error)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
                case (.queued(let lhs), .queued(let rhs)):
                    if let lhs, let rhs {
                        return lhs == rhs
                    }

                    return false

                case (.downloading(let lhs), .downloading(let rhs)):
                    return lhs == rhs

                case (.completed(let lhs), .completed(let rhs)):
                    return lhs == rhs

                case (.failed, .failed):
                    return true

                default:
                    return false
            }
        }

        var description: String {
            switch self {
                case .queued:
                    return "Queued"

                case .suspended:
                    return "Suspended"

                case let .downloading(progress):
                    return "Downloading with progress \(progress)"

                case .completed:
                    return "Completed"

                case .finished:
                    return "Finished"

                case .canceled:
                    return "Canceled"

                case let .failed(error):
                    return error.localizedDescription
            }
        }

        var debugDescription: String {
            switch self {
                case let .queued(data):
                    if let data, let dataDesc = String(data: data, encoding: .utf8) {
                        return "Restored with data: (\(dataDesc))"
                    } else {
                        return "Queued"
                    }

                case let .suspended(data):
                    if let dataDesc = String(data: data, encoding: .utf8) {
                        return "Paused with resumable data: (\(dataDesc))"
                    } else {
                        return "Paused"
                    }

                case let .downloading(progress):
                    return "Downloading with progress \(progress)"

                case let .completed(tempLocation):
                    return "Download completed with temporary path: \(tempLocation.absoluteString)"

                case let .finished(location):
                    return "Finished task with resource path: \(location.absoluteString)"

                case .canceled:
                    return "Canceled"

                case let .failed(error):
                    return error.localizedDescription
            }
        }
    }
}
