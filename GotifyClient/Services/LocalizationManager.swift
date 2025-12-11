//
//  LocalizationManager.swift
//  GotifyClient
//
//  语言本地化管理器
//

import Foundation
import SwiftUI

/// 语言本地化管理器
@MainActor
@Observable
final class LocalizationManager {
    /// 单例实例
    static let shared = LocalizationManager()

    /// 当前语言设置
    private(set) var currentLanguage: AppLanguage = .system

    /// 刷新触发器 - 用于触发视图更新
    var refreshTrigger: Int = 0

    /// 当前使用的 Locale
    var currentLocale: Locale {
        Locale(identifier: effectiveLanguageCode)
    }

    /// 支持的语言代码列表（按优先级排序）
    private static let supportedLanguageCodes = ["zh-Hans", "en"]

    /// 当前生效的语言代码
    private(set) var effectiveLanguageCode: String = "en"

    /// Bundle 缓存（预加载所有支持的语言）
    private var bundleCache: [String: Bundle] = [:]

    /// 当前使用的 Bundle
    private var currentBundle: Bundle {
        bundleCache[effectiveLanguageCode] ?? Bundle.main
    }

    /// 语言变更通知名称
    static let languageDidChangeNotification = Notification.Name("languageDidChange")

    private init() {
        // 预加载所有语言 Bundle（避免首次切换时的延迟）
        preloadBundles()

        // 从 UserDefaults 加载语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        }

        // 计算初始的生效语言代码
        effectiveLanguageCode = resolveEffectiveLanguageCode()

        #if DEBUG
        print("[LocalizationManager] init - currentLanguage: \(currentLanguage), effectiveLanguageCode: \(effectiveLanguageCode)")
        print("[LocalizationManager] preferredLanguages: \(Locale.preferredLanguages)")
        print("[LocalizationManager] bundleCache keys: \(Array(bundleCache.keys))")
        #endif
    }

    /// 预加载所有语言 Bundle
    private func preloadBundles() {
        for code in Self.supportedLanguageCodes {
            if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                bundleCache[code] = bundle
            }
        }
    }

    /// 解析生效的语言代码
    private func resolveEffectiveLanguageCode() -> String {
        // 如果用户选择了特定语言，直接使用
        if let code = currentLanguage.effectiveLanguageCode {
            return code
        }

        // 跟随系统时，解析系统首选语言
        return resolveSystemLanguageCode()
    }

    /// 解析系统语言代码，匹配到我们支持的语言
    private func resolveSystemLanguageCode() -> String {
        let preferredLanguages = Locale.preferredLanguages

        for preferredLang in preferredLanguages {
            // 尝试精确前缀匹配（如 zh-Hans-CN 匹配 zh-Hans）
            for supportedCode in Self.supportedLanguageCodes {
                if preferredLang.hasPrefix(supportedCode) {
                    return supportedCode
                }
            }

            // 尝试基础语言匹配（如 zh 匹配 zh-Hans）
            let baseCode = preferredLang.components(separatedBy: "-").first ?? preferredLang
            for supportedCode in Self.supportedLanguageCodes {
                if supportedCode.hasPrefix(baseCode) {
                    return supportedCode
                }
            }
        }

        return "en"
    }

    /// 设置语言
    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }

        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")

        // 更新生效的语言代码
        effectiveLanguageCode = resolveEffectiveLanguageCode()

        #if DEBUG
        print("[LocalizationManager] setLanguage - language: \(language), effectiveLanguageCode: \(effectiveLanguageCode)")
        #endif

        // 递增刷新触发器
        refreshTrigger += 1

        // 发送通知
        NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: language)
    }

    /// 获取本地化字符串
    func localizedString(_ key: String) -> String {
        let bundle = currentBundle
        let value = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        if value != key {
            return value
        }
        // 回退到主 Bundle
        return Bundle.main.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    /// 获取本地化字符串（带参数）
    func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedString(key)
        return String(format: format, arguments: arguments)
    }

    /// 从 AppSettings 同步语言设置
    func syncFromSettings(_ settings: AppSettings) {
        if settings.language != currentLanguage {
            setLanguage(settings.language)
        }
    }

    /// 获取所有支持的语言
    var supportedLanguages: [AppLanguage] {
        AppLanguage.allCases
    }
}

// MARK: - Localized String Helper
/// 便捷函数获取本地化字符串
@MainActor
func L(_ key: String) -> String {
    LocalizationManager.shared.localizedString(key)
}

/// 便捷函数获取本地化字符串（带参数）
@MainActor
func L(_ key: String, _ arguments: CVarArg...) -> String {
    let format = LocalizationManager.shared.localizedString(key)
    return String(format: format, arguments: arguments)
}

