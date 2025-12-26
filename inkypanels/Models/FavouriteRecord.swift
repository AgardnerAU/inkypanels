import Foundation
import SwiftData

/// SwiftData model for tracking favourite files
@Model
final class FavouriteRecord {
    /// File path as stable identifier
    @Attribute(.unique) var filePath: String

    /// When this file was favourited
    var addedDate: Date

    init(filePath: String, addedDate: Date = Date()) {
        self.filePath = filePath
        self.addedDate = addedDate
    }
}
