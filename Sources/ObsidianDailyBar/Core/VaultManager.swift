import Foundation

public struct ObsidianDailyConfig: Codable, Equatable, Sendable {
    public var folder: String
    public var format: String
    public var template: String?

    public init(folder: String = "", format: String = "YYYY-MM-DD", template: String? = nil) {
        self.folder = folder
        self.format = format
        self.template = template
    }
}

public enum SortOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case fileOrder = "fileOrder"
    case newestFirst = "newestFirst"
    case openFirst = "openFirst"
    case alphabetical = "alphabetical"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fileOrder: return "默认（文件顺序）"
        case .newestFirst: return "最新优先"
        case .openFirst: return "未完成优先"
        case .alphabetical: return "按字母顺序"
        }
    }
}

public final class VaultManager: @unchecked Sendable {
    public static let shared = VaultManager()

    private let userDefaultsVaultKey = "ObsidianVaultPath"
    private let userDefaultsTodoHeadingKey = "ObsidianTodoHeading"
    private let userDefaultsInsertHeadingKey = "ObsidianInsertHeading"
    private let userDefaultsArchiveFolderKey = "ObsidianArchiveFolder"
    private let userDefaultsSortOrderKey = "ObsidianSortOrder"
    private let userDefaultsOpenOnlyKey = "ObsidianOpenOnly"
    private let userDefaultsLaunchAtLoginKey = "ObsidianLaunchAtLogin"

    public var vaultURL: URL? {
        didSet {
            if let path = vaultURL?.path {
                UserDefaults.standard.set(path, forKey: userDefaultsVaultKey)
            } else {
                UserDefaults.standard.removeObject(forKey: userDefaultsVaultKey)
            }
            reloadConfig()
        }
    }

    public var todoHeading: String? {
        didSet {
            UserDefaults.standard.set(todoHeading, forKey: userDefaultsTodoHeadingKey)
        }
    }

    public var insertHeading: String? {
        didSet {
            UserDefaults.standard.set(insertHeading, forKey: userDefaultsInsertHeadingKey)
        }
    }

    public var archiveFolder: String? {
        didSet {
            UserDefaults.standard.set(archiveFolder, forKey: userDefaultsArchiveFolderKey)
        }
    }

    public var sortOrder: SortOrder {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: userDefaultsSortOrderKey)
        }
    }

    public var openOnly: Bool {
        didSet {
            UserDefaults.standard.set(openOnly, forKey: userDefaultsOpenOnlyKey)
        }
    }

    public private(set) var dailyConfig: ObsidianDailyConfig = ObsidianDailyConfig()

    private init() {
        // 1. 初始化偏好设置
        if let savedSort = UserDefaults.standard.string(forKey: userDefaultsSortOrderKey),
           let order = SortOrder(rawValue: savedSort) {
            self.sortOrder = order
        } else {
            self.sortOrder = .fileOrder
        }

        self.openOnly = UserDefaults.standard.bool(forKey: userDefaultsOpenOnlyKey)
        self.todoHeading = UserDefaults.standard.string(forKey: userDefaultsTodoHeadingKey)
        self.insertHeading = UserDefaults.standard.string(forKey: userDefaultsInsertHeadingKey)
        self.archiveFolder = UserDefaults.standard.string(forKey: userDefaultsArchiveFolderKey)

        // 2. 检测 Vault 路径
        if let savedPath = UserDefaults.standard.string(forKey: userDefaultsVaultKey),
           FileManager.default.fileExists(atPath: savedPath) {
            self.vaultURL = URL(fileURLWithPath: savedPath)
        } else if let envPath = ProcessInfo.processInfo.environment["OBSIDIAN_VAULT_ROOT"],
                  FileManager.default.fileExists(atPath: envPath) {
            self.vaultURL = URL(fileURLWithPath: envPath)
        } else {
            // 探测常见 Vault 位置（目录下需存在 .obsidian 配置目录）
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let candidatePaths = [
                "\(home)/Documents/Obsidian",
                "\(home)/Obsidian",
                "\(home)/Library/Mobile Documents/iCloud~md~obsidian/Documents"
            ]
            for candidate in candidatePaths where Self.isObsidianVault(candidate) {
                self.vaultURL = URL(fileURLWithPath: candidate)
                break
            }
        }

        reloadConfig()
    }

    public func reloadConfig() {
        guard let vault = vaultURL else {
            self.dailyConfig = ObsidianDailyConfig()
            return
        }

        let configURL = vault.appendingPathComponent(".obsidian").appendingPathComponent("daily-notes.json")
        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            self.dailyConfig = ObsidianDailyConfig()
            return
        }

        let folder = (json["folder"] as? String)?.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")) ?? ""
        let format = (json["format"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = (json["template"] as? String)?.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))

        self.dailyConfig = ObsidianDailyConfig(
            folder: folder,
            format: format.flatMap { $0.isEmpty ? nil : $0 } ?? "YYYY-MM-DD",
            template: template.flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    /// 获取指定日期的日记文件完整 URL（若主路径不存在且配置了 archiveFolder 则尝试归档路径）
    public func resolvedNoteURL(for date: Date) -> (primary: URL, resolved: URL)? {
        guard let vault = vaultURL else { return nil }

        let relativeDate = MomentFormatter.format(pattern: dailyConfig.format, date: date)
        var primary = vault

        if !dailyConfig.folder.isEmpty {
            for part in dailyConfig.folder.split(separator: "/") {
                primary.appendPathComponent(String(part))
            }
        }

        for part in relativeDate.split(separator: "/") {
            primary.appendPathComponent(String(part))
        }

        if primary.pathExtension.isEmpty {
            primary.appendPathExtension("md")
        }

        // 如果主文件存在，直接返回
        if FileManager.default.fileExists(atPath: primary.path) {
            return (primary, primary)
        }

        // 如果存在归档配置，检查归档路径
        if let archivePattern = archiveFolder, !archivePattern.isEmpty {
            let archiveRel = MomentFormatter.format(pattern: archivePattern, date: date)
            let noteName = MomentFormatter.format(pattern: dailyConfig.format, date: date)
            var archiveURL = vault
            for part in archiveRel.split(separator: "/") {
                archiveURL.appendPathComponent(String(part))
            }
            if let lastPart = noteName.split(separator: "/").last {
                archiveURL.appendPathComponent(String(lastPart))
            }
            if archiveURL.pathExtension.isEmpty {
                archiveURL.appendPathExtension("md")
            }

            if FileManager.default.fileExists(atPath: archiveURL.path) {
                return (primary, archiveURL)
            }
        }

        return (primary, primary)
    }

    /// 获取模板文件完整 URL
    public func templateURL() -> URL? {
        guard let vault = vaultURL, let templateRel = dailyConfig.template, !templateRel.isEmpty else {
            return nil
        }
        var url = vault
        for part in templateRel.split(separator: "/") {
            url.appendPathComponent(String(part))
        }
        if url.pathExtension.isEmpty {
            url.appendPathExtension("md")
        }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 生成打开 Obsidian 该文件的 URL Scheme。
    /// `file` 参数必须为 Vault 内相对路径，不能是绝对路径。
    public func obsidianOpenURL(for filePath: URL) -> URL? {
        guard let vault = vaultURL else { return nil }

        let vaultPath = vault.standardizedFileURL.path
        let targetPath = filePath.standardizedFileURL.path
        let relativePath: String
        if targetPath.hasPrefix(vaultPath + "/") {
            relativePath = String(targetPath.dropFirst(vaultPath.count + 1))
        } else {
            relativePath = filePath.lastPathComponent
        }

        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "vault", value: vault.lastPathComponent),
            URLQueryItem(name: "file", value: relativePath)
        ]
        return components.url
    }

    /// 判断目录是否为 Obsidian Vault（存在 `.obsidian` 子目录）。
    private static func isObsidianVault(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let configPath = path + "/.obsidian"
        return FileManager.default.fileExists(atPath: configPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
