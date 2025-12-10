//
//  GotifyApplication.swift
//  GotifyClient
//
//  Gotify应用模型
//

import Foundation
import SwiftData

/// Gotify应用（来自服务器的app）
@Model
final class GotifyApplication {
    /// 唯一标识符
    var id: UUID
    /// 服务器上的应用ID
    var appId: Int
    /// 应用名称
    var name: String
    /// 应用描述
    var appDescription: String
    /// 应用图标URL
    var imageUrl: String?
    /// 是否启用通知
    var notificationEnabled: Bool
    /// 所属服务器
    var server: GotifyServer?
    /// 创建时间
    var createdAt: Date
    /// 更新时间
    var updatedAt: Date
    
    init(
        appId: Int,
        name: String,
        appDescription: String = "",
        imageUrl: String? = nil,
        notificationEnabled: Bool = true,
        server: GotifyServer? = nil
    ) {
        self.id = UUID()
        self.appId = appId
        self.name = name
        self.appDescription = appDescription
        self.imageUrl = imageUrl
        self.notificationEnabled = notificationEnabled
        self.server = server
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// 唯一键（用于合并来自不同服务器的同名应用）
    var uniqueKey: String {
        guard let serverId = server?.id else { return "\(appId)" }
        return "\(serverId.uuidString)-\(appId)"
    }
}

