//
//  AppearanceManager.swift
//  GotifyClient
//
//  外观管理器
//

import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// 外观管理器
@MainActor
@Observable
final class AppearanceManager {
    /// 单例实例
    static let shared = AppearanceManager()

    /// 当前外观设置
    private(set) var currentAppearance: AppAppearance = .system

    /// 刷新触发器 - 用于触发视图更新
    var refreshTrigger: Int = 0

    /// 外观变更通知名称
    static let appearanceDidChangeNotification = Notification.Name("appearanceDidChange")

    private init() {
        // 从 UserDefaults 加载外观设置
        if let savedAppearance = UserDefaults.standard.string(forKey: "appAppearance"),
           let appearance = AppAppearance(rawValue: savedAppearance) {
            currentAppearance = appearance
        }

        #if DEBUG
        print("[AppearanceManager] init - currentAppearance: \(currentAppearance)")
        #endif
    }

    /// 设置外观
    func setAppearance(_ appearance: AppAppearance) {
        guard appearance != currentAppearance else { return }

        currentAppearance = appearance
        UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance")

        #if DEBUG
        print("[AppearanceManager] setAppearance - appearance: \(appearance)")
        #endif

        // 应用外观设置
        applyAppearance()

        // 递增刷新触发器
        refreshTrigger += 1

        // 发送通知
        NotificationCenter.default.post(name: Self.appearanceDidChangeNotification, object: appearance)
    }

    /// 应用外观设置
    func applyAppearance() {
        #if os(macOS)
        let targetAppearance = currentAppearance.nsAppearance
        NSApp.appearance = targetAppearance

        // 显式更新所有窗口的外观，确保 SwiftUI 内容立即响应
        // 这对于从深色模式切换到跟随系统时特别重要
        for window in NSApp.windows {
            window.appearance = targetAppearance
        }
        #endif
        // iOS 通过 SwiftUI 的 preferredColorScheme 在视图层面处理
    }

    /// 获取当前的 ColorScheme（用于 SwiftUI preferredColorScheme modifier）
    var colorScheme: ColorScheme? {
        #if os(macOS)
        // 在 macOS 上，返回 nil 让 SwiftUI 完全跟随 NSApp.appearance
        // 这样可以避免 preferredColorScheme 和 NSApp.appearance 之间的冲突
        // 确保标题栏和内容区域的外观始终保持一致
        return nil
        #else
        return currentAppearance.colorScheme
        #endif
    }

    /// 从 AppSettings 同步外观设置
    func syncFromSettings(_ settings: AppSettings) {
        if settings.appearance != currentAppearance {
            currentAppearance = settings.appearance
            UserDefaults.standard.set(currentAppearance.rawValue, forKey: "appAppearance")
            applyAppearance()
            refreshTrigger += 1
        }
    }
}

