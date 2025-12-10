//
//  AppSettings.swift
//  GotifyClient
//
//  应用程序设置模型
//

import Foundation
import SwiftData

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
    /// 创建时间
    var createdAt: Date
    /// 更新时间
    var updatedAt: Date
    
    init() {
        self.id = UUID()
        self.launchAtLogin = false
        self.launchHidden = false
        self.showNotifications = true
        self.notificationSound = true
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

