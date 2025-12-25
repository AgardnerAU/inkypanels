import XCTest
@testable import InkyPanelsCore

final class ReadingProgressTests: XCTestCase {

    func testPercentComplete() {
        let progress = ReadingProgress(
            comicId: UUID(),
            currentPage: 50,
            totalPages: 100
        )
        XCTAssertEqual(progress.percentComplete, 50.0)
    }

    func testPercentCompleteWithZeroPages() {
        let progress = ReadingProgress(
            comicId: UUID(),
            currentPage: 0,
            totalPages: 0
        )
        XCTAssertEqual(progress.percentComplete, 0.0)
    }

    func testHasStarted() {
        var progress = ReadingProgress(
            comicId: UUID(),
            currentPage: 0,
            totalPages: 100
        )
        XCTAssertFalse(progress.hasStarted)

        progress.currentPage = 1
        XCTAssertTrue(progress.hasStarted)
    }

    func testAddBookmark() {
        var progress = ReadingProgress(
            comicId: UUID(),
            currentPage: 0,
            totalPages: 100
        )

        progress.addBookmark(at: 10)
        XCTAssertEqual(progress.bookmarks, [10])

        progress.addBookmark(at: 5)
        XCTAssertEqual(progress.bookmarks, [5, 10]) // Should be sorted

        // Adding duplicate should not add again
        progress.addBookmark(at: 10)
        XCTAssertEqual(progress.bookmarks, [5, 10])
    }

    func testRemoveBookmark() {
        var progress = ReadingProgress(
            comicId: UUID(),
            currentPage: 0,
            totalPages: 100,
            bookmarks: [5, 10, 15]
        )

        progress.removeBookmark(at: 10)
        XCTAssertEqual(progress.bookmarks, [5, 15])

        // Removing non-existent bookmark should do nothing
        progress.removeBookmark(at: 100)
        XCTAssertEqual(progress.bookmarks, [5, 15])
    }

    func testToggleBookmark() {
        var progress = ReadingProgress(
            comicId: UUID(),
            currentPage: 0,
            totalPages: 100
        )

        progress.toggleBookmark(at: 10)
        XCTAssertTrue(progress.bookmarks.contains(10))

        progress.toggleBookmark(at: 10)
        XCTAssertFalse(progress.bookmarks.contains(10))
    }

    func testCodable() throws {
        let original = ReadingProgress(
            comicId: UUID(),
            currentPage: 25,
            totalPages: 100,
            lastReadDate: Date(),
            isCompleted: false,
            bookmarks: [5, 10, 15]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ReadingProgress.self, from: encoded)

        XCTAssertEqual(decoded.comicId, original.comicId)
        XCTAssertEqual(decoded.currentPage, original.currentPage)
        XCTAssertEqual(decoded.totalPages, original.totalPages)
        XCTAssertEqual(decoded.isCompleted, original.isCompleted)
        XCTAssertEqual(decoded.bookmarks, original.bookmarks)
    }
}
