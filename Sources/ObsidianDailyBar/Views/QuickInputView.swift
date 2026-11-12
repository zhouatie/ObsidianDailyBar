import SwiftUI

public struct QuickInputView: View {
    @ObservedObject var viewModel: DailyNotesViewModel
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    public init(viewModel: DailyNotesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.secondary)

            TextField("添加待办事项... (按 Enter 保存)", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .onSubmit {
                    submit()
                }

            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.addTodo(text: text)
        inputText = ""
    }
}
