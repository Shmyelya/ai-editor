import SwiftUI
import UIKit

struct EditResultView: View {
    let sourceText: String
    let resultText: String
    let action: EditorAction
    let isComplete: Bool
    let ribbon: WordChangeRibbon?

    @State private var mode: Mode = .result
    @State private var showsCopiedMark = false
    @State private var copyMarkReset: Task<Void, Never>?

    private enum Mode: Hashable {
        case result
        case changes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isComplete, action == .translate {
                translationBlocks
            } else if isComplete {
                Picker("Режим", selection: $mode) {
                    Text("Результат").tag(Mode.result)
                    Text("Изменения").tag(Mode.changes)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if mode == .changes, let ribbon {
                    Text(changeSummary(ribbon))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    resultCard {
                        ribbonText(ribbon)
                    }
                } else {
                    resultCard {
                        plainResult
                    }
                }
            } else {
                resultCard {
                    plainResult
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var plainResult: some View {
        Text(verbatim: resultText)
            .font(.body)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var translationBlocks: some View {
        VStack(alignment: .leading, spacing: 16) {
            labeledCard(title: "Было", text: sourceText, showsCopy: false)
            labeledCard(title: "Стало", text: resultText, showsCopy: true)
        }
    }

    private func labeledCard(title: String, text: String, showsCopy: Bool) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    if showsCopy {
                        copyButton
                    }
                }
                Text(verbatim: text)
                    .font(.body)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func resultCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer(minLength: 0)
                    copyButton
                }
                content()
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var copyButton: some View {
        Button(action: copyResult) {
            Image(systemName: showsCopiedMark ? "checkmark" : "doc.on.doc")
                .font(.body)
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Скопировать")
    }

    private func copyResult() {
        UIPasteboard.general.string = resultText
        showsCopiedMark = true
        copyMarkReset?.cancel()
        copyMarkReset = Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            showsCopiedMark = false
        }
    }

    private func changeSummary(_ ribbon: WordChangeRibbon) -> String {
        var added = 0
        var removed = 0
        for piece in ribbon.pieces {
            switch piece {
            case .inserted:
                added += 1
            case .removed:
                removed += 1
            case .unchanged, .space, .lineBreak:
                break
            }
        }
        return "Добавлено: \(added), удалено: \(removed)"
    }

    private func ribbonText(_ ribbon: WordChangeRibbon) -> some View {
        Text(attributedRibbon(ribbon))
            .font(.body)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attributedRibbon(_ ribbon: WordChangeRibbon) -> AttributedString {
        ribbon.pieces.reduce(into: AttributedString()) { text, piece in
            text.append(attributedPiece(piece))
        }
    }

    private func attributedPiece(_ piece: WordChangeRibbon.Piece) -> AttributedString {
        switch piece {
        case .space:
            AttributedString(" ")
        case .lineBreak:
            AttributedString("\n")
        case .unchanged(let word):
            wordRun(word, color: .primary, wash: nil, strikethrough: false)
        case .removed(let word):
            wordRun(word, color: .red, wash: .red, strikethrough: true)
        case .inserted(let word):
            wordRun(word, color: .green, wash: .green, strikethrough: false)
        }
    }

    private func wordRun(
        _ word: String,
        color: Color,
        wash: Color?,
        strikethrough: Bool
    ) -> AttributedString {
        var text = AttributedString(word)
        text.swiftUI.foregroundColor = color
        if let wash {
            text.swiftUI.backgroundColor = wash.opacity(0.18)
        }
        if strikethrough {
            text.swiftUI.strikethroughStyle = Text.LineStyle(pattern: .solid, color: color)
        }
        return text
    }
}
