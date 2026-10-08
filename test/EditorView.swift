import SwiftData
import SwiftUI
import UIKit

struct EditorView: View {
    @State private var model = EditorModel()

    var body: some View {
        NavigationStack {
            EditorForm(model: model)
                .navigationTitle("Редактор")
        }
    }
}

private struct EditorForm: View {
    @Bindable var model: EditorModel
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isDraftFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                draftSection
                LabeledContent("Действие") {
                    Picker("Действие", selection: $model.action) {
                        ForEach(EditorAction.allCases) { action in
                            Text(action.title)
                                .lineLimit(1)
                                .tag(action)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                if model.action == .translate {
                    LabeledContent("Язык") {
                        Picker("Язык", selection: $model.language) {
                            ForEach(TranslationLanguage.allCases) { language in
                                Text(language.title)
                                    .lineLimit(1)
                                    .tag(language)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                Button {
                    if model.isStreaming {
                        model.stop(in: modelContext)
                    } else {
                        model.launch(in: modelContext)
                    }
                } label: {
                    Text(model.isStreaming ? "Стоп" : "Запустить")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.isStreaming && !model.canLaunch)
                if model.isStreaming, model.resultText.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
                if !model.resultText.isEmpty {
                    EditResultView(
                        sourceText: model.sourceText,
                        resultText: model.resultText,
                        action: model.resultAction,
                        isComplete: !model.isStreaming,
                        ribbon: model.changeRibbon
                    )
                }
                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Повторить") {
                        model.retry(in: modelContext)
                    }
                    .buttonStyle(.bordered)
                }
                if let saveErrorMessage = model.saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") {
                    isDraftFocused = false
                }
            }
        }
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(model.characterCount)/\(EditorModel.characterLimit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    model.paste(text)
                }
                .environment(\.locale, Locale(identifier: "ru_RU"))
                Button("Очистить") {
                    model.clear()
                }
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: draftBinding)
                    .font(.body)
                    .focused($isDraftFocused)
                    .frame(height: fieldHeight)
                    .scrollContentBackground(.hidden)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                if model.draft.isEmpty {
                    Text("Вставьте текст")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { model.draft },
            set: { model.replaceDraft($0) }
        )
    }

    private var fieldHeight: CGFloat {
        let lineHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight
        return lineHeight * 8 + 16
    }
}
