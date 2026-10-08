import SwiftData
import SwiftUI

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Chat.updatedAt, order: .reverse) private var chats: [Chat]
    @State private var model = ChatListModel()
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if chats.isEmpty {
                    ContentUnavailableView {
                        Label("Пока нет чатов", systemImage: "bubble.left.and.bubble.right")
                    } actions: {
                        Button("Новый чат", action: createChat)
                    }
                } else {
                    List {
                        ForEach(chats) { chat in
                            NavigationLink(value: chat.id) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chat.title)
                                        .font(.body)
                                    Text(ChatListTime.label(for: chat.updatedAt))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Удалить", role: .destructive) {
                                    model.delete(chat, in: modelContext)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Чаты")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createChat) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Новый чат")
                }
            }
            .navigationDestination(for: UUID.self) { chatID in
                ChatView(chatID: chatID)
            }
        }
        .task {
            model.deleteEmptyChats(in: modelContext, keeping: Set(path))
        }
    }

    private func createChat() {
        guard let id = model.createChat(in: modelContext) else { return }
        path.append(id)
    }
}

@MainActor
private enum ChatListTime {
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .named
        return formatter
    }()

    static func label(for date: Date) -> String {
        formatter.localizedString(for: date, relativeTo: .now)
    }
}

#Preview {
    ChatListView()
        .modelContainer(for: Chat.self, inMemory: true)
}
