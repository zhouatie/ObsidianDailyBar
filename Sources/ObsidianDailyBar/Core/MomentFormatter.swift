import Foundation

public enum MomentFormatter {
    private static let tokens: [String] = [
        "YYYY", "MMMM", "dddd", "ddd", "MMM", "YY", "MM", "DD", "M", "D"
    ]

    private static let monthNames = [
        1: "January", 2: "February", 3: "March", 4: "April",
        5: "May", 6: "June", 7: "July", 8: "August",
        9: "September", 10: "October", 11: "November", 12: "December"
    ]

    private static let weekdayNames = [
        1: "Sunday", 2: "Monday", 3: "Tuesday", 4: "Wednesday",
        5: "Thursday", 6: "Friday", 7: "Saturday"
    ]

    public static func format(pattern: String, date: Date, calendar: Calendar = .current) -> String {
        if pattern.isEmpty {
            return ""
        }

        var result = ""
        var index = pattern.startIndex

        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday, 2 = Monday...

        while index < pattern.endIndex {
            // 支持 Moment.js 的 [...] 转义字符（例如 [Daily] 输出为 Daily，不解析其中的 D/M token）
            if pattern[index] == "[" {
                if let closingIndex = pattern[index...].firstIndex(of: "]") {
                    let literalStart = pattern.index(after: index)
                    let literal = pattern[literalStart..<closingIndex]
                    result.append(contentsOf: literal)
                    index = pattern.index(after: closingIndex)
                    continue
                }
            }

            let remaining = pattern[index...]
            var matched = false

            for token in tokens {
                if remaining.hasPrefix(token) {
                    let formattedToken = render(token: token, year: year, month: month, day: day, weekday: weekday)
                    result.append(formattedToken)
                    index = pattern.index(index, offsetBy: token.count)
                    matched = true
                    break
                }
            }

            if !matched {
                result.append(pattern[index])
                index = pattern.index(after: index)
            }
        }

        return result
    }

    private static func render(token: String, year: Int, month: Int, day: Int, weekday: Int) -> String {
        switch token {
        case "YYYY":
            return String(format: "%04d", year)
        case "YY":
            return String(format: "%02d", year % 100)
        case "MMMM":
            return monthNames[month] ?? "\(month)"
        case "MMM":
            let name = monthNames[month] ?? "\(month)"
            return String(name.prefix(3))
        case "MM":
            return String(format: "%02d", month)
        case "M":
            return "\(month)"
        case "DD":
            return String(format: "%02d", day)
        case "D":
            return "\(day)"
        case "dddd":
            return weekdayNames[weekday] ?? ""
        case "ddd":
            let name = weekdayNames[weekday] ?? ""
            return String(name.prefix(3))
        default:
            return token
        }
    }
}
