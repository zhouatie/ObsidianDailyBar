# Obsidian Daily Bar

一个常驻 macOS 菜单栏的 Obsidian 日记待办小组件。用 SwiftUI 原生实现，直接读写 Obsidian 中的 Markdown 日记文件，不依赖 Electron 或 WebView。

灵感来自 [LucaNerlich/obsidian-daily-qs](https://github.com/LucaNerlich/obsidian-daily-qs)。

## 功能特性

1. **常驻菜单栏**
   - 状态栏展示当前进度，例如 `3/5`。
   - 全部完成时图标变为绿色，无待办时自动精简。
   - Accessory 模式运行，不占用 Dock 空间。

2. **双向热同步**
   - 自动读取 Vault 下 `.obsidian/daily-notes.json`，获取日记目录、日期格式和模板文件。
   - 通过文件系统监听（FSEvents + 轻量轮询）同步外部编辑与 iCloud 变更。

3. **周视图导航**
   - 顶部显示本周七天，并用颜色点标记完成状态。
   - 支持点击某天、前一天、后一天、回到今天。

4. **Markdown 待办操作**
   - 点击复选框切换 `- [ ]` 与 `- [x]`。
   - 识别 2 空格或 Tab 缩进，保留父子任务结构。
   - 底部输入框回车即可新增待办；悬浮行可新增子任务。
   - 双击或点击编辑图标可原地编辑。
   - 支持顺延到明天（含子任务），明天日记不存在时按模板自动创建。
   - 支持删除任务树，并提供单级撤销。

5. **历史待办顺延（Carry Over）**
   - 扫描过去 30 天内最近一份含未完成任务的日记。
   - 存在遗留任务时，工具栏出现 `顺延 (N)` 徽标，点击一键迁移到今天。

6. **打开 Obsidian**
   - 通过 `obsidian://open` 深度链接定位当前日记。

7. **偏好设置**
   - 选择或自动探测 Vault 目录。
   - `todoHeading`：仅显示指定标题下的待办。
   - `insertHeading`：新待办插入到指定标题下。
   - `archiveFolder`：历史日记归档目录规则。
   - 排序方式：文件顺序、最新优先、未完成优先、字母排序。
   - 开机自动启动。

## 系统要求

- macOS 13 (Ventura) 及以上。
- 构建需要 Xcode 15 及以上（Swift 5.9 工具链）。
- 无第三方依赖。

## 安装

### 从源码安装到 /Applications

```bash
# 先克隆仓库，再在仓库根目录执行
./install.sh
```

脚本会完成三件事：Release 构建、打包为 `.app`、复制到 `/Applications` 并启动。

### 只构建，不安装

```bash
./build-app.sh
open ObsidianDailyBar.app
```

打包后体积约 2.8 MB，主要为应用图标。

### 终端快捷命令

在 `~/.zshrc` 中加入：

```bash
alias daily="open -a ObsidianDailyBar"
```

之后在终端输入 `daily ` 即可唤起。

## 首次使用

1. 点击菜单栏图标打开浮窗。
2. 点击右上角齿轮打开偏好设置。
3. 选择 Obsidian Vault 根目录。
4. 返回浮窗，开始添加待办。

应用会探测 `~/Documents/Obsidian`、`~/Obsidian`、iCloud 中的 Obsidian 目录，以及环境变量 `OBSIDIAN_VAULT_ROOT`。

## 配置项

| 配置 | 作用 | 默认 |
| --- | --- | --- |
| Vault 根目录 | 读取与写入的目标仓库 | 自动探测 |
| `todoHeading` | 只显示该标题下的待办 | 全文 |
| `insertHeading` | 新待办插入位置 | 跟随 `todoHeading` |
| `archiveFolder` | 归档目录格式，例如 `dailies/_archive/YYYY` | 关闭 |
| 排序方式 | 列表排序规则 | 文件顺序 |
| 开机自动启动 | 登录时通过 `SMAppService` 注册 | 关闭 |

## 项目结构

```
ObsidianDailyBar/
├── Package.swift                 # SPM 工程配置
├── build-app.sh                  # Release 构建与打包
├── install.sh                    # 构建并安装到 /Applications
├── Resources/
│   ├── AppIcon.icns              # 应用图标
│   ├── AppIcon.png               # 图标源文件
│   └── Info.plist                # Accessory 应用属性
├── Sources/ObsidianDailyBar/
│   ├── ObsidianDailyBarApp.swift # 应用入口
│   ├── Core/
│   │   ├── FileWatcher.swift     # 文件系统监听与防抖
│   │   ├── LaunchAtLogin.swift   # 开机自启
│   │   ├── MarkdownTodoEngine.swift # Markdown 解析与增删改查
│   │   ├── MomentFormatter.swift # Moment.js 风格日期格式化
│   │   ├── TodoError.swift       # 统一错误类型
│   │   └── VaultManager.swift    # Vault 探测与 Obsidian 配置读取
│   ├── Models/
│   │   └── Models.swift          # TodoItem / DailySnapshot / DaySummary
│   ├── ViewModel/
│   │   └── DailyNotesViewModel.swift
│   └── Views/
│       ├── PopoverContentView.swift
│       ├── QuickInputView.swift
│       ├── SettingsView.swift
│       ├── SettingsWindowManager.swift
│       ├── StatusItemLabel.swift
│       ├── TodoRowView.swift
│       └── WeekStripView.swift
└── Tests/ObsidianDailyBarTests/  # 单元测试
```

## 开发

```bash
swift build          # 调试构建
swift test           # 运行单元测试
./build-app.sh       # Release 构建并打包
```

单元测试覆盖日期格式化、Markdown 待办解析、标题过滤与快照统计。测试不访问磁盘，不修改 Vault。

## 已知限制

- 撤销只有一级，不支持多步历史。
- 待办文本按纯文本处理，不渲染行内 Markdown 样式。
- 仅支持 Markdown 复选框语法，不解析 Obsidian Tasks 插件的扩展字段。

## 贡献

1. Fork 本仓库并创建分支。
2. 提交前运行 `swift build` 与 `swift test`。
3. 提交 Pull Request，说明动机与改动范围。

## 隐私

应用不发起任何网络请求，不收集遥测数据。所有数据读写均发生在本地 Obsidian Vault 内。

## 许可证

[MIT](LICENSE)

## 免责声明

本项目为个人开源项目，与 Obsidian 官方无关联。Obsidian 为其相应权利人的商标。
