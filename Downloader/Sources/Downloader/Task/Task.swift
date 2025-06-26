import Foundation

extension Downloader {
    /// Object that describes a download task.
    public final class Task: Equatable {
        /// Task's identifier.
        public let identifier: String

        /// Resource's url.
        public let source: URL

        /// Optional destination for the resource.
        public var destination: Destination?
        
        /// State of the current task.
        private(set) var state: State
        
        /// Number of bytes that the file contains,
        /// aka Size of the file in bytes.
        private let totalBytesExpectedToWrite: UInt64

        private(set) var position: UInt?

        init(
            request: Request,
            identifier: String?,
            state: State = .queued(nil),
            totalBytesExpectedToWrite: UInt64
        ) {
            self.identifier = identifier ?? request.identifier

            self.source = request.source
            self.destination = request.destination
            self.state = state
            self.totalBytesExpectedToWrite = totalBytesExpectedToWrite
        }

        public static func == (lhs: Downloader.Task, rhs: Downloader.Task) -> Bool {
            let identifierComparison = lhs.identifier == rhs.identifier
            lazy var stateComparison = lhs.state == rhs.state

            return identifierComparison && stateComparison
        }
    }
}

extension Downloader.Request {
    fileprivate var identifier: String {
        source.absoluteString
    }
}
