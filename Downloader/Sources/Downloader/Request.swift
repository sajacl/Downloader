import Foundation

extension Downloader {
    /// Object that describes a request for download a resource.
    public struct Request {
        // Kind? TASK?!
        public enum Kind: Hashable, Sendable {
            case foreground(isEphemeral: Bool)

            case background(Background)

            public static let `default`: Kind = .background(
                Background(
                    identifier: Bundle.main.bundleIdentifier!,
                    isDiscretionary: false,
                    sessionSendsLaunchEvents: true
                )
            )

            public struct Background: Hashable, Sendable {
                /// <#Description#>
                public let identifier: String

                /// A Boolean flag that determines whether background tasks can be scheduled at the discretion of the system for optimal performance.
                /// When set to true, the system schedules tasks at its discretion to optimise power and performance.
                /// (e.g., deferring tasks when the device is low on battery or the network is under heavy load).
                public var isDiscretionary: Bool

                /// A Boolean flag that indicates whether the app should be resumed or launched in the background when transfers finish.
                /// Allows the system to relaunch your app in the background when a background task completes or requires your app to handle an event.
                public var sessionSendsLaunchEvents: Bool
            }
        }

        /// Resource's url.
        public let source: URL

        /// Optional destination for the resource.
        public var destination: Destination?
        
        /// <#Description#>
        public let kind: Kind

        /// A Boolean flag that determines whether connections should be made over a cellular network.
        public var allowsCellularAccess: Bool
        
        /// A Boolean value that indicates whether the session should wait for connectivity to become available, or fail immediately.
        public var waitsForConnectivity: Bool

        public init(
            source: URL,
            destination: Destination? = nil,
            kind: Kind = .default,
            allowsCellularAccess: Bool,
            waitsForConnectivity: Bool
        ) {
            self.source = source
            self.destination = destination
            self.kind = kind
            self.allowsCellularAccess = allowsCellularAccess
            self.waitsForConnectivity = waitsForConnectivity
        }

        public init?(
            _ urlString: String,
            destination: Destination?,
            kind: Kind,
            allowsCellularAccess: Bool,
            waitsForConnectivity: Bool
        ) {
            guard let url = URL(string: urlString) else {
                return nil
            }

            self.source = url
            self.destination = destination
            self.kind = kind
            self.allowsCellularAccess = allowsCellularAccess
            self.waitsForConnectivity = waitsForConnectivity
        }

        public static func `default`(_ source: URL, destination: Destination? = nil) -> Request {
            Request(
                source: source,
                destination: destination,
                kind: .default,
                allowsCellularAccess: false,
                waitsForConnectivity: true
            )
        }

        public static func lowPriority(_ source: URL, destination: Destination? = nil) -> Request {
            Request(
                source: source,
                destination: destination,
                kind: .default,
                allowsCellularAccess: false,
                waitsForConnectivity: true
            )
        }

        func makeURLRequest() -> URLRequest {
            URLRequest(url: source)
        }
    }
}
