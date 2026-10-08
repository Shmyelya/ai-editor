import Observation

@MainActor
@Observable
final class EditorModel {
    static let characterLimit = 4000

    var draft = ""
    var action: EditorAction = .paraphrase
    var language: TranslationLanguage = .en

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

    func launch() {}
}
