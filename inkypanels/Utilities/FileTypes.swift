import Foundation

/// Magic bytes for file type detection
enum FileMagic {
    static let zip: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
    static let zipEmpty: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
    static let zipSpanned: [UInt8] = [0x50, 0x4B, 0x07, 0x08]
    static let rar4: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]
    static let rar5: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]
    static let sevenZip: [UInt8] = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
    static let pdf: [UInt8] = [0x25, 0x50, 0x44, 0x46] // %PDF
    static let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    static let jpg: [UInt8] = [0xFF, 0xD8, 0xFF]
    static let gif87: [UInt8] = [0x47, 0x49, 0x46, 0x38, 0x37, 0x61] // GIF87a
    static let gif89: [UInt8] = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61] // GIF89a
    static let webp: [UInt8] = [0x52, 0x49, 0x46, 0x46] // RIFF (check for WEBP at offset 8)
    static let tiff_le: [UInt8] = [0x49, 0x49, 0x2A, 0x00] // Little-endian
    static let tiff_be: [UInt8] = [0x4D, 0x4D, 0x00, 0x2A] // Big-endian
}

/// File type detection utility
enum FileTypeDetector {
    /// Detect file type from magic bytes
    static func detectType(from data: Data) -> ComicFileType? {
        guard data.count >= 8 else { return nil }

        let bytes = [UInt8](data.prefix(8))

        // Check ZIP formats (CBZ)
        if bytes.starts(with: FileMagic.zip) ||
           bytes.starts(with: FileMagic.zipEmpty) ||
           bytes.starts(with: FileMagic.zipSpanned) {
            return .zip
        }

        // Check RAR formats (CBR)
        if bytes.starts(with: FileMagic.rar5) {
            return nil // RAR5 not supported, return nil to trigger error
        }
        if bytes.starts(with: FileMagic.rar4) {
            return .rar
        }

        // Check 7-Zip (CB7)
        if bytes.starts(with: FileMagic.sevenZip) {
            return .sevenZip
        }

        // Check PDF
        if bytes.starts(with: FileMagic.pdf) {
            return .pdf
        }

        // Check images
        if bytes.starts(with: FileMagic.png) {
            return .png
        }
        if bytes.starts(with: FileMagic.jpg) {
            return .jpg
        }
        if bytes.starts(with: FileMagic.gif87) || bytes.starts(with: FileMagic.gif89) {
            return .gif
        }
        if bytes.starts(with: FileMagic.tiff_le) || bytes.starts(with: FileMagic.tiff_be) {
            return .tiff
        }

        // WebP requires checking offset 8 for "WEBP"
        if bytes.starts(with: FileMagic.webp) && data.count >= 12 {
            let webpMarker = [UInt8](data[8..<12])
            if webpMarker == [0x57, 0x45, 0x42, 0x50] { // "WEBP"
                return .webp
            }
        }

        return nil
    }

    /// Check if a file is RAR5 format (not supported)
    static func isRAR5(data: Data) -> Bool {
        guard data.count >= 8 else { return false }
        let bytes = [UInt8](data.prefix(8))
        return bytes.starts(with: FileMagic.rar5)
    }
}

extension Array where Element == UInt8 {
    func starts(with other: [UInt8]) -> Bool {
        guard self.count >= other.count else { return false }
        return Array(self.prefix(other.count)) == other
    }
}
