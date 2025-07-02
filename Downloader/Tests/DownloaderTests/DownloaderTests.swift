import XCTest
@testable import Downloader

final class DownloaderTests: XCTestCase {
    func testExample() throws {
        let manager = DownloadManager(name: "TEST")

        let URLs: [URL] = try {
            [
            try XCTUnwrap(
                URL(string: "https://sample-files.com/downloads/documents/txt/simple.txt")
            ),
            try XCTUnwrap(
                URL(string: "https://sample-files.com/downloads/documents/txt/long-doc.txt")
            ),

            ]
        }()

        let requests = URLs.map { Downloader.Request.default($0) }

        requests.forEach { request in
            manager.register(request)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            manager.pauseAll()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                manager.resumeAll()
            }
        }

        let promise = expectation(description: "")

        wait(for: [promise], timeout: 10)
    }
}
