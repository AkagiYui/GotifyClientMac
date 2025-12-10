//
//  GotifyServer.swift
//  GotifyClient
//
//  Gotify服务器配置模型
//

import Foundation
import SwiftData

/// Gotify服务器配置
@Model
final class GotifyServer {
    /// 唯一标识符
    var id: UUID
    /// 服务器名称（用于显示）
    var name: String
    /// 服务器地址（URL）
    var url: String
    /// 客户端令牌（client token）
    var clientToken: String
    /// 是否启用连接
    var isEnabled: Bool
    /// 创建时间
    var createdAt: Date
    /// 最后连接时间
    var lastConnectedAt: Date?
    /// 连接状态
    @Transient var connectionStatus: ConnectionStatus = .disconnected
    
    /// 关联的应用列表
    @Relationship(deleteRule: .cascade, inverse: \GotifyApplication.server)
    var applications: [GotifyApplication] = []
    
    /// 关联的消息列表
    @Relationship(deleteRule: .cascade, inverse: \GotifyMessage.server)
    var messages: [GotifyMessage] = []
    
    init(
        name: String,
        url: String,
        clientToken: String,
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.clientToken = clientToken
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }
    
    /// 获取WebSocket URL
    var webSocketURL: URL? {
        guard var urlComponents = URLComponents(string: url) else { return nil }
        urlComponents.scheme = urlComponents.scheme == "https" ? "wss" : "ws"
        urlComponents.path = "/stream"
        urlComponents.queryItems = [URLQueryItem(name: "token", value: clientToken)]
        return urlComponents.url
    }
    
    /// 获取基础API URL
    var baseURL: URL? {
        URL(string: url)
    }
}

/// 连接状态枚举
enum ConnectionStatus: String, Codable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .disconnected: return "已断开"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .error: return "错误"
        }
    }
    
    var iconName: String {
        switch self {
        case .disconnected: return "circle"
        case .connecting: return "circle.dotted"
        case .connected: return "circle.fill"
        case .error: return "exclamationmark.circle"
        }
    }
}

