import Foundation

extension Downloader {
    /// Default download manager, that will be used for simple tasks.
    static let `default` = Manager(name: "Default")
    
    /// Register's requests on default download manager.
    public static func register(
        _ request: Request,
        intercepting completionHandler: (
            @Sendable (URL?, Result<URLResponse, Error>?) -> Void
        )? = nil
    ) {
        `default`.register(request, intercepting: completionHandler)
    }
}
