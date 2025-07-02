import XCTest
@testable import Downloader

final class TaskTests: XCTestCase {
    func testProgressFraction() {
        let progress = Downloader.Task.Progress.halfway

        XCTAssertEqual(progress.fractionCompleted, 0.5)
    }

    func testProgressPercentage() {
        let progress = Downloader.Task.Progress.halfway

        XCTAssertEqual(progress.percentageCompleted, 50)
    }
}

extension Downloader.TaskProgress {
    fileprivate static var halfway: Downloader.TaskProgress {
        Downloader.Task.Progress(
            totalBytesWritten: 500,
            totalBytesExpectedToWrite: 1000
        )
    }
}
