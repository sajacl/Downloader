import Foundation

extension Downloader {
    /// Object that describes a request for download a resource.
    public struct Request: Equatable, Hashable,
                           Sendable,
                           CustomStringConvertible, CustomDebugStringConvertible {
        /// Resource's url.
        public let source: URL
        
        /// Request id.
        public let identifier: String

        /// Optional destination for the resource.
        public var destination: Destination?

        /// Flag that indicates if the request should be kept alive;
        /// Taking advantage of URLSession's daemon.
        public var keepAlive: Bool

        /// Flag that indicates if the request should proceed anonymously.
        public var shouldPersist: Bool

        /// A Boolean flag that determines whether connections should be made over a cellular network.
        public var allowsCellularAccess: Bool
        
        /// A Boolean value that indicates whether the session should wait for connectivity to become available, or fail immediately.
        public var waitsForConnectivity: Bool

        public init(
            _ source: URL,
            identifier: String? = nil,
            destination: Destination?,
            keepAlive: Bool,
            shouldPersist: Bool,
            allowsCellularAccess: Bool,
            waitsForConnectivity: Bool
        ) {
            self.source = source
            self.identifier = identifier ?? source.absoluteString
            self.destination = destination
            self.keepAlive = keepAlive
            self.shouldPersist = shouldPersist
            self.allowsCellularAccess = allowsCellularAccess
            self.waitsForConnectivity = waitsForConnectivity
        }

        public init?(
            _ urlString: String,
            identifier: String? = nil,
            destination: Destination?,
            keepAlive: Bool,
            shouldPersist: Bool,
            allowsCellularAccess: Bool,
            waitsForConnectivity: Bool
        ) {
            guard let url = URL(string: urlString) else {
                return nil
            }

            self.source = url
            self.identifier = identifier ?? urlString
            self.destination = destination
            self.keepAlive = keepAlive
            self.shouldPersist = shouldPersist
            self.allowsCellularAccess = allowsCellularAccess
            self.waitsForConnectivity = waitsForConnectivity
        }

        public static func `default`(_ source: URL, destination: Destination? = nil) -> Request {
            Request(
                source,
                destination: destination,
                keepAlive: true,
                shouldPersist: true,
                allowsCellularAccess: false,
                waitsForConnectivity: true
            )
        }

        public static func lowPriority(_ source: URL, destination: Destination? = nil) -> Request {
            Request(
                source,
                destination: destination,
                keepAlive: true,
                shouldPersist: false,
                allowsCellularAccess: false,
                waitsForConnectivity: true
            )
        }

        func makeURLRequest() -> URLRequest {
            URLRequest(url: source)
        }

        public var description: String {
            source.absoluteString
        }

        public var debugDescription: String {
            source.absoluteString
        }
    }
}
