import Foundation

extension Downloader {
    /// Object representing a path to store a resource.
    public struct Destination: Equatable, Hashable,
                               Sendable,
                               CustomStringConvertible, CustomDebugStringConvertible {
        /// Path for the given resource without name and extension.
        public let path: URL

        /// Name of the resource + extension.
        public let fileName: String

        public init(path: URL, fileName: String) {
            self.path = path
            self.fileName = fileName
        }

        public init(fullPath: URL) {
            let fileName = fullPath.lastPathComponent
            let path = fullPath.deletingLastPathComponent()

            self.path = path
            self.fileName = fileName
        }

        var fullPath: URL {
            var url = path

            url.appendPathComponent(fileName)

            return url
        }

        public var description: String {
            path.absoluteString + fileName
        }

        public var debugDescription: String {
            path.absoluteString + fileName
        }
    }
}
