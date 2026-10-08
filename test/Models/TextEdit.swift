import Foundation
import SwiftData

@Model
final class TextEdit {
    var sourceText: String
    var resultText: String
    var action: String
    var language: String?
    var tone: String?
    var createdAt: Date
    var completedNormally: Bool = true

    init(
        sourceText: String,
        resultText: String,
        action: String,
        language: String?,
        tone: String?,
        createdAt: Date,
        completedNormally: Bool
    ) {
        self.sourceText = sourceText
        self.resultText = resultText
        self.action = action
        self.language = language
        self.tone = tone
        self.createdAt = createdAt
        self.completedNormally = completedNormally
    }
}
