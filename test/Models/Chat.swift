import Foundation
import SwiftData

@Model
final class Chat {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Message.chat)
    var messages: [Message] = []

    init(title: String, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
