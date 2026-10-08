import SwiftData
import SwiftUI

struct EditDetailView: View {
    @State private var presentation: EditPresentation
    private let allowUnchangedNotice: Bool

    init(edit: TextEdit, allowUnchangedNotice: Bool) {
        _presentation = State(initialValue: EditPresentation(edit: edit))
        self.allowUnchangedNotice = allowUnchangedNotice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(verbatim: presentation.dateLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                EditResultView(
                    sourceText: presentation.sourceText,
                    resultText: presentation.resultText,
                    action: presentation.action,
                    isComplete: true,
                    allowUnchangedNotice: allowUnchangedNotice,
                    ribbon: presentation.ribbon
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(presentation.actionLine)
    }
}
