import SwiftData
import SwiftUI

struct EditDetailView: View {
    @State private var presentation: EditPresentation

    init(edit: TextEdit) {
        _presentation = State(initialValue: EditPresentation(edit: edit))
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
                    ribbon: presentation.ribbon
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(presentation.action.title)
    }
}
