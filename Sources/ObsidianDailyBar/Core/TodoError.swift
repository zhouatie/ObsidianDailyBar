import Foundation

/// 引擎层对外抛出的统一错误类型。
public enum TodoError: LocalizedError, Equatable {
    /// 未设置 Obsidian 仓库路径。
    case vaultNotConfigured
    /// 行号超出文件范围。
    case lineOutOfRange(Int)
    /// 目标行不是 Markdown 待办。
    case notATodo(line: Int)
    /// 待办文本为空。
    case emptyText
    /// 指定的父级待办不存在。
    case parentNotFound(line: Int)
    /// 无法解析明天日记的文件路径。
    case unreachableTargetDate

    public var errorDescription: String? {
        switch self {
        case .vaultNotConfigured:
            return "未设置 Obsidian 仓库路径"
        case .lineOutOfRange(let line):
            return "行号越界：第 \(line) 行"
        case .notATodo(let line):
            return "第 \(line) 行不是待办事项"
        case .emptyText:
            return "待办内容不能为空"
        case .parentNotFound(let line):
            return "父级待办不存在：第 \(line) 行"
        case .unreachableTargetDate:
            return "无法解析目标日期的日记路径"
        }
    }
}
