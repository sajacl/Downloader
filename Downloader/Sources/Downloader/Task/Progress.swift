import Foundation

extension Downloader {
    public typealias TaskProgress = Task.Progress
}

extension Downloader.Task {
    /// Object that represents progress of a task.
    public struct Progress: Equatable, Comparable,
                            Sendable,
                            CustomStringConvertible, CustomDebugStringConvertible {
        /// Number of bytes that has been written for the given task.
        public var totalBytesWritten: UInt64

        /// Number of bytes that is expected to be written for a given task.
        public var totalBytesExpectedToWrite: UInt64

        init(totalBytesWritten: UInt64, totalBytesExpectedToWrite: UInt64) {
            self.totalBytesWritten = totalBytesWritten
            self.totalBytesExpectedToWrite = totalBytesExpectedToWrite
        }

        public static func < (lhs: Progress, rhs: Progress) -> Bool {
            lhs.totalBytesWritten < rhs.totalBytesWritten
        }

        /// Zero progress, indicating the task has not been started.
        public static let zero: Progress = Progress(
            totalBytesWritten: 0,
            totalBytesExpectedToWrite: 0
        )

        /// Percentage of completion as a value between 0 and 1 (e.g., 0.75 = 75%)
        public var fractionCompleted: Double {
            guard totalBytesExpectedToWrite > 0 else {
                return 0
            }

            return Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }

        /// Percentage of completion as an integer from 0 to 100
        public var percentageCompleted: UInt {
            UInt((fractionCompleted * 100))
        }

        public var description: String {
            "\(percentageCompleted)/100"
        }

        public var debugDescription: String {
            "\(totalBytesWritten)/\(totalBytesExpectedToWrite)"
        }
    }
}
