import XCTest
@testable import InkyPanelsCore

final class FileTypeDetectorTests: XCTestCase {

    func testDetectZIPFormat() {
        let zipData = Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(FileTypeDetector.detectType(from: zipData), .zip)
    }

    func testDetectRAR4Format() {
        let rar4Data = Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00, 0x00])
        XCTAssertEqual(FileTypeDetector.detectType(from: rar4Data), .rar)
    }

    func testDetectRAR5FormatReturnsNil() {
        // RAR5 is not supported, should return nil
        let rar5Data = Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00])
        XCTAssertNil(FileTypeDetector.detectType(from: rar5Data))
    }

    func testIsRAR5() {
        let rar5Data = Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00])
        XCTAssertTrue(FileTypeDetector.isRAR5(data: rar5Data))

        let rar4Data = Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00, 0x00])
        XCTAssertFalse(FileTypeDetector.isRAR5(data: rar4Data))
    }

    func testDetect7zFormat() {
        let sevenZipData = Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0x00, 0x00])
        XCTAssertEqual(FileTypeDetector.detectType(from: sevenZipData), .sevenZip)
    }

    func testDetectPDFFormat() {
        let pdfData = Data([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]) // %PDF-1.4
        XCTAssertEqual(FileTypeDetector.detectType(from: pdfData), .pdf)
    }

    func testDetectPNGFormat() {
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        XCTAssertEqual(FileTypeDetector.detectType(from: pngData), .png)
    }

    func testDetectJPGFormat() {
        let jpgData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46])
        XCTAssertEqual(FileTypeDetector.detectType(from: jpgData), .jpg)
    }

    func testDetectGIFFormat() {
        let gif89Data = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x00, 0x00])
        XCTAssertEqual(FileTypeDetector.detectType(from: gif89Data), .gif)
    }

    func testDetectTIFFFormat() {
        let tiffLEData = Data([0x49, 0x49, 0x2A, 0x00, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(FileTypeDetector.detectType(from: tiffLEData), .tiff)
    }

    func testDetectWebPFormat() {
        // RIFF....WEBP
        var webpData = Data([0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00])
        webpData.append(contentsOf: [0x57, 0x45, 0x42, 0x50]) // WEBP
        XCTAssertEqual(FileTypeDetector.detectType(from: webpData), .webp)
    }

    func testEmptyDataReturnsNil() {
        XCTAssertNil(FileTypeDetector.detectType(from: Data()))
    }

    func testTooShortDataReturnsNil() {
        let shortData = Data([0x50, 0x4B])
        XCTAssertNil(FileTypeDetector.detectType(from: shortData))
    }
}
