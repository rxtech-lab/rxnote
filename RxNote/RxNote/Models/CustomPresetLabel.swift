import Foundation
import SwiftData

@Model
final class CustomPresetLabel {
    var category: String
    var label: String
    var createdAt: Date

    init(category: String, label: String) {
        self.category = category
        self.label = label
        self.createdAt = Date()
    }
}
