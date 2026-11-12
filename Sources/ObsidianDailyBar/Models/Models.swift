import Foundation

public struct TodoItem: Identifiable, Equatable, Hashable, Sendable {
    public var id: String { "\(line)_\(text)" }
    /// 1-based line number in the markdown file
    public var line: Int
    public var checked: Bool
    public var text: String
    /// Nesting depth (0 = root, 1 = indented once, etc.)
    public var depth: Int
    /// 1-based line number of parent item, if any
    public var parentLine: Int?

    public init(line: Int, checked: Bool, text: String, depth: Int, parentLine: Int? = nil) {
        self.line = line
        self.checked = checked
        self.text = text
        self.depth = depth
        self.parentLine = parentLine
    }
}

public struct DaySummary: Identifiable, Equatable, Sendable {
    public var id: String { dateString }
    public var date: Date
    public var dateString: String
    public var openCount: Int
    public var doneCount: Int
    public var exists: Bool
    public var isToday: Bool

    public var totalCount: Int {
        openCount + doneCount
    }

    public init(date: Date, dateString: String, openCount: Int, doneCount: Int, exists: Bool, isToday: Bool) {
        self.date = date
        self.dateString = dateString
        self.openCount = openCount
        self.doneCount = doneCount
        self.exists = exists
        self.isToday = isToday
    }
}

public struct DailySnapshot: Equatable, Sendable {
    public var date: Date
    public var dateString: String
    public var filePath: URL?
    public var exists: Bool
    public var todos: [TodoItem]
    public var openCount: Int
    public var doneCount: Int
    public var carryOverCount: Int
    public var obsidianURI: URL?
    public var error: String?

    public var totalCount: Int {
        openCount + doneCount
    }

    public init(
        date: Date,
        dateString: String,
        filePath: URL? = nil,
        exists: Bool = false,
        todos: [TodoItem] = [],
        carryOverCount: Int = 0,
        obsidianURI: URL? = nil,
        error: String? = nil
    ) {
        self.date = date
        self.dateString = dateString
        self.filePath = filePath
        self.exists = exists
        self.todos = todos
        self.openCount = todos.filter { !$0.checked }.count
        self.doneCount = todos.filter { $0.checked }.count
        self.carryOverCount = carryOverCount
        self.obsidianURI = obsidianURI
        self.error = error
    }
}
