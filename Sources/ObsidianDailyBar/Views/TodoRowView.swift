import SwiftUI

public struct TodoRowView: View {
    let todo: TodoItem
    @ObservedObject var viewModel: DailyNotesViewModel
    @State private var isHovering: Bool = false
    @State private var isAddingChild: Bool = false
    @State private var childText: String = ""

    public init(todo: TodoItem, viewModel: DailyNotesViewModel) {
        self.todo = todo
        self.viewModel = viewModel
    }

    private var isEditing: Bool {
        viewModel.editingTodoLine == todo.line
    }

    private var parsed: ParsedTodoText {
        parseTodoText(todo.text)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                // 缩进指示
                if todo.depth > 0 {
                    Spacer()
                        .frame(width: CGFloat(todo.depth * 16))
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1.5, height: 16)
                }

                // Checkbox
                Button(action: {
                    viewModel.toggleTodo(line: todo.line)
                }) {
                    Image(systemName: todo.checked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(todo.checked ? Color.green : Color.secondary)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)

                // 文本或行内编辑框
                if isEditing {
                    TextField("编辑待办", text: $viewModel.editingText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.top, 1)
                        .onSubmit {
                            viewModel.commitEditing()
                        }
                        .onExitCommand {
                            viewModel.cancelEditing()
                        }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(parsed.mainText)
                            .font(.system(size: 13, weight: .regular))
                            .strikethrough(todo.checked, color: .secondary.opacity(0.8))
                            .foregroundStyle(todo.checked ? Color.secondary : Color.primary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture(count: 2) {
                                viewModel.startEditing(line: todo.line, text: todo.text)
                            }

                        // 元信息标签栏 (截止日期 / 来源 / 创建时间)
                        if parsed.hasMetadata {
                            HStack(spacing: 6) {
                                if let due = parsed.due {
                                    HStack(spacing: 3) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 9))
                                        Text(due)
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundStyle(Color.orange)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }

                                if let source = parsed.source {
                                    HStack(spacing: 3) {
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 9))
                                        Text(source)
                                            .font(.system(size: 10))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(Color.blue)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }

                                if let created = parsed.created {
                                    HStack(spacing: 2) {
                                        Text("➕ \(created)")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color.secondary.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.top, 1)
                        }
                    }
                    // 占满剩余宽度，保证文本换行宽度与 hover 状态无关
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? Color.accentColor.opacity(0.06) : Color.clear)
            )
            // Hover 悬浮快捷操作菜单：叠加在行内容之上，不参与布局，避免文本重排
            .overlay(alignment: .topTrailing) {
                if isHovering && !isEditing {
                    hoverActionBar
                        .padding(.top, 4)
                        .padding(.trailing, 8)
                        .transition(.opacity)
                }
            }
            .help(todo.text) // 鼠标悬停显示完整原生系统 Tooltip 浮窗
            .onHover { hovering in
                self.isHovering = hovering
            }

            // 内联添加子任务输入条
            if isAddingChild {
                HStack(spacing: 6) {
                    Spacer().frame(width: CGFloat((todo.depth + 1) * 16))
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    TextField("新增子任务，按回车保存", text: $childText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onSubmit {
                            if !childText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                viewModel.addTodo(text: childText, underLine: todo.line)
                                childText = ""
                                isAddingChild = false
                            }
                        }
                        .onExitCommand {
                            isAddingChild = false
                            childText = ""
                        }

                    Button("取消") {
                        isAddingChild = false
                        childText = ""
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Hover 快捷操作条 (浮于文案之上)

    private var hoverActionBar: some View {
        HStack(spacing: 2) {
            hoverButton(systemName: "plus.circle", tint: .secondary, help: "添加子任务") {
                isAddingChild.toggle()
            }
            hoverButton(systemName: "pencil", tint: .secondary, help: "编辑") {
                viewModel.startEditing(line: todo.line, text: todo.text)
            }
            hoverButton(systemName: "trash", tint: Color.red.opacity(0.8), help: "删除") {
                viewModel.deleteTodo(line: todo.line)
            }
        }
        .padding(2)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func hoverButton(systemName: String, tint: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Todo Text Parser
private struct ParsedTodoText {
    let mainText: String
    let due: String?
    let created: String?
    let source: String?

    var hasMetadata: Bool {
        due != nil || created != nil || source != nil
    }
}

private func parseTodoText(_ text: String) -> ParsedTodoText {
    var clean = text

    // 1. 提取来源 (来源: ...)
    var source: String?
    if let match = clean.range(of: #"\(来源:\s*(.+)\)\s*$"#, options: .regularExpression) {
        let raw = String(clean[match])
        source = raw.replacingOccurrences(of: "^\\(来源:\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\)\\s*$", with: "", options: .regularExpression)
        clean.removeSubrange(match)
    }

    // 2. 提取截止日期 📅 YYYY-MM-DD
    var due: String?
    if let dueRange = clean.range(of: #"📅\s*(\d{4}-\d{2}-\d{2})"#, options: .regularExpression) {
        let raw = String(clean[dueRange])
        due = raw.replacingOccurrences(of: "📅", with: "").trimmingCharacters(in: .whitespaces)
        clean.removeSubrange(dueRange)
    }

    // 3. 提取创建时间 ➕ MM-DD HH:mm
    var created: String?
    if let createdRange = clean.range(of: #"➕\s*([\d\-:\s]+)"#, options: .regularExpression) {
        let raw = String(clean[createdRange])
        created = raw.replacingOccurrences(of: "➕", with: "").trimmingCharacters(in: .whitespaces)
        clean.removeSubrange(createdRange)
    }

    clean = clean.trimmingCharacters(in: .whitespaces)
    return ParsedTodoText(
        mainText: clean.isEmpty ? text : clean,
        due: due,
        created: created,
        source: source
    )
}
