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
    @FocusState private var isDraftFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                draftSection
                LabeledContent("Действие") {
                    Picker("Действие", selection: $model.action) {
                        ForEach(EditorAction.allCases) { action in
                            Text(action.title).tag(action)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                if model.action == .translate {
                    LabeledContent("Язык") {
                        Picker("Язык", selection: $model.language) {
                            ForEach(TranslationLanguage.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
                Button("Запустить") {
                    model.launch()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canLaunch)
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
