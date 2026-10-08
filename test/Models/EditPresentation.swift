import Foundation
import SwiftData

struct EditPresentation {
    let sourceText: String
    let resultText: String
    let action: EditorAction
    let actionLine: String
    let dateLine: String
    let ribbon: WordChangeRibbon?

    init(edit: TextEdit) {
        sourceText = edit.sourceText
        resultText = edit.resultText
        action = EditorAction(rawValue: edit.action) ?? .paraphrase
        actionLine = Self.actionLine(
            storedAction: edit.action,
            toneCode: edit.tone,
            languageCode: edit.language
        )
        dateLine = Self.dateLine(date: edit.createdAt)
        if action == .translate || resultText.isEmpty {
            ribbon = nil
        } else {
            ribbon = WordChangeRibbon(source: sourceText, result: resultText)
        }
    }

    static func actionTitle(storedAction: String) -> String {
        EditorAction(rawValue: storedAction)?.title ?? ""
    }

    static func actionLine(storedAction: String, toneCode: String?, languageCode: String?) -> String {
        let title = actionTitle(storedAction: storedAction)
        if storedAction == EditorAction.translate.rawValue,
           let languageCode,
           let languageTitle = TranslationLanguage(rawValue: languageCode)?.title {
            return "\(title) → \(languageTitle)"
        }
        guard let toneCode,
              let tone = ParaphraseTone(rawValue: toneCode),
              tone != .neutral else {
            return title
        }
        return "\(title), \(tone.title)"
    }

    static func dateLine(date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let time = date.formatted(timeStyle)
        if calendar.isDateInToday(date) {
            return "Сегодня, \(time)"
        }
        if calendar.isDateInYesterday(date) {
            return "Вчера, \(time)"
        }
        let dayMonth = date.formatted(dayMonthStyle)
        guard calendar.component(.year, from: date) == calendar.component(.year, from: now) else {
            let year = calendar.component(.year, from: date)
            return "\(dayMonth) \(year), \(time)"
        }
        return "\(dayMonth), \(time)"
    }

    private static let locale = Locale(identifier: "ru_RU")
    private static let timeStyle = Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)
    private static let dayMonthStyle = Date.FormatStyle().day().month(.abbreviated).locale(locale)
}
