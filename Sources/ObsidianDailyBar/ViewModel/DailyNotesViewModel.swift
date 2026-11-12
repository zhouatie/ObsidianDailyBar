import Foundation
import SwiftUI
import AppKit

@MainActor
public final class DailyNotesViewModel: ObservableObject {
    @Published public var selectedDate: Date = Date()
    @Published public var snapshot: DailySnapshot = DailySnapshot(date: Date(), dateString: "")
    @Published public var todaySnapshot: DailySnapshot = DailySnapshot(date: Date(), dateString: "")
    @Published public var weekDays: [DaySummary] = []

    @Published public var searchQuery: String = ""
    @Published public var filterOpenOnly: Bool = false
    @Published public var sortOrder: SortOrder = .fileOrder
    @Published public var selectedTodoLine: Int?
    @Published public var editingTodoLine: Int?
    @Published public var editingText: String = ""

    @Published public var isSettingsPresented: Bool = false
    @Published public var errorMessage: String?

    private let fileWatcher = FileWatcher()

    public init() {
        self.sortOrder = VaultManager.shared.sortOrder
        self.filterOpenOnly = VaultManager.shared.openOnly

        fileWatcher.onChange = { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }

        refresh()
        startWatching()
    }

    public var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    public var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: selectedDate)
    }

    public var filteredTodos: [TodoItem] {
        var items = snapshot.todos

        // 搜索过滤
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = searchQuery.lowercased()
            items = items.filter { $0.text.lowercased().contains(q) }
        }

        // 仅看未完成
        if filterOpenOnly {
            items = items.filter { !$0.checked }
        }

        // 排序规则
        switch sortOrder {
        case .fileOrder:
            return items
        case .newestFirst:
            return reverseSubtrees(items)
        case .openFirst:
            return items.sorted { a, b in
                if a.checked == b.checked {
                    return a.line < b.line
                }
                return !a.checked && b.checked
            }
        case .alphabetical:
            return items.sorted { $0.text.localizedCompare($1.text) == .orderedAscending }
        }
    }

    public func refresh() {
        self.snapshot = MarkdownTodoEngine.shared.readSnapshot(date: selectedDate)
        if Calendar.current.isDateInToday(selectedDate) {
            self.todaySnapshot = self.snapshot
        } else {
            self.todaySnapshot = MarkdownTodoEngine.shared.readSnapshot(date: Date())
        }
        self.weekDays = calculateWeekSummary(for: selectedDate)
    }

    public func startWatching() {
        if let urls = VaultManager.shared.resolvedNoteURL(for: selectedDate) {
            let file = urls.resolved
            let folder = urls.resolved.deletingLastPathComponent()
            fileWatcher.watch(file: file, folder: folder)
        }
    }

    // MARK: - Navigation

    public func selectDate(_ date: Date) {
        self.selectedDate = date
        self.selectedTodoLine = nil
        self.editingTodoLine = nil
        refresh()
        startWatching()
    }

    public func goToToday() {
        selectDate(Date())
    }

    public func previousDay() {
        if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectDate(prev)
        }
    }

    public func nextDay() {
        if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            selectDate(next)
        }
    }

    // MARK: - Todo Operations

    public func toggleTodo(line: Int) {
        perform {
            try MarkdownTodoEngine.shared.toggleTodo(date: selectedDate, line: line)
        }
    }

    public func addTodo(text: String, underLine: Int? = nil) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        perform {
            try MarkdownTodoEngine.shared.addTodo(date: selectedDate, text: text, underLine: underLine)
        }
    }

    public func startEditing(line: Int, text: String) {
        self.editingTodoLine = line
        self.editingText = text
    }

    public func commitEditing() {
        guard let line = editingTodoLine else { return }
        let text = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            perform {
                try MarkdownTodoEngine.shared.editTodo(date: selectedDate, line: line, newText: text)
            }
        }
        self.editingTodoLine = nil
        self.editingText = ""
    }

    public func cancelEditing() {
        self.editingTodoLine = nil
        self.editingText = ""
    }

    public func deleteTodo(line: Int, withChildren: Bool = true) {
        perform {
            try MarkdownTodoEngine.shared.deleteTodo(date: selectedDate, line: line, withChildren: withChildren)
        }
    }

    public func deferTodo(line: Int, withChildren: Bool = true) {
        perform {
            try MarkdownTodoEngine.shared.deferTodo(date: selectedDate, line: line, withChildren: withChildren)
        }
    }

    public func carryOver() {
        perform {
            try MarkdownTodoEngine.shared.carryOver(toDate: selectedDate)
        }
    }

    /// 执行写操作：成功后刷新快照并清空旧错误，失败时记录错误信息。
    private func perform(_ operation: () throws -> DailySnapshot) {
        do {
            self.snapshot = try operation()
            self.errorMessage = nil
            refresh()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// 反转顶层任务块的顺序，保持父子层级与块内顺序不变。
    private func reverseSubtrees(_ items: [TodoItem]) -> [TodoItem] {
        var blocks: [[TodoItem]] = []
        var current: [TodoItem] = []

        for item in items {
            if let first = current.first, item.depth <= first.depth {
                blocks.append(current)
                current = []
            }
            current.append(item)
        }
        if !current.isEmpty {
            blocks.append(current)
        }
        return blocks.reversed().flatMap { $0 }
    }

    public func undo() {
        do {
            if let snap = try MarkdownTodoEngine.shared.undo() {
                self.snapshot = snap
                self.errorMessage = nil
                refresh()
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func openInObsidian() {
        if let uri = snapshot.obsidianURI {
            NSWorkspace.shared.open(uri)
        } else if let vault = VaultManager.shared.vaultURL {
            var components = URLComponents()
            components.scheme = "obsidian"
            components.host = "open"
            components.queryItems = [URLQueryItem(name: "vault", value: vault.lastPathComponent)]
            if let uri = components.url {
                NSWorkspace.shared.open(uri)
            }
        }
    }

    // MARK: - Week Summary

    private func calculateWeekSummary(for referenceDate: Date) -> [DaySummary] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // 周一作为一周的第一天

        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return []
        }

        var days: [DaySummary] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: weekInterval.start) {
                let dateStr = MomentFormatter.format(pattern: "YYYY-MM-DD", date: date)
                let snap = MarkdownTodoEngine.shared.readSnapshot(date: date)
                let isToday = calendar.isDateInToday(date)
                days.append(DaySummary(
                    date: date,
                    dateString: dateStr,
                    openCount: snap.openCount,
                    doneCount: snap.doneCount,
                    exists: snap.exists,
                    isToday: isToday
                ))
            }
        }
        return days
    }
}
