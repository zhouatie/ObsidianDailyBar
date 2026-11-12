import SwiftUI
import AppKit

public struct PopoverContentView: View {
    @ObservedObject var viewModel: DailyNotesViewModel

    public init(viewModel: DailyNotesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. 顶部状态栏
            headerSection
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // MARK: - 2. 周导航 Week Strip
            WeekStripView(viewModel: viewModel)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            // MARK: - 3. 工具条 (搜索/筛选/排序/Carry Over)
            filterToolbar
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            Divider()

            // MARK: - 4. 任务列表
            ZStack {
                if viewModel.filteredTodos.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(viewModel.filteredTodos) { todo in
                                TodoRowView(todo: todo, viewModel: viewModel)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // MARK: - 5. 底部快速输入与状态
            VStack(spacing: 8) {
                QuickInputView(viewModel: viewModel)

                HStack {
                    Text("共 \(viewModel.snapshot.totalCount) 项 · 待办 \(viewModel.snapshot.openCount) · 已完成 \(viewModel.snapshot.doneCount)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let err = viewModel.errorMessage {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 380, height: 520)
        .background(.ultraThinMaterial)
        .onAppear {
            viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refresh()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(viewModel.formattedSelectedDate)
                        .font(.system(size: 14, weight: .bold))

                    if viewModel.isToday {
                        Text("今日")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }

                Text(viewModel.snapshot.exists ? "已关联 Obsidian 日记" : "未创建日记 (点击添加自动创建)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                // 撤销
                Button(action: { viewModel.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("撤销上一操作 (u)")

                // 在 Obsidian 中打开
                Button(action: { viewModel.openInObsidian() }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("在 Obsidian 中打开当前日记")

                // 设置
                Button(action: {
                    SettingsWindowManager.shared.show(viewModel: viewModel)
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("偏好设置")
            }
        }
    }

    private var filterToolbar: some View {
        HStack(spacing: 8) {
            // 搜索框
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("搜索待办...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // 仅看未完成过滤
            Button(action: {
                viewModel.filterOpenOnly.toggle()
            }) {
                Image(systemName: viewModel.filterOpenOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(viewModel.filterOpenOnly ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(viewModel.filterOpenOnly ? "显示全部" : "仅看未完成")

            // 排序菜单
            Menu {
                ForEach(SortOrder.allCases) { order in
                    Button(action: { viewModel.sortOrder = order }) {
                        HStack {
                            Text(order.title)
                            if viewModel.sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13))
                    .foregroundStyle(viewModel.sortOrder != .fileOrder ? Color.accentColor : Color.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("排序方式：\(viewModel.sortOrder.title)")

            // Carry Over (顺延历史未完成任务)
            if viewModel.snapshot.carryOverCount > 0 && viewModel.isToday {
                Button(action: {
                    viewModel.carryOver()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold))
                        Text("顺延 (\(viewModel.snapshot.carryOverCount))")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.18))
                    .foregroundStyle(Color.orange)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("将前几天未完成的 \(viewModel.snapshot.carryOverCount) 条任务移至今天")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.snapshot.exists ? "checkmark.circle" : "doc.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.6))

            VStack(spacing: 4) {
                if !viewModel.searchQuery.isEmpty {
                    Text("无匹配结果")
                        .font(.system(size: 13, weight: .medium))
                    Text("未找到包含 “\(viewModel.searchQuery)” 的待办事项")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else if !viewModel.snapshot.exists {
                    Text("今日尚无日记文件")
                        .font(.system(size: 13, weight: .medium))
                    Text("在下方输入内容按回车，将自动生成今日日记")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("没有待办事项")
                        .font(.system(size: 13, weight: .medium))
                    Text("所有任务都已完成，或者今天没有安排")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(30)
    }
}
