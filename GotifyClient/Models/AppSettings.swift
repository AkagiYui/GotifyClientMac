//
//  AppSettings.swift
//  GotifyClient
//
//  应用程序设置模型
//

import Foundation
import SwiftData

/// 应用语言选项
enum AppLanguage: String, CaseIterable, Codable {
    case system = "system"      // 跟随系统
    case english = "en"         // English
    case simplifiedChinese = "zh-Hans"  // 简体中文

    /// 显示名称
    /// 语言名称使用其原生语言显示（如英文始终显示 "English"，中文始终显示 "简体中文"）
    /// "跟随系统" 选项需要动态本地化
    @MainActor
    var displayName: String {
        switch self {
        case .system:
            return LocalizationManager.shared.localizedString("language.system")
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    /// 获取实际使用的语言代码
    var effectiveLanguageCode: String? {
        switch self {
        case .system:
            return nil  // nil 表示使用系统语言
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }
}

/// 应用程序设置
@Model
final class AppSettings {
    /// 唯一标识符（单例模式，只有一条记录）
    var id: UUID
    /// 是否开机自动启动
    var launchAtLogin: Bool
    /// 开机启动时是否隐藏主窗口
    var launchHidden: Bool
    /// 是否显示系统通知
    var showNotifications: Bool
    /// 通知声音
    var notificationSound: Bool
    /// 应用语言（存储原始值）
    var languageRawValue: String = "system"
    /// 创建时间
    var createdAt: Date
    /// 更新时间
    var updatedAt: Date

    /// 应用语言（计算属性）
    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRawValue) ?? .system }
        set { languageRawValue = newValue.rawValue }
    }

    init() {
        self.id = UUID()
        self.launchAtLogin = false
        self.launchHidden = false
        self.showNotifications = true
        self.notificationSound = true
        self.languageRawValue = AppLanguage.system.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// 获取或创建设置实例
    @MainActor
    static func getOrCreate(context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}

