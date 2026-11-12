import SwiftUI
import AppKit

@main
struct ObsidianDailyBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = DailyNotesViewModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(viewModel: viewModel)
        } label: {
            StatusItemLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为后台菜单栏 Accessory 应用（不显示在 Dock）
        NSApp.setActivationPolicy(.accessory)
    }
}
