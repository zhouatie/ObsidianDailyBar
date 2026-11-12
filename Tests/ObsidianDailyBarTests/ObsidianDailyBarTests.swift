import XCTest
@testable import ObsidianDailyBar

final class MomentFormatterTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    func testDateTokens() {
        let date = makeDate(year: 2026, month: 3, day: 5)
        XCTAssertEqual(MomentFormatter.format(pattern: "YYYY-MM-DD", date: date, calendar: calendar), "2026-03-05")
        XCTAssertEqual(MomentFormatter.format(pattern: "YYYY/M/D", date: date, calendar: calendar), "2026/3/5")
        XCTAssertEqual(MomentFormatter.format(pattern: "YY", date: date, calendar: calendar), "26")
    }

    func testWeekdayTokens() {
        let date = makeDate(year: 2026, month: 3, day: 5) // Thursday
        XCTAssertEqual(MomentFormatter.format(pattern: "dddd", date: date, calendar: calendar), "Thursday")
        XCTAssertEqual(MomentFormatter.format(pattern: "ddd", date: date, calendar: calendar), "Thu")
    }

    func testLiteralEscape() {
        let date = makeDate(year: 2026, month: 3, day: 5)
        XCTAssertEqual(
            MomentFormatter.format(pattern: "[Daily] YYYY-MM-DD", date: date, calendar: calendar),
            "Daily 2026-03-05"
        )
    }

    func testEmptyPattern() {
        XCTAssertEqual(MomentFormatter.format(pattern: "", date: Date()), "")
    }
}

final class TodoParsingTests: XCTestCase {
    private let engine = MarkdownTodoEngine.shared

    private let sample = """
    # 2026-03-05

    ## Tasks
    - [ ] 根任务 A
      - [x] 子任务 A1
        - [ ] 孙任务 A2
    - [ ] 根任务 B

    ## Notes
    - [ ] 备注任务
    """

    func testParseNesting() {
        let todos = engine.parseTodos(content: sample)

        XCTAssertEqual(todos.count, 5)
        XCTAssertEqual(todos.map(\.line), [4, 5, 6, 7, 10])
        XCTAssertEqual(todos.map(\.depth), [0, 1, 2, 0, 0])
        XCTAssertEqual(todos.map(\.checked), [false, true, false, false, false])
        XCTAssertEqual(todos.map(\.parentLine), [nil, 4, 5, nil, nil])
        XCTAssertEqual(todos.first?.text, "根任务 A")
    }

    func testFilterByHeading() {
        let todos = engine.parseTodos(content: sample)
        let filtered = engine.filterTodos(content: sample, todos: todos, heading: "Tasks")

        XCTAssertEqual(filtered.map(\.line), [4, 5, 6, 7])
    }

    func testFilterByMissingHeadingReturnsEmpty() {
        let todos = engine.parseTodos(content: sample)
        let filtered = engine.filterTodos(content: sample, todos: todos, heading: "Archive")

        XCTAssertTrue(filtered.isEmpty)
    }

    func testNilHeadingKeepsAllTodos() {
        let todos = engine.parseTodos(content: sample)
        XCTAssertEqual(engine.filterTodos(content: sample, todos: todos, heading: nil).count, todos.count)
    }
}

final class DailySnapshotTests: XCTestCase {
    func testCountsDerivedFromTodos() {
        let todos = [
            TodoItem(line: 1, checked: false, text: "a", depth: 0),
            TodoItem(line: 2, checked: true, text: "b", depth: 0),
            TodoItem(line: 3, checked: false, text: "c", depth: 0)
        ]
        let snapshot = DailySnapshot(date: Date(), dateString: "2026-03-05", todos: todos)

        XCTAssertEqual(snapshot.openCount, 2)
        XCTAssertEqual(snapshot.doneCount, 1)
        XCTAssertEqual(snapshot.totalCount, 3)
    }
}
