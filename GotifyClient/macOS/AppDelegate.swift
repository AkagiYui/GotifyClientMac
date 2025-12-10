//
//  AppDelegate.swift
//  GotifyClient
//
//  macOS应用委托
//

#if os(macOS)
import AppKit
import SwiftUI
import SwiftData

/// macOS应用委托
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 是否应该隐藏Dock图标
    private var shouldHideDockIcon = false

    /// 模型上下文（由外部注入）
    weak var modelContext: ModelContext?

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            // 设置菜单栏
            setupMenuBar()

            // 监听未读消息数量变化
            observeUnreadCount()
        }
    }

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭窗口后不退出应用，继续在后台运行
        return false
    }

    nonisolated func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 点击Dock图标时，如果没有可见窗口，则打开主窗口
        if !flag {
            Task { @MainActor in
                self.openMainWindow()
            }
        }
        return true
    }

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            // 断开所有WebSocket连接
            WebSocketManager.shared.disconnectAll()
        }
    }

    /// 设置菜单栏
    private func setupMenuBar() {
        let menuBarManager = MenuBarManager.shared
        menuBarManager.setupMenuBar()

        menuBarManager.onOpenMainWindow = { [weak self] in
            self?.openMainWindow()
        }

        menuBarManager.onQuitApp = {
            NSApplication.shared.terminate(nil)
        }
    }

    /// 打开主窗口
    func openMainWindow() {
        // 显示Dock图标
        showDockIcon()

        // 激活应用
        NSApplication.shared.activate(ignoringOtherApps: true)

        // 打开或聚焦主窗口
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        } else {
            // 如果没有窗口，需要创建一个新窗口
            // 这通常由SwiftUI的WindowGroup自动处理
        }
    }

    /// 隐藏主窗口并隐藏Dock图标
    func hideMainWindow() {
        // 隐藏所有窗口
        for window in NSApplication.shared.windows {
            window.close()
        }

        // 隐藏Dock图标
        hideDockIcon()
    }

    /// 显示Dock图标
    private func showDockIcon() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    /// 隐藏Dock图标
    private func hideDockIcon() {
        // 延迟隐藏，确保窗口关闭动画完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    /// 监听未读消息数量变化
    private func observeUnreadCount() {
        // 使用定时器定期更新未读计数
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                MenuBarManager.shared.unreadCount = AppState.shared.unreadCount
            }
        }
    }

    /// 检查是否应该隐藏启动
    func checkLaunchHidden() {
        guard let context = modelContext else {
            print("⚠️ ModelContext is nil, cannot check launch hidden setting")
            return
        }

        let settings = AppSettings.getOrCreate(context: context)
        print("📱 Launch settings - launchAtLogin: \(settings.launchAtLogin), launchHidden: \(settings.launchHidden)")

        // 只有在开机自动启动且设置了隐藏时才隐藏窗口
        if settings.launchAtLogin && settings.launchHidden {
            print("🔒 Hiding main window on launch")
            // 延迟隐藏窗口，确保应用已完全启动
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                Task { @MainActor in
                    self?.hideMainWindow()
                }
            }
        } else {
            print("👁️ Showing main window on launch")
            // 确保Dock图标显示
            showDockIcon()
        }
    }
}

// MARK: - Window Close Handler
extension AppDelegate {
    /// 窗口即将关闭时的处理
    func windowWillClose() {
        // 隐藏Dock图标
        hideDockIcon()
    }
}
#endif
