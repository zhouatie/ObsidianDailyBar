import Foundation

public struct UndoRecord: Sendable {
    public let date: Date
    public let fileURL: URL
    public let previousContent: String
    /// 用于可能涉及跨文件操作（如 deferToTomorrow）的备用状态
    public let secondaryURL: URL?
    public let secondaryPreviousContent: String?
}

public final class MarkdownTodoEngine: @unchecked Sendable {
    public static let shared = MarkdownTodoEngine()

    private var lastUndoRecord: UndoRecord?

    private init() {}

    // MARK: - Regular Expressions
    private let checkboxRegex = try! NSRegularExpression(
        pattern: #"^(\s*)([-*+])\s+\[([ xX])\](\s+)(.*)$"#,
        options: []
    )
    private let headingRegex = try! NSRegularExpression(
        pattern: #"^(#{1,6})\s+(.+?)\s*$"#,
        options: []
    )
    private let tasksHeadingRegex = try! NSRegularExpression(
        pattern: #"(?i)^#{1,6}\s+(tasks|todos)\s*$"#,
        options: []
    )

    // MARK: - Parse Todos
    public func parseTodos(content: String) -> [TodoItem] {
        let lines = content.components(separatedBy: "\n")
        var todos: [TodoItem] = []
        var stack: [Int] = [] // 行号栈
        var lastDepth = 0

        for (idx, line) in lines.enumerated() {
            let lineNo = idx + 1
            let range = NSRange(location: 0, length: (line as NSString).length)
            guard let match = checkboxRegex.firstMatch(in: line, options: [], range: range) else {
                continue
            }

            let indentRange = match.range(at: 1)
            let checkRange = match.range(at: 3)
            let textRange = match.range(at: 5)

            let indentStr = (line as NSString).substring(with: indentRange)
            let checkStr = (line as NSString).substring(with: checkRange)
            let text = (line as NSString).substring(with: textRange)

            let checked = checkStr != " "
            let rawDepth = indentLevel(indentStr)

            let depth: Int
            if stack.isEmpty {
                depth = 0
            } else {
                depth = min(rawDepth, lastDepth + 1)
            }

            while stack.count > depth {
                stack.removeLast()
            }

            let parentLine = stack.last
            stack.append(lineNo)
            lastDepth = depth

            todos.append(TodoItem(
                line: lineNo,
                checked: checked,
                text: text,
                depth: depth,
                parentLine: parentLine
            ))
        }

        return todos
    }

    private func indentLevel(_ indent: String) -> Int {
        let tabs = indent.filter { $0 == "\t" }.count
        let spaces = indent.filter { $0 == " " }.count
        return tabs + (spaces / 2)
    }

    // MARK: - Filter By Heading
    public func filterTodos(content: String, todos: [TodoItem], heading: String?) -> [TodoItem] {
        guard let heading = heading?.trimmingCharacters(in: .whitespacesAndNewlines), !heading.isEmpty else {
            return todos
        }
        let targetHeading = heading.lowercased()
        let lines = content.components(separatedBy: "\n")
        var ranges: [(start: Int, end: Int)] = []

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let range = NSRange(location: 0, length: (line as NSString).length)
            if let match = headingRegex.firstMatch(in: line, options: [], range: range) {
                let levelRange = match.range(at: 1)
                let titleRange = match.range(at: 2)
                let level = (line as NSString).substring(with: levelRange).count
                let title = (line as NSString).substring(with: titleRange).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                if title == targetHeading {
                    let startLine = i + 2 // 1-based 下一行
                    var j = i + 1
                    while j < lines.count {
                        let nextLine = lines[j]
                        let nextRange = NSRange(location: 0, length: (nextLine as NSString).length)
                        if let nextMatch = headingRegex.firstMatch(in: nextLine, options: [], range: nextRange) {
                            let nextLevel = (nextLine as NSString).substring(with: nextMatch.range(at: 1)).count
                            if nextLevel <= level {
                                break
                            }
                        }
                        j += 1
                    }
                    ranges.append((start: startLine, end: j + 1))
                }
            }
            i += 1
        }

        if ranges.isEmpty {
            return []
        }

        return todos.filter { todo in
            ranges.contains { todo.line >= $0.start && todo.line < $0.end }
        }
    }

    // MARK: - Snapshot
    public func readSnapshot(date: Date, heading: String? = nil) -> DailySnapshot {
        let dateStr = MomentFormatter.format(pattern: "YYYY-MM-DD", date: date)
        guard let noteURLs = VaultManager.shared.resolvedNoteURL(for: date) else {
            return DailySnapshot(date: date, dateString: dateStr, error: "未设置 Obsidian 仓库路径")
        }

        let fileURL = noteURLs.resolved
        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        let obsidianURI = VaultManager.shared.obsidianOpenURL(for: fileURL)

        guard exists, let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return DailySnapshot(
                date: date,
                dateString: dateStr,
                filePath: fileURL,
                exists: false,
                todos: [],
                carryOverCount: carrySourceCount(before: date),
                obsidianURI: obsidianURI
            )
        }

        let allTodos = parseTodos(content: content)
        let filteredTodos = filterTodos(content: content, todos: allTodos, heading: heading ?? VaultManager.shared.todoHeading)

        return DailySnapshot(
            date: date,
            dateString: dateStr,
            filePath: fileURL,
            exists: true,
            todos: filteredTodos,
            carryOverCount: carrySourceCount(before: date),
            obsidianURI: obsidianURI
        )
    }

    // MARK: - Mutate Operations

    public func toggleTodo(date: Date, line: Int) throws -> DailySnapshot {
        guard let noteURLs = VaultManager.shared.resolvedNoteURL(for: date) else {
            throw TodoError.vaultNotConfigured
        }
        let url = noteURLs.resolved
        let content = try String(contentsOf: url, encoding: .utf8)
        var lines = content.components(separatedBy: "\n")
        let idx = line - 1
        guard idx >= 0 && idx < lines.count else {
            throw TodoError.lineOutOfRange(line)
        }

        let targetLine = lines[idx]
        let range = NSRange(location: 0, length: (targetLine as NSString).length)
        guard let match = checkboxRegex.firstMatch(in: targetLine, options: [], range: range) else {
            throw TodoError.notATodo(line: line)
        }

        let indent = (targetLine as NSString).substring(with: match.range(at: 1))
        let marker = (targetLine as NSString).substring(with: match.range(at: 2))
        let check = (targetLine as NSString).substring(with: match.range(at: 3))
        let space = (targetLine as NSString).substring(with: match.range(at: 4))
        let text = (targetLine as NSString).substring(with: match.range(at: 5))

        let nextCheck = (check == " ") ? "x" : " "
        lines[idx] = "\(indent)\(marker) [\(nextCheck)]\(space)\(text)"

        let nextContent = lines.joined(separator: "\n")
        try recordUndoAndWrite(date: date, fileURL: url, oldContent: content, newContent: nextContent)
        return readSnapshot(date: date)
    }

    public func editTodo(date: Date, line: Int, newText: String) throws -> DailySnapshot {
        guard let noteURLs = VaultManager.shared.resolvedNoteURL(for: date) else {
            throw TodoError.vaultNotConfigured
        }
        let cleanText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            throw TodoError.emptyText
        }

        let url = noteURLs.resolved
        let content = try String(contentsOf: url, encoding: .utf8)
        var lines = content.components(separatedBy: "\n")
        let idx = line - 1
        guard idx >= 0 && idx < lines.count else {
            throw TodoError.lineOutOfRange(line)
        }

        let targetLine = lines[idx]
        let range = NSRange(location: 0, length: (targetLine as NSString).length)
        guard let match = checkboxRegex.firstMatch(in: targetLine, options: [], range: range) else {
            throw TodoError.notATodo(line: line)
        }

        let indent = (targetLine as NSString).substring(with: match.range(at: 1))
        let marker = (targetLine as NSString).substring(with: match.range(at: 2))
        let check = (targetLine as NSString).substring(with: match.range(at: 3))
        let space = (targetLine as NSString).substring(with: match.range(at: 4))

        lines[idx] = "\(indent)\(marker) [\(check)]\(space)\(cleanText)"
        let nextContent = lines.joined(separator: "\n")
        try recordUndoAndWrite(date: date, fileURL: url, oldContent: content, newContent: nextContent)
        return readSnapshot(date: date)
    }

    public func deleteTodo(date: Date, line: Int, withChildren: Bool) throws -> DailySnapshot {
        guard let noteURLs = VaultManager.shared.resolvedNoteURL(for: date) else {
            throw TodoError.vaultNotConfigured
        }
        let url = noteURLs.resolved
        let content = try String(contentsOf: url, encoding: .utf8)
        let todos = parseTodos(content: content)
        guard let target = todos.first(where: { $0.line == line }) else {
            throw TodoError.notATodo(line: line)
        }

        var linesToDrop: Set<Int> = [line]
        if withChildren {
            let parentDepth = target.depth
            var checkChildren = false
            for t in todos {
                if t.line == line {
                    checkChildren = true
                    continue
                }
                if checkChildren {
                    if t.depth <= parentDepth {
                        break
                    }
                    linesToDrop.insert(t.line)
                }
            }
        }

        let lines = content.components(separatedBy: "\n")
        var kept: [String] = []
        for (i, lineStr) in lines.enumerated() {
            let lineNo = i + 1
            if !linesToDrop.contains(lineNo) {
                kept.append(lineStr)
            }
        }

        let nextContent = kept.joined(separator: "\n")
        try recordUndoAndWrite(date: date, fileURL: url, oldContent: content, newContent: nextContent)
        return readSnapshot(date: date)
    }

    public func addTodo(date: Date, text: String, underLine: Int? = nil, heading: String? = nil) throws -> DailySnapshot {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            throw TodoError.emptyText
        }

        guard let noteURLs = VaultManager.shared.resolvedNoteURL(for: date) else {
            throw TodoError.vaultNotConfigured
        }

        let url = noteURLs.primary
        try ensureNoteExists(date: date, url: url)

        let content = try String(contentsOf: url, encoding: .utf8)
        var lines = content.components(separatedBy: "\n")

        let targetHeading = heading ?? VaultManager.shared.insertHeading ?? VaultManager.shared.todoHeading

        if let parentLine = underLine, parentLine > 0 {
            // 插入子任务
            let todos = parseTodos(content: content)
            guard let parent = todos.first(where: { $0.line == parentLine }) else {
                throw TodoError.parentNotFound(line: parentLine)
            }
            let childDepth = parent.depth + 1
            let indent = String(repeating: "  ", count: childDepth)
            let newLine = "\(indent)- [ ] \(cleanText)"

            // 插入到当前任务（及其所有子任务）的末尾
            var insertIndex = parentLine // 0-based lines.insert at parentLine 刚好在 parentLine 后面
            for t in todos where t.line > parentLine {
                if t.depth > parent.depth {
                    insertIndex = t.line
                } else {
                    break
                }
            }
            if insertIndex > lines.count {
                lines.append(newLine)
            } else {
                lines.insert(newLine, at: insertIndex)
            }
        } else {
            // 顶级任务插入
            let insertPos = findInsertionIndex(lines: lines, heading: targetHeading)
            let newLine = "- [ ] \(cleanText)"
            if insertPos >= lines.count {
                lines.append(newLine)
            } else {
                lines.insert(newLine, at: insertPos)
            }
        }

        let nextContent = lines.joined(separator: "\n")
        try recordUndoAndWrite(date: date, fileURL: url, oldContent: content, newContent: nextContent)
        return readSnapshot(date: date)
    }

    public func deferTodo(date: Date, line: Int, withChildren: Bool) throws -> DailySnapshot {
        guard let noteURLs = VaultManager.shared.resolvedNoteURL(for: date) else {
            throw TodoError.vaultNotConfigured
        }
        let currentURL = noteURLs.resolved
        let content = try String(contentsOf: currentURL, encoding: .utf8)
        let todos = parseTodos(content: content)
        guard let target = todos.first(where: { $0.line == line }) else {
            throw TodoError.notATodo(line: line)
        }

        // 收集要迁移的 todos
        var movingTodos: [TodoItem] = [target]
        if withChildren {
            let parentDepth = target.depth
            var collecting = false
            for t in todos {
                if t.line == line {
                    collecting = true
                    continue
                }
                if collecting {
                    if t.depth <= parentDepth { break }
                    movingTodos.append(t)
                }
            }
        }

        // 计算明天日期
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date),
              let tomorrowURLs = VaultManager.shared.resolvedNoteURL(for: tomorrow) else {
            throw TodoError.unreachableTargetDate
        }

        let tomorrowURL = tomorrowURLs.primary
        try ensureNoteExists(date: tomorrow, url: tomorrowURL)
        let tomorrowContent = try String(contentsOf: tomorrowURL, encoding: .utf8)

        // 1. 在明天追加这些 todos
        var tomorrowLines = tomorrowContent.components(separatedBy: "\n")
        let baseDepth = movingTodos.first?.depth ?? 0
        let heading = VaultManager.shared.insertHeading ?? VaultManager.shared.todoHeading
        var insertPos = findInsertionIndex(lines: tomorrowLines, heading: heading)

        for todo in movingTodos {
            let relativeDepth = max(0, todo.depth - baseDepth)
            let indent = String(repeating: "  ", count: relativeDepth)
            let check = todo.checked ? "x" : " "
            let newLine = "\(indent)- [\(check)] \(todo.text)"
            if insertPos >= tomorrowLines.count {
                tomorrowLines.append(newLine)
                insertPos = tomorrowLines.count
            } else {
                tomorrowLines.insert(newLine, at: insertPos)
                insertPos += 1
            }
        }
        let nextTomorrowContent = tomorrowLines.joined(separator: "\n")

        // 2. 从今天删除这些 todos
        let movingLines = Set(movingTodos.map { $0.line })
        let currentLines = content.components(separatedBy: "\n")
        let nextCurrentContent = currentLines.enumerated()
            .filter { !movingLines.contains($0.offset + 1) }
            .map { $0.element }
            .joined(separator: "\n")

        // 写入并记录撤销
        ensureParentDirectoryExists(for: tomorrowURL)
        ensureParentDirectoryExists(for: currentURL)
        try nextTomorrowContent.write(to: tomorrowURL, atomically: true, encoding: .utf8)
        self.lastUndoRecord = UndoRecord(
            date: date,
            fileURL: currentURL,
            previousContent: content,
            secondaryURL: tomorrowURL,
            secondaryPreviousContent: tomorrowContent
        )
        try nextCurrentContent.write(to: currentURL, atomically: true, encoding: .utf8)

        return readSnapshot(date: date)
    }

    // MARK: - Carry Over
    public func carryOver(toDate: Date = Date(), heading: String? = nil) throws -> DailySnapshot {
        guard let (sourceDate, _) = carrySource(before: toDate) else {
            return readSnapshot(date: toDate)
        }

        guard let sourceURLs = VaultManager.shared.resolvedNoteURL(for: sourceDate),
              let targetURLs = VaultManager.shared.resolvedNoteURL(for: toDate) else {
            throw TodoError.vaultNotConfigured
        }

        let targetURL = targetURLs.primary
        try ensureNoteExists(date: toDate, url: targetURL)

        let sourceContent = try String(contentsOf: sourceURLs.resolved, encoding: .utf8)
        let sourceTodos = parseTodos(content: sourceContent).filter { !$0.checked }

        if sourceTodos.isEmpty {
            return readSnapshot(date: toDate)
        }

        let targetContent = try String(contentsOf: targetURL, encoding: .utf8)
        var targetLines = targetContent.components(separatedBy: "\n")
        let targetHeading = heading ?? VaultManager.shared.insertHeading ?? VaultManager.shared.todoHeading
        var insertPos = findInsertionIndex(lines: targetLines, heading: targetHeading)

        let existingTargetTodos = Set(parseTodos(content: targetContent).filter { !$0.checked }.map { $0.text })
        var toMove: [TodoItem] = []

        for todo in sourceTodos {
            if !existingTargetTodos.contains(todo.text) {
                toMove.append(todo)
                let indent = String(repeating: "  ", count: todo.depth)
                let newLine = "\(indent)- [ ] \(todo.text)"
                if insertPos >= targetLines.count {
                    targetLines.append(newLine)
                    insertPos = targetLines.count
                } else {
                    targetLines.insert(newLine, at: insertPos)
                    insertPos += 1
                }
            }
        }

        // 从源日记中删除这些移动的待办
        let movedTexts = Set(toMove.map { $0.text })
        let sourceLines = sourceContent.components(separatedBy: "\n")
        let dropLines = Set(parseTodos(content: sourceContent).filter { !$0.checked && movedTexts.contains($0.text) }.map { $0.line })
        let nextSourceContent = sourceLines.enumerated()
            .filter { !dropLines.contains($0.offset + 1) }
            .map { $0.element }
            .joined(separator: "\n")

        let nextTargetContent = targetLines.joined(separator: "\n")

        try nextTargetContent.write(to: targetURL, atomically: true, encoding: .utf8)
        self.lastUndoRecord = UndoRecord(
            date: toDate,
            fileURL: targetURL,
            previousContent: targetContent,
            secondaryURL: sourceURLs.resolved,
            secondaryPreviousContent: sourceContent
        )
        try nextSourceContent.write(to: sourceURLs.resolved, atomically: true, encoding: .utf8)

        return readSnapshot(date: toDate)
    }

    public func undo() throws -> DailySnapshot? {
        guard let record = lastUndoRecord else { return nil }
        try record.previousContent.write(to: record.fileURL, atomically: true, encoding: .utf8)
        if let secURL = record.secondaryURL, let secPrev = record.secondaryPreviousContent {
            try secPrev.write(to: secURL, atomically: true, encoding: .utf8)
        }
        self.lastUndoRecord = nil
        return readSnapshot(date: record.date)
    }

    // MARK: - Helper Methods

    private func findInsertionIndex(lines: [String], heading: String?) -> Int {
        if let heading = heading?.trimmingCharacters(in: .whitespacesAndNewlines), !heading.isEmpty {
            let headingLower = heading.lowercased()
            for (idx, line) in lines.enumerated() {
                let range = NSRange(location: 0, length: (line as NSString).length)
                if let match = headingRegex.firstMatch(in: line, options: [], range: range) {
                    let title = (line as NSString).substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if title == headingLower {
                        return idx + 1
                    }
                }
            }
        }

        // 寻找 tasks 或 todos heading
        for (idx, line) in lines.enumerated() {
            let range = NSRange(location: 0, length: (line as NSString).length)
            if tasksHeadingRegex.firstMatch(in: line, options: [], range: range) != nil {
                return idx + 1
            }
        }

        // 寻找已有待办列表的末尾
        var lastTodoIndex = -1
        for (idx, line) in lines.enumerated() {
            let range = NSRange(location: 0, length: (line as NSString).length)
            if checkboxRegex.firstMatch(in: line, options: [], range: range) != nil {
                lastTodoIndex = idx
            }
        }
        if lastTodoIndex >= 0 {
            return lastTodoIndex + 1
        }

        return lines.count
    }

    private func ensureNoteExists(date: Date, url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            return
        }
        let folder = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        let body: String
        if let templateURL = VaultManager.shared.templateURL(),
           let templateContent = try? String(contentsOf: templateURL, encoding: .utf8) {
            let dateStr = MomentFormatter.format(pattern: "YYYY-MM-DD", date: date)
            body = templateContent
                .replacingOccurrences(of: "{{date}}", with: dateStr)
                .replacingOccurrences(of: "{{date:YYYY-MM-DD}}", with: dateStr)
                .replacingOccurrences(of: "{{time}}", with: "")
        } else {
            let dateStr = MomentFormatter.format(pattern: "YYYY-MM-DD", date: date)
            body = "# \(dateStr)\n\n"
        }

        try body.write(to: url, atomically: true, encoding: .utf8)
    }

    private func ensureParentDirectoryExists(for fileURL: URL) {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func recordUndoAndWrite(date: Date, fileURL: URL, oldContent: String, newContent: String) throws {
        ensureParentDirectoryExists(for: fileURL)
        self.lastUndoRecord = UndoRecord(
            date: date,
            fileURL: fileURL,
            previousContent: oldContent,
            secondaryURL: nil,
            secondaryPreviousContent: nil
        )
        try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func carrySource(before date: Date) -> (Date, Int)? {
        let calendar = Calendar.current
        for offset in 1...30 {
            guard let prev = calendar.date(byAdding: .day, value: -offset, to: date) else { break }
            guard let noteURLs = VaultManager.shared.resolvedNoteURL(for: prev) else { continue }
            let path = noteURLs.resolved.path
            if FileManager.default.fileExists(atPath: path),
               let content = try? String(contentsOf: noteURLs.resolved, encoding: .utf8) {
                let openCount = parseTodos(content: content).filter { !$0.checked }.count
                if openCount > 0 {
                    return (prev, openCount)
                }
            }
        }
        return nil
    }

    public func carrySourceCount(before date: Date) -> Int {
        carrySource(before: date)?.1 ?? 0
    }
}
