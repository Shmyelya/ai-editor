import Foundation
import SwiftData

@MainActor
@Observable
final class ChatListModel {
    func createChat(in context: ModelContext) -> UUID? {
        let chat = Chat(title: "Новый чат")
        context.insert(chat)
        do {
            try context.save()
            return chat.id
        } catch {
            context.rollback()
            return nil
        }
    }

    func delete(_ chat: Chat, in context: ModelContext) {
        context.delete(chat)
        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }

    func deleteEmptyChats(in context: ModelContext, keeping ids: Set<UUID> = []) {
        do {
            let chats = try context.fetch(FetchDescriptor<Chat>())
            let empty = chats.filter { $0.messages.isEmpty && !ids.contains($0.id) }
            guard !empty.isEmpty else { return }
            for chat in empty {
                context.delete(chat)
            }
            try context.save()
        } catch {
            context.rollback()
        }
    }
}
