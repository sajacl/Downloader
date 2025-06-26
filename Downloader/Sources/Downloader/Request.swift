import Foundation

extension Downloader {
    /// Object that describes a request for download a resource.
    public struct Request {
        /// Resource's url.
        public let source: URL

        /// Optional destination for the resource.
        public var destination: Destination?

        public init(url: URL, destination: Destination?) {
            self.source = url
            self.destination = destination
        }

        public init?(_ urlString: String, destination: Destination?) {
            guard let url = URL(string: urlString) else {
                return nil
            }

            self.source = url
            self.destination = destination
        }
    }
}
