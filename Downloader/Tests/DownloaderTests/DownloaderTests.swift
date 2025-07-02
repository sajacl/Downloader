import XCTest
@testable import Downloader

final class DownloaderTests: XCTestCase {
    func testSingleFile() throws {
        let manager = DownloadManager(name: "TEST")

        let url: URL = try XCTUnwrap(
            URL(string: "https://sample-files.com/downloads/documents/txt/long-doc.txt")
        )

        let request = Downloader.Request(
            url,
            destination: Downloader.Destination(fullPath: URL(string: "Sajad/Downloads/simple.txt")!),
            keepAlive: false,
            shouldPersist: true,
            allowsCellularAccess: false,
            waitsForConnectivity: true
        )

        manager.register(request)

//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            manager.pauseAll()
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                manager.resumeAll()
//            }
//        }

        let promise = expectation(description: "")

        wait(for: [promise], timeout: 10)
    }

    func testBunch() throws {
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

        let requests = URLs.map {
            Downloader.Request(
                $0,
                destination: nil,
                keepAlive: false,
                shouldPersist: true,
                allowsCellularAccess: false,
                waitsForConnectivity: true
            )
        }

        requests.forEach { request in
            manager.register(request)
        }

        //        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //            manager.pauseAll()
        //
        //            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //                manager.resumeAll()
        //            }
        //        }

        let promise = expectation(description: "")

        wait(for: [promise], timeout: 10)
    }
}
