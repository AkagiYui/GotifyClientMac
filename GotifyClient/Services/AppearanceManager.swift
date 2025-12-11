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
        NSApp.appearance = currentAppearance.nsAppearance
        #endif
        // iOS 通过 SwiftUI 的 preferredColorScheme 在视图层面处理
    }

    /// 获取当前的 ColorScheme（用于 SwiftUI preferredColorScheme modifier）
    var colorScheme: ColorScheme? {
        currentAppearance.colorScheme
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

