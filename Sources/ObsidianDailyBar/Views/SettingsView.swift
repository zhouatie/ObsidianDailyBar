import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var viewModel: DailyNotesViewModel
    var isStandaloneWindow: Bool = false
    var onDismiss: (() -> Void)? = nil

    @State private var vaultPath: String = ""
    @State private var todoHeading: String = ""
    @State private var insertHeading: String = ""
    @State private var archiveFolder: String = ""
    @State private var launchAtLogin: Bool = false

    public init(
        viewModel: DailyNotesViewModel,
        isStandaloneWindow: Bool = false,
        onDismiss: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.isStandaloneWindow = isStandaloneWindow
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. 顶部固定标题栏
            HStack {
                Text("偏好设置")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                Button("完成") {
                    dismissView()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider()

            // MARK: - 2. 中间可滚动表单区域
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Vault 路径
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Obsidian 仓库目录 (Vault Root)")
                            .font(.system(size: 13, weight: .medium))

                        HStack {
                            TextField("选择或输入 Obsidian 仓库路径", text: $vaultPath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))

                            Button("选择文件夹...") {
                                selectFolder()
                            }
                        }

                        if let vault = VaultManager.shared.vaultURL {
                            Text("当前检测到: \(vault.path)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 2. Obsidian 自动读取的 Daily Note 配置展示
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Daily Notes 插件配置 (读取自 .obsidian/daily-notes.json)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                            GridRow {
                                Text("日记目录:").font(.system(size: 11)).foregroundStyle(.secondary)
                                Text(VaultManager.shared.dailyConfig.folder.isEmpty ? "根目录" : VaultManager.shared.dailyConfig.folder)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            GridRow {
                                Text("日期格式:").font(.system(size: 11)).foregroundStyle(.secondary)
                                Text(VaultManager.shared.dailyConfig.format)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            GridRow {
                                Text("模板文件:").font(.system(size: 11)).foregroundStyle(.secondary)
                                Text(VaultManager.shared.dailyConfig.template ?? "无")
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Divider()

                    // 3. 任务标题过滤与归档规则
                    VStack(alignment: .leading, spacing: 10) {
                        Text("过滤与插入规则 (可选)")
                            .font(.system(size: 13, weight: .medium))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("只显示特定标题下的待办 (todoHeading)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            TextField("例如 Tasks 或 Todos (留空显示全文所有待办)", text: $todoHeading)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("新增待办插入的标题 (insertHeading)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            TextField("例如 Inbox 或 Tasks (留空跟随上述标题)", text: $insertHeading)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("历史日记归档目录格式 (archiveFolder)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            TextField("例如 dailies/_archive/YYYY (留空不启用归档)", text: $archiveFolder)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }
                    }

                    Divider()

                    // 4. 系统启动选项
                    Toggle("开机自动启动 (Launch at Login)", isOn: $launchAtLogin)
                        .font(.system(size: 13))
                        .onChange(of: launchAtLogin) { newValue in
                            LaunchAtLogin.setEnabled(newValue)
                        }
                }
                .padding(18)
            }

            Divider()

            // MARK: - 3. 底部固定操作栏（永不遮挡）
            HStack {
                Button("退出 ObsidianDailyBar", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("应用并刷新") {
                    saveSettings()
                    viewModel.refresh()
                    dismissView()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 420, maxWidth: 460, minHeight: 480, maxHeight: 580)
        .onAppear {
            loadCurrentSettings()
        }
    }

    private func dismissView() {
        saveSettings()
        viewModel.isSettingsPresented = false
        onDismiss?()
    }

    private func loadCurrentSettings() {
        self.vaultPath = VaultManager.shared.vaultURL?.path ?? ""
        self.todoHeading = VaultManager.shared.todoHeading ?? ""
        self.insertHeading = VaultManager.shared.insertHeading ?? ""
        self.archiveFolder = VaultManager.shared.archiveFolder ?? ""
        self.launchAtLogin = LaunchAtLogin.isEnabled
    }

    private func saveSettings() {
        let cleanVault = vaultPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanVault.isEmpty && FileManager.default.fileExists(atPath: cleanVault) {
            VaultManager.shared.vaultURL = URL(fileURLWithPath: cleanVault)
        }

        let cleanTodoH = todoHeading.trimmingCharacters(in: .whitespacesAndNewlines)
        VaultManager.shared.todoHeading = cleanTodoH.isEmpty ? nil : cleanTodoH

        let cleanInsertH = insertHeading.trimmingCharacters(in: .whitespacesAndNewlines)
        VaultManager.shared.insertHeading = cleanInsertH.isEmpty ? nil : cleanInsertH

        let cleanArchive = archiveFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        VaultManager.shared.archiveFolder = cleanArchive.isEmpty ? nil : cleanArchive

        VaultManager.shared.reloadConfig()
        viewModel.refresh()
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择 Vault 根目录"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            self.vaultPath = selectedURL.path
        }
    }
}
