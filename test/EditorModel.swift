import Foundation
import Observation

@MainActor
@Observable
final class EditorModel {
    static let characterLimit = 4000

    var draft = ""
    var action: EditorAction = .paraphrase
    var language: TranslationLanguage = .en
    private(set) var resultText = ""
    private(set) var errorMessage: String?
    private(set) var isStreaming = false

    private var requestTask: Task<Void, Never>?
    private var requestGeneration = 0
    private var sentSource = ""
    private var sentAction: EditorAction = .paraphrase
    private var sentLanguage: TranslationLanguage = .en

    var characterCount: Int {
        draft.count
    }

    var canLaunch: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func replaceDraft(_ text: String) {
        if text.count > Self.characterLimit {
            draft = String(text.prefix(Self.characterLimit))
        } else {
            draft = text
        }
    }

    func paste(_ text: String) {
        replaceDraft(text)
    }

    func clear() {
        draft = ""
    }

    func launch() {
        guard canLaunch, !isStreaming else { return }
        sentSource = draft
        sentAction = action
        sentLanguage = language
        beginRequest(source: sentSource, action: sentAction, language: sentLanguage)
    }

    func stop() {
        guard isStreaming else { return }
        requestGeneration += 1
        requestTask?.cancel()
        requestTask = nil
        isStreaming = false
    }

    func retry() {
        guard errorMessage != nil, !isStreaming else { return }
        beginRequest(source: sentSource, action: sentAction, language: sentLanguage)
    }

    private func beginRequest(source: String, action: EditorAction, language: TranslationLanguage) {
        requestTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        resultText = ""
        errorMessage = nil
        isStreaming = true

        let systemPrompt = action.systemPrompt(language: language)
        let service = GroqChatService()
        requestTask = Task {
            let stream = service.streamEdit(systemPrompt: systemPrompt, sourceText: source)
            do {
                for try await delta in stream {
                    try Task.checkCancellation()
                    guard generation == self.requestGeneration else { return }
                    self.resultText += delta
                }
                self.finishIfCurrent(generation)
            } catch is CancellationError {
                self.finishIfCurrent(generation)
            } catch {
                self.failIfCurrent(error, generation: generation)
            }
        }
    }

    private func finishIfCurrent(_ generation: Int) {
        guard generation == requestGeneration else { return }
        isStreaming = false
        requestTask = nil
    }

    private func failIfCurrent(_ error: Error, generation: Int) {
        guard generation == requestGeneration else { return }
        errorMessage = Self.message(for: error)
        isStreaming = false
        requestTask = nil
    }

    private static func message(for error: Error) -> String {
        guard let requestError = error as? GroqRequestError else {
            return "Не удалось получить ответ"
        }
        switch requestError {
        case .noNetwork:
            return "Нет сети"
        case .apiLimit:
            return "Кончился лимит API"
        case .failed:
            return "Не удалось получить ответ"
        }
    }
}
