import Foundation
import SwiftData

@MainActor
@Observable
final class ChatScreenModel {
    var draft = ""
    private(set) var errorMessage: String?
    private(set) var isWaitingForText = false
    private(set) var streamingMessageID: UUID?
    private(set) var streamingText = ""

    private(set) var isGenerating = false
    private var accumulated = ""
    private var lastPersistedAt: ContinuousClock.Instant?
    private var replyMessage: Message?
    private var requestTask: Task<Void, Never>?

    private static let noNetwork = "Нет сети"
    private static let apiLimit = "Кончился лимит API"
    private static let requestFailure = "Не удалось получить ответ"
    private static let saveInterval: Duration = .milliseconds(500)

    var canSend: Bool {
        !isGenerating && !trimmedDraft.isEmpty
    }

    func send(in chat: Chat, context: ModelContext, using service: any ChatService) {
        let text = trimmedDraft
        guard !text.isEmpty, !isGenerating else { return }

        let isFirstUserMessage = !chat.messages.contains { $0.role == .user }
        let message = Message(role: .user, text: text)
        context.insert(message)
        message.chat = chat
        if !chat.messages.contains(where: { $0.id == message.id }) {
            chat.messages.append(message)
        }

        if isFirstUserMessage {
            chat.title = title(from: text)
        }
        chat.updatedAt = .now

        do {
            try context.save()
        } catch {
            context.rollback()
            return
        }

        draft = ""
        let transcript = chat.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { ChatServiceMessage(role: $0.role.rawValue, content: $0.text) }
        startStreaming(transcript, in: chat, context: context, using: service)
    }

    func retry(in chat: Chat, context: ModelContext, using service: any ChatService) {
        guard !isGenerating else { return }

        let sorted = chat.messages.sorted { $0.createdAt < $1.createdAt }
        guard let lastUserIndex = sorted.lastIndex(where: { $0.role == .user }) else { return }

        let transcript = sorted[...lastUserIndex].map { message in
            ChatServiceMessage(role: message.role.rawValue, content: message.text)
        }
        startStreaming(transcript, in: chat, context: context, using: service)
    }

    func stop() {
        requestTask?.cancel()
    }

    func removeEmptyAssistantMessages(in chat: Chat, context: ModelContext) {
        let empty = chat.messages.filter { $0.role == .assistant && $0.text.isEmpty }
        guard !empty.isEmpty else { return }
        for message in empty {
            context.delete(message)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }

    func discardIfEmpty(_ chat: Chat, in context: ModelContext) {
        guard chat.messages.isEmpty else { return }
        context.delete(chat)
        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }

    private func startStreaming(
        _ transcript: [ChatServiceMessage],
        in chat: Chat,
        context: ModelContext,
        using service: any ChatService
    ) {
        errorMessage = nil
        accumulated = ""
        lastPersistedAt = nil
        replyMessage = nil
        streamingMessageID = nil
        streamingText = ""
        isWaitingForText = true
        isGenerating = true

        let stream = service.streamReply(to: transcript)
        requestTask = Task {
            await consume(stream: stream, chat: chat, context: context)
        }
    }

    private func consume(
        stream: AsyncThrowingStream<String, any Error>,
        chat: Chat,
        context: ModelContext
    ) async {
        defer { finishPresentation() }

        do {
            for try await delta in stream {
                try Task.checkCancellation()
                try append(delta, to: chat, context: context)
            }
            try persist(in: chat, context: context, force: true)
        } catch is CancellationError {
            saveAfterInterruption(in: chat, context: context)
        } catch let error as ChatServiceError {
            saveAfterInterruption(in: chat, context: context)
            errorMessage = message(for: error)
        } catch {
            saveAfterInterruption(in: chat, context: context)
            errorMessage = Self.requestFailure
        }
    }

    private func append(_ delta: String, to chat: Chat, context: ModelContext) throws {
        accumulated += delta
        guard !accumulated.isEmpty else { return }
        if replyMessage == nil {
            let message = Message(role: .assistant, text: accumulated)
            context.insert(message)
            message.chat = chat
            if !chat.messages.contains(where: { $0.id == message.id }) {
                chat.messages.append(message)
            }
            replyMessage = message
            streamingMessageID = message.id
            isWaitingForText = false
        }
        streamingText = accumulated
        try persist(in: chat, context: context, force: false)
    }

    private func saveAfterInterruption(in chat: Chat, context: ModelContext) {
        if accumulated.isEmpty, let replyMessage {
            context.delete(replyMessage)
            self.replyMessage = nil
            streamingMessageID = nil
            streamingText = ""
            do {
                try context.save()
            } catch {
                context.rollback()
                errorMessage = Self.requestFailure
            }
            return
        }
        do {
            try persist(in: chat, context: context, force: true)
        } catch {
            errorMessage = Self.requestFailure
        }
    }

    private func persist(in chat: Chat, context: ModelContext, force: Bool) throws {
        guard let replyMessage, !accumulated.isEmpty else { return }

        let now = ContinuousClock.now
        if !force, let lastPersistedAt, lastPersistedAt.duration(to: now) < Self.saveInterval {
            return
        }

        replyMessage.text = accumulated
        chat.updatedAt = .now
        try context.save()
        lastPersistedAt = now
    }

    private func finishPresentation() {
        isGenerating = false
        isWaitingForText = false
        streamingMessageID = nil
        streamingText = ""
        replyMessage = nil
        requestTask = nil
    }

    private func message(for error: ChatServiceError) -> String {
        switch error {
        case .noNetwork:
            Self.noNetwork
        case .apiLimit:
            Self.apiLimit
        case .failed:
            Self.requestFailure
        }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func title(from text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmedLine = firstLine.trimmingCharacters(in: .whitespaces)
        let value = trimmedLine.isEmpty ? text : trimmedLine
        return String(value.prefix(40))
    }
}
