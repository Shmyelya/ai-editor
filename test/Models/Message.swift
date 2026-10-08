import Foundation
import SwiftData

@Model
final class Message {
    var id: UUID
    var createdAt: Date
    var role: MessageRole
    var text: String
    var chat: Chat?

    init(role: MessageRole, text: String, createdAt: Date = .now, chat: Chat? = nil) {
        self.id = UUID()
        self.createdAt = createdAt
        self.role = role
        self.text = text
        self.chat = chat
    }
}
