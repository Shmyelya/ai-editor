import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class EditorModel {
    static let characterLimit = 4000

    var draft = ""
    var action: EditorAction = .paraphrase
    var language: TranslationLanguage = .en
    private(set) var resultText = ""
    private(set) var sourceText = ""
    private(set) var resultAction: EditorAction = .paraphrase
    private(set) var changeRibbon: WordChangeRibbon?
    private(set) var errorMessage: String?
    private(set) var saveErrorMessage: String?
    private(set) var isStreaming = false

    private var requestTask: Task<Void, Never>?
    private var requestGeneration = 0
    private var sentLanguage: TranslationLanguage = .en
    @ObservationIgnored private var attemptID: PersistentIdentifier?
    @ObservationIgnored private var requestContext: ModelContext?

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

    func launch(in context: ModelContext) {
        guard canLaunch, !isStreaming else { return }
        attemptID = nil
        sourceText = draft
        resultAction = action
        sentLanguage = language
        beginRequest(source: sourceText, action: resultAction, language: sentLanguage, context: context)
    }

    func stop(in context: ModelContext) {
        guard isStreaming else { return }
        requestGeneration += 1
        requestTask?.cancel()
        requestTask = nil
        storeChangeRibbon()
        isStreaming = false
        persist(in: context)
    }

    func retry(in context: ModelContext) {
        guard errorMessage != nil, !isStreaming else { return }
        beginRequest(source: sourceText, action: resultAction, language: sentLanguage, context: context)
    }

    func delete(_ edit: TextEdit, in context: ModelContext) {
        let identifier = edit.persistentModelID
        context.delete(edit)
        do {
            try context.save()
        } catch {
            context.rollback()
            saveErrorMessage = "Не удалось сохранить"
            return
        }
        if attemptID == identifier {
            attemptID = nil
        }
    }

    private func beginRequest(
        source: String,
        action: EditorAction,
        language: TranslationLanguage,
        context: ModelContext
    ) {
        requestTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        requestContext = context
        resultText = ""
        changeRibbon = nil
        errorMessage = nil
        saveErrorMessage = nil
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
        requestTask = nil
        storeChangeRibbon()
        isStreaming = false
        persistCurrentRequest()
    }

    private func failIfCurrent(_ error: Error, generation: Int) {
        guard generation == requestGeneration else { return }
        errorMessage = Self.message(for: error)
        requestTask = nil
        storeChangeRibbon()
        isStreaming = false
        persistCurrentRequest()
    }

    private func persistCurrentRequest() {
        guard let requestContext else { return }
        persist(in: requestContext)
    }

    private func persist(in context: ModelContext) {
        guard !resultText.isEmpty else { return }
        do {
            if let attemptID {
                let edits = try context.fetch(FetchDescriptor<TextEdit>())
                guard let edit = edits.first(where: { $0.persistentModelID == attemptID }) else {
                    saveErrorMessage = "Не удалось сохранить"
                    return
                }
                edit.resultText = resultText
                try context.save()
            } else {
                let edit = TextEdit(
                    sourceText: sourceText,
                    resultText: resultText,
                    action: resultAction.rawValue,
                    language: resultAction == .translate ? sentLanguage.rawValue : nil,
                    createdAt: Date()
                )
                context.insert(edit)
                try context.save()
                attemptID = edit.persistentModelID
            }
            saveErrorMessage = nil
        } catch {
            context.rollback()
            saveErrorMessage = "Не удалось сохранить"
        }
    }

    private func storeChangeRibbon() {
        guard !resultText.isEmpty, resultAction != .translate else {
            changeRibbon = nil
            return
        }
        changeRibbon = WordChangeRibbon(source: sourceText, result: resultText)
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
