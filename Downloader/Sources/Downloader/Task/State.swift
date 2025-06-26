import Foundation

extension Downloader.Task {
    /// Object that describes a task's internal state.
    enum State: Equatable, Comparable {
        /// Task is queued and is waiting to be processed.
        case queued(Progress?)

        /// Task is currently running/downloading.
        case downloading(Progress)

        /// Task is completed and resource has been written to the given url.
        case completed(URL)

        /// Task has been failed with an error.
        case failed(Error)

        static func < (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
                case (.queued(let lhs), .queued(let rhs)):
                    if let lhs, let rhs {
                        return lhs < rhs
                    }

                    return false

                case (.downloading(let lhs), .downloading(let rhs)):
                    return lhs < rhs

                case (.completed, .completed):
                    return true

                case (.failed, .failed):
                    return true

                default:
                    return false
            }
        }

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
    }
}
