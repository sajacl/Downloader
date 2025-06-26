import Foundation

extension Downloader {
    /// Object representing a path to store a resource.
    public struct Destination {
        /// Path for the given resource without name and extension.
        public let path: URL

        /// Name of the resource + extension.
        public let fileName: String?

        public init(path: URL, fileName: String?) {
            self.path = path
            self.fileName = fileName
        }

        public init(fullPath: URL) {
            let fileName = fullPath.lastPathComponent
            let path = fullPath.deletingLastPathComponent()

            self.path = path
            self.fileName = fileName
        }
    }
}
