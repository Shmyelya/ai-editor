import SwiftUI

struct EditorView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {}
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Редактор")
        }
    }
}
