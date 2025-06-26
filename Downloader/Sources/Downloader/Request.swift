import Foundation

extension Downloader {
    /// Object that describes a request for download a resource.
    public struct Request {
        /// URL of the resource.
        public let url: URL

        /// Optional destination for the resource.
        public let destination: URL?

        public init(url: URL, destination: URL?) {
            self.url = url
            self.destination = destination
        }

        public init?(_ urlString: String, destination: URL?) {
            guard let url = URL(string: urlString) else {
                return nil
            }

            self.url = url
            self.destination = destination
        }
    }
}
