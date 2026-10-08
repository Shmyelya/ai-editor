import SwiftUI
import UIKit

struct EditResultView: View {
    let sourceText: String
    let resultText: String
    let action: EditorAction
    let isComplete: Bool
    let ribbon: WordChangeRibbon?

    @State private var mode: Mode = .result

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
                    ribbonText(ribbon)
                } else {
                    plainResult
                }
            } else {
                plainResult
            }
            Button("Скопировать") {
                UIPasteboard.general.string = resultText
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var plainResult: some View {
        Text(verbatim: resultText)
            .font(.body)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var translationBlocks: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Было")
                    .font(.headline)
                Text(verbatim: sourceText)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Стало")
                    .font(.headline)
                Text(verbatim: resultText)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func ribbonText(_ ribbon: WordChangeRibbon) -> some View {
        flowingText(for: ribbon)
            .font(.body)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func flowingText(for ribbon: WordChangeRibbon) -> Text {
        var text = Text(verbatim: "")
        for piece in ribbon.pieces {
            text = text + textPiece(piece)
        }
        return text
    }

    private func textPiece(_ piece: WordChangeRibbon.Piece) -> Text {
        switch piece {
        case .space:
            Text(verbatim: " ")
        case .lineBreak(_):
            Text(verbatim: "\n")
        case .unchanged(let word):
            Text(verbatim: word)
        case .removed(let word):
            Text(verbatim: word)
                .foregroundStyle(.red)
                .strikethrough(true, color: .red)
        case .inserted(let word):
            Text(verbatim: word)
                .foregroundStyle(.green)
        }
    }
}
