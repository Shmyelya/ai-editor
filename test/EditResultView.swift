import SwiftUI
import UIKit

struct EditResultView: View {
    let sourceText: String
    let resultText: String
    let action: EditorAction
    let isComplete: Bool
    let allowUnchangedNotice: Bool
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
            } else if isComplete, let notice = unchangedNotice {
                resultSection(notice: notice) {
                    plainResult
                }
            } else if isComplete {
                Picker("Режим", selection: $mode) {
                    Text("Результат").tag(Mode.result)
                    Text("Изменения").tag(Mode.changes)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                resultSection(summary: mode == .changes ? ribbon.map(changeSummary) : nil) {
                    if mode == .changes, let ribbon {
                        ribbonText(ribbon)
                    } else {
                        plainResult
                    }
                }
            } else {
                resultSection(summary: nil) {
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

    private var unchangedNotice: String? {
        guard allowUnchangedNotice, action != .translate else { return nil }
        let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source == result else { return nil }
        return action == .proofread ? "Ошибок не найдено" : "Текст не изменился"
    }

    private func resultSection<Content: View>(
        summary: String? = nil,
        notice: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                if let notice {
                    Label(notice, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                copyButton
            }
            card(content: content)
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

    private enum Highlight {
        case removed
        case inserted
    }

    private func attributedRibbon(_ ribbon: WordChangeRibbon) -> AttributedString {
        var text = AttributedString()
        var buffer = ""
        var bufferKind: Highlight?
        let pieces = ribbon.pieces

        func flush() {
            guard let bufferKind, !buffer.isEmpty else {
                buffer = ""
                return
            }
            switch bufferKind {
            case .removed:
                text.append(wordRun(buffer, color: .red, wash: .red, strikethrough: true))
            case .inserted:
                text.append(wordRun(buffer, color: .green, wash: .green, strikethrough: false))
            }
            buffer = ""
        }

        for index in pieces.indices {
            switch pieces[index] {
            case .removed(let word):
                if bufferKind != .removed {
                    flush()
                    bufferKind = .removed
                }
                buffer += word
            case .inserted(let word):
                if bufferKind != .inserted {
                    flush()
                    bufferKind = .inserted
                }
                buffer += word
            case .space:
                if let bufferKind, runContinues(bufferKind, in: pieces, after: index) {
                    buffer += " "
                } else {
                    flush()
                    bufferKind = nil
                    text.append(AttributedString(" "))
                }
            case .lineBreak:
                flush()
                bufferKind = nil
                text.append(AttributedString("\n"))
            case .unchanged(let word):
                flush()
                bufferKind = nil
                text.append(wordRun(word, color: .primary, wash: nil, strikethrough: false))
            }
        }
        flush()
        return text
    }

    private func runContinues(
        _ kind: Highlight,
        in pieces: [WordChangeRibbon.Piece],
        after index: Int
    ) -> Bool {
        var next = index + 1
        while next < pieces.count {
            switch pieces[next] {
            case .space:
                next += 1
            case .removed where kind == .removed:
                return true
            case .inserted where kind == .inserted:
                return true
            default:
                return false
            }
        }
        return false
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
