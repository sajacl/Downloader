import Foundation

extension Downloader.Session {
    public enum Kind: Hashable,
                      Sendable,
                      CustomStringConvertible, CustomDebugStringConvertible {
        case foreground(isEphemeral: Bool)

        case background(Background)

        public struct Background: Hashable, Sendable {
            /// Unique identifier for background session.
            public let identifier: String

            /// A Boolean flag that determines whether background tasks can be scheduled at the discretion of the system for optimal performance.
            /// When set to true, the system schedules tasks at its discretion to optimise power and performance.
            /// (e.g., deferring tasks when the device is low on battery or the network is under heavy load).
            public var isDiscretionary: Bool

            /// A Boolean flag that indicates whether the app should be resumed or launched in the background when transfers finish.
            /// Allows the system to relaunch your app in the background when a background task completes or requires your app to handle an event.
            public var sessionSendsLaunchEvents: Bool

            public static let `default`: Self = Background(
                identifier: Bundle.main.bundleIdentifier!,
                isDiscretionary: false,
                sessionSendsLaunchEvents: true
            )
        }

        public var description: String {
            switch self {
                case let .foreground(isEphemeral):
                    return isEphemeral ? "Ephemeral" : "Persisted"

                case .background:
                    return "Background"
            }
        }

        public var debugDescription: String {
            switch self {
                case let .foreground(isEphemeral):
                    return isEphemeral ? "Ephemeral" : "Persisted"

                case let .background(task):
                    return "Background with identifier \(task.identifier)"
            }
        }
    }
}
