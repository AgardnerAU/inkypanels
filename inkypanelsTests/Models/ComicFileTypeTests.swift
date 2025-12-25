import XCTest
@testable import InkyPanelsCore

final class ComicFileTypeTests: XCTestCase {

    func testInitFromExtension() {
        XCTAssertEqual(ComicFileType(from: "cbz"), .cbz)
        XCTAssertEqual(ComicFileType(from: "CBZ"), .cbz)
        XCTAssertEqual(ComicFileType(from: "cbr"), .cbr)
        XCTAssertEqual(ComicFileType(from: "pdf"), .pdf)
        XCTAssertEqual(ComicFileType(from: "jpg"), .jpg)
        XCTAssertEqual(ComicFileType(from: "jpeg"), .jpeg)
        XCTAssertEqual(ComicFileType(from: "7z"), .sevenZip)
        XCTAssertEqual(ComicFileType(from: "unknown"), .unknown)
    }

    func testIsComicArchive() {
        XCTAssertTrue(ComicFileType.cbz.isComicArchive)
        XCTAssertTrue(ComicFileType.cbr.isComicArchive)
        XCTAssertTrue(ComicFileType.cb7.isComicArchive)
        XCTAssertTrue(ComicFileType.cba.isComicArchive)
        XCTAssertFalse(ComicFileType.zip.isComicArchive)
        XCTAssertFalse(ComicFileType.pdf.isComicArchive)
        XCTAssertFalse(ComicFileType.png.isComicArchive)
    }

    func testIsArchive() {
        XCTAssertTrue(ComicFileType.cbz.isArchive)
        XCTAssertTrue(ComicFileType.zip.isArchive)
        XCTAssertTrue(ComicFileType.rar.isArchive)
        XCTAssertTrue(ComicFileType.sevenZip.isArchive)
        XCTAssertFalse(ComicFileType.pdf.isArchive)
        XCTAssertFalse(ComicFileType.png.isArchive)
    }

    func testIsImage() {
        XCTAssertTrue(ComicFileType.png.isImage)
        XCTAssertTrue(ComicFileType.jpg.isImage)
        XCTAssertTrue(ComicFileType.jpeg.isImage)
        XCTAssertTrue(ComicFileType.webp.isImage)
        XCTAssertFalse(ComicFileType.cbz.isImage)
        XCTAssertFalse(ComicFileType.pdf.isImage)
    }

    func testFileExtension() {
        XCTAssertEqual(ComicFileType.cbz.fileExtension, "cbz")
        XCTAssertEqual(ComicFileType.sevenZip.fileExtension, "7z")
    }

    func testCodable() throws {
        let original = ComicFileType.cbz
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ComicFileType.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }
}
