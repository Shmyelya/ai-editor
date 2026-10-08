import Foundation
import SwiftData

@Model
final class TextEdit {
    var sourceText: String
    var resultText: String
    var action: String
    var language: String?
    var createdAt: Date

    init(sourceText: String, resultText: String, action: String, language: String?, createdAt: Date) {
        self.sourceText = sourceText
        self.resultText = resultText
        self.action = action
        self.language = language
        self.createdAt = createdAt
    }
}
