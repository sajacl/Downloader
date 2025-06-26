import Foundation

extension Downloader.Task {
    /// Object that represents progress of a task.
    public struct Progress: Equatable, Comparable {
        /// Process of the task that can be started from 0, or being resumed from a progress.
        public var partialProgress: Float

        /// Number of bytes that has been written for the given task.
        public var totalBytesWritten: UInt64?

        init(_ progress: Float, totalBytesWritten: UInt64? = nil) {
            self.partialProgress = progress
            self.totalBytesWritten = totalBytesWritten
        }
        
        /// Zero progress, indicating the task has not been started.
        @MainActor static let zero: Progress = Progress(0)

        public static func < (lhs: Progress, rhs: Progress) -> Bool {
            let progressComparison = lhs.partialProgress < rhs.partialProgress

            lazy var bytesWrittenComparison: Bool = {
                guard let lhsTotalBytesWritten = lhs.totalBytesWritten,
                      let rhsTotalBytesWritten = rhs.totalBytesWritten else {
                    return true
                }
                
                return lhsTotalBytesWritten < rhsTotalBytesWritten
            }()

            return progressComparison && bytesWrittenComparison
        }
    }
}
