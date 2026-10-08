import SwiftData
import SwiftUI

struct HistoryView: View {
    @Bindable var model: EditorModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TextEdit.createdAt, order: .reverse) private var edits: [TextEdit]

    var body: some View {
        Group {
            if let saveErrorMessage = model.saveErrorMessage {
                editsList
                    .safeAreaInset(edge: .bottom) {
                        Text(saveErrorMessage)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
            } else {
                editsList
            }
        }
        .navigationTitle("История правок")
    }

    private var editsList: some View {
        Group {
            if edits.isEmpty {
                ContentUnavailableView {
                    Text("Пока нет правок")
                }
            } else {
                List {
                    ForEach(edits) { edit in
                        NavigationLink {
                            EditDetailView(edit: edit)
                        } label: {
                            HistoryRow(edit: edit)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Удалить", role: .destructive) {
                                model.delete(edit, in: modelContext)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let edit: TextEdit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(EditPresentation.actionTitle(storedAction: edit.action))
                .font(.headline)
            Text(verbatim: edit.sourceText)
                .font(.body)
                .lineLimit(1)
            Text(verbatim: EditPresentation.dateLine(
                storedAction: edit.action,
                languageCode: edit.language,
                date: edit.createdAt
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
