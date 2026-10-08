import SwiftData
import SwiftUI

struct ChatView: View {
    let chatID: UUID
    var service: any ChatService = GroqChatService()
    var requestOnAppear = false
    @Query private var chats: [Chat]

    var body: some View {
        if let chat = chats.first(where: { $0.id == chatID }) {
            ChatScreen(chat: chat, service: service, requestOnAppear: requestOnAppear)
        }
    }
}

private struct ChatScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var chat: Chat
    let service: any ChatService
    var requestOnAppear = false
    @State private var model = ChatScreenModel()
    @State private var didRequestOnAppear = false
    @State private var followsBottom = true
    @State private var isAtBottom = true
    @State private var userIsDragging = false
    @State private var didDiscardEmptyChat = false
    @State private var didScrollToEndOnOpen = false
    @State private var endScroll = 0

    private static let feedEndID = "feed-end"
    private static let unansweredReply = "Ответ не получен"

    var body: some View {
        messages
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: requestOnAppear ? chat.messages.count : 0) {
            guard requestOnAppear, !didRequestOnAppear, chat.messages.contains(where: { $0.role == .user }) else { return }
            didRequestOnAppear = true
            model.retry(in: chat, context: modelContext, using: service)
        }
        .task {
            model.removeEmptyAssistantMessages(in: chat, context: modelContext)
        }
        .onDisappear {
            guard !didDiscardEmptyChat else { return }
            didDiscardEmptyChat = true
            model.stop()
            let chat = chat
            let context = modelContext
            Task { @MainActor in
                model.discardIfEmpty(chat, in: context)
            }
        }
    }

    private var messages: some View {
        let items = chat.messages.sorted { $0.createdAt < $1.createdAt }
        let visibleMessages = items.filter { !displayText(for: $0).isEmpty }
        return Group {
            if items.isEmpty && !model.isWaitingForText {
                ContentUnavailableView {
                    Label("Напишите сообщение", systemImage: "bubble.left")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    composer
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            VStack(spacing: 12) {
                                ForEach(visibleMessages) { message in
                                    MessageBubble(role: message.role, text: displayText(for: message))
                                }
                                if model.isWaitingForText {
                                    TypingIndicator()
                                }
                                if let errorMessage = model.errorMessage {
                                    errorBanner(errorMessage)
                                } else if showsUnansweredReply {
                                    errorBanner(Self.unansweredReply)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 12)
                            Color.clear
                                .frame(height: 0)
                                .id(Self.feedEndID)
                                .accessibilityHidden(true)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .defaultScrollAnchor(.bottom, for: .initialOffset)
                    .defaultScrollAnchor(.top, for: .alignment)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        Self.nearBottom(geometry)
                    } action: { _, atBottom in
                        isAtBottom = atBottom
                    }
                    .onScrollPhaseChange { oldPhase, newPhase, context in
                        updateFollow(
                            phase: newPhase,
                            previous: oldPhase,
                            atBottom: Self.nearBottom(context.geometry)
                        )
                    }
                    .onChange(of: isAtBottom) { _, atBottom in
                        guard userIsDragging, !atBottom else { return }
                        followsBottom = false
                    }
                    .onChange(of: endScroll) { _, _ in
                        scrollToFeedEnd(proxy)
                    }
                    .onChange(of: model.streamingText) { _, text in
                        guard !text.isEmpty else { return }
                        scrollToFeedEnd(proxy)
                    }
                    .onChange(of: model.errorMessage) { _, message in
                        guard message != nil else { return }
                        scrollToFeedEnd(proxy)
                    }
                    .onAppear {
                        guard !didScrollToEndOnOpen else { return }
                        didScrollToEndOnOpen = true
                        followsBottom = true
                        Task { @MainActor in
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                proxy.scrollTo(Self.feedEndID, anchor: .bottom)
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        composer
                    }
                }
            }
        }
    }

    private var showsUnansweredReply: Bool {
        guard !model.isGenerating else { return false }
        let last = chat.messages.max { $0.createdAt < $1.createdAt }
        return last?.role == .user
    }

    private var composer: some View {
        @Bindable var model = model
        return HStack(alignment: .bottom, spacing: 8) {
            TextField("Сообщение", text: $model.draft, axis: .vertical)
                .font(.body)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if model.isGenerating {
                ComposerButton(systemName: "stop.fill", label: "Стоп", action: stop)
            } else {
                ComposerButton(systemName: "arrow.up", label: "Отправить", action: send)
                    .disabled(!model.canSend)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func displayText(for message: Message) -> String {
        if message.id == model.streamingMessageID {
            return model.streamingText
        }
        return message.text
    }

    private func send() {
        followsBottom = true
        model.send(in: chat, context: modelContext, using: service)
        endScroll += 1
    }

    private static func nearBottom(_ geometry: ScrollGeometry) -> Bool {
        let threshold: CGFloat = 40
        if geometry.contentSize.height <= geometry.containerSize.height + threshold {
            return true
        }
        return geometry.contentSize.height - geometry.visibleRect.maxY <= threshold
    }

    private func updateFollow(phase: ScrollPhase, previous: ScrollPhase, atBottom: Bool) {
        if phase == .interacting {
            userIsDragging = true
            if !atBottom {
                followsBottom = false
            }
            return
        }
        if phase == .decelerating {
            if userIsDragging, !atBottom {
                followsBottom = false
            }
            return
        }
        if phase == .idle {
            userIsDragging = false
            if previous == .interacting || previous == .decelerating, atBottom {
                followsBottom = true
            }
        }
    }

    private func retry() {
        followsBottom = true
        model.retry(in: chat, context: modelContext, using: service)
        endScroll += 1
    }

    private func scrollToFeedEnd(_ proxy: ScrollViewProxy) {
        guard followsBottom else { return }
        Task { @MainActor in
            guard followsBottom else { return }
            proxy.scrollTo(Self.feedEndID, anchor: .bottom)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Label {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Повторить", action: retry)
                .buttonStyle(.bordered)
                .layoutPriority(1)
        }
    }

    private func stop() {
        model.stop()
    }
}

private enum BubbleStyle {
    static let cornerRadius: CGFloat = 18
    static let maxWidthFraction: CGFloat = 0.8
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 8

    static func fill(isUser: Bool) -> Color {
        isUser ? Color.accentColor : Color(.secondarySystemBackground)
    }
}

private struct MessageBubble: View {
    let role: MessageRole
    let text: String

    var body: some View {
        BubbleWidthLayout(maxFraction: BubbleStyle.maxWidthFraction, alignTrailing: role == .user) {
            bubbleText
                .padding(.horizontal, BubbleStyle.horizontalPadding)
                .padding(.vertical, BubbleStyle.verticalPadding)
                .background(
                    BubbleStyle.fill(isUser: role == .user),
                    in: RoundedRectangle(cornerRadius: BubbleStyle.cornerRadius, style: .continuous)
                )
        }
    }

    @ViewBuilder
    private var bubbleText: some View {
        if role == .assistant {
            messageText
                .font(.body)
                .foregroundStyle(Color.primary)
                .textSelection(.enabled)
        } else {
            messageText
                .font(.body)
                .foregroundStyle(Color.white)
        }
    }

    private var messageText: Text {
        if let attributed = assistantMarkdown {
            Text(attributed)
        } else {
            Text(text)
        }
    }

    private var assistantMarkdown: AttributedString? {
        guard role == .assistant else { return nil }
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .throwError
        )
        return try? AttributedString(markdown: text, options: options)
    }
}

private struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        BubbleWidthLayout(maxFraction: BubbleStyle.maxWidthFraction, alignTrailing: false) {
            bubble
        }
        .accessibilityHidden(true)
    }

    private var bubble: some View {
        Group {
            if reduceMotion {
                dots(activeIndex: nil)
            } else {
                PhaseAnimator([0, 1, 2]) { phase in
                    dots(activeIndex: phase)
                } animation: { _ in
                    .easeInOut(duration: 0.4)
                }
            }
        }
        .padding(.horizontal, BubbleStyle.horizontalPadding)
        .padding(.vertical, BubbleStyle.verticalPadding)
        .background(
            BubbleStyle.fill(isUser: false),
            in: RoundedRectangle(cornerRadius: BubbleStyle.cornerRadius, style: .continuous)
        )
    }

    private func dots(activeIndex: Int?) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(activeIndex == index ? 1.6 : 1)
            }
        }
    }
}

private struct ComposerButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct BubbleWidthLayout: Layout {
    var maxFraction: CGFloat
    var alignTrailing: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let maxWidth = maximumWidth(for: proposal.width)
        let child = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: proposal.height))
        let width = proposal.width ?? child.width
        return CGSize(width: width, height: child.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let subview = subviews.first else { return }
        let availableWidth = bounds.width > 0 ? bounds.width : proposal.width
        let maxWidth = maximumWidth(for: availableWidth)
        let measurement = ProposedViewSize(width: maxWidth, height: nil)
        let size = subview.sizeThatFits(measurement)
        let fittedWidth = min(size.width, maxWidth ?? size.width)
        let x = alignTrailing ? bounds.maxX - fittedWidth : bounds.minX
        subview.place(
            at: CGPoint(x: x, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: fittedWidth, height: size.height)
        )
    }

    private func maximumWidth(for width: CGFloat?) -> CGFloat? {
        guard let width, width.isFinite else { return nil }
        return width * maxFraction
    }
}

#Preview("Лимит API") {
    APILimitPreview()
        .modelContainer(for: Chat.self, inMemory: true)
}

private struct APILimitPreview: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Chat.createdAt) private var chats: [Chat]
    @State private var didPrepare = false

    var body: some View {
        NavigationStack {
            if let chat = chats.first {
                ChatView(
                    chatID: chat.id,
                    service: APILimitPreviewService(),
                    requestOnAppear: true
                )
            }
        }
        .task {
            guard !didPrepare else { return }
            didPrepare = true
            guard chats.isEmpty else { return }

            let chat = Chat(title: "Новый чат")
            let message = Message(role: .user, text: "Привет")
            modelContext.insert(chat)
            modelContext.insert(message)
            message.chat = chat
            if !chat.messages.contains(where: { $0.id == message.id }) {
                chat.messages.append(message)
            }

            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
            }
        }
    }
}

private struct APILimitPreviewService: ChatService {
    private static let responseStatusCode = 429
    private static let responseBody = """
    {"error":{"message":"Rate limit reached","type":"tokens","code":"rate_limit_exceeded"}}
    """

    func streamReply(to _: [ChatServiceMessage]) -> AsyncThrowingStream<String, any Error> {
        let failure = groqChatFailure(statusCode: Self.responseStatusCode, body: Self.responseBody)
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: failure)
        }
    }
}
