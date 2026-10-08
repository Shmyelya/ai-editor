import Foundation
import SwiftData

struct EditPresentation {
    let sourceText: String
    let resultText: String
    let action: EditorAction
    let dateLine: String
    let ribbon: WordChangeRibbon?

    init(edit: TextEdit) {
        sourceText = edit.sourceText
        resultText = edit.resultText
        action = EditorAction(rawValue: edit.action) ?? .paraphrase
        dateLine = Self.dateLine(
            storedAction: edit.action,
            languageCode: edit.language,
            date: edit.createdAt
        )
        if action == .translate || resultText.isEmpty {
            ribbon = nil
        } else {
            ribbon = WordChangeRibbon(source: sourceText, result: resultText)
        }
    }

    static func actionTitle(storedAction: String) -> String {
        EditorAction(rawValue: storedAction)?.title ?? ""
    }

    static func dateLine(storedAction: String, languageCode: String?, date: Date) -> String {
        let formatted = date.formatted(dateStyle)
        guard storedAction == EditorAction.translate.rawValue,
              let languageCode,
              let title = TranslationLanguage(rawValue: languageCode)?.title else {
            return formatted
        }
        return "\(title), \(formatted)"
    }

    private static let dateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
        .locale(Locale(identifier: "ru_RU"))
}
