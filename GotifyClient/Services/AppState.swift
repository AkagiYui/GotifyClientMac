//
//  AppState.swift
//  GotifyClient
//
//  应用程序状态管理
//

import Foundation
import SwiftData
import Observation

/// 应用程序状态管理器
@MainActor
@Observable
final class AppState {
    /// 单例实例
    static let shared = AppState()
    
    /// 未读消息数量
    var unreadCount: Int = 0
    
    /// 当前选中的服务器ID
    var selectedServerId: UUID?
    
    /// 当前选中的消息ID
    var selectedMessageId: UUID?
    
    /// 是否显示添加服务器表单
    var showAddServerSheet: Bool = false
    
    /// 是否显示设置视图
    var showSettingsSheet: Bool = false
    
    /// 模型上下文（需要外部注入）
    weak var modelContext: ModelContext?
    
    private init() {}
    
    /// 初始化应用状态
    func initialize(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupWebSocketCallbacks()
        loadUnreadCount()
        connectAllServers()
        
        // 请求通知权限
        Task {
            _ = await NotificationManager.shared.requestAuthorization()
        }
    }
    
    /// 设置WebSocket回调
    private func setupWebSocketCallbacks() {
        WebSocketManager.shared.onMessageReceived = { [weak self] messageDTO, server in
            Task { @MainActor in
                await self?.handleNewMessage(messageDTO, from: server)
            }
        }
        
        WebSocketManager.shared.onConnectionStatusChanged = { server, status in
            // 连接状态已经在WebSocketManager中更新到server对象
            if status == .connected {
                server.lastConnectedAt = Date()
            }
        }
    }
    
    /// 处理新消息
    private func handleNewMessage(_ messageDTO: GotifyMessageDTO, from server: GotifyServer) async {
        guard let context = modelContext else { return }
        
        // 创建消息对象
        let message = messageDTO.toMessage(server: server)
        context.insert(message)
        
        // 更新未读计数
        unreadCount += 1
        await NotificationManager.shared.updateBadgeCount(unreadCount)
        
        // 检查是否需要发送通知
        let shouldNotify = await shouldSendNotification(for: message, server: server)
        if shouldNotify {
            let settings = AppSettings.getOrCreate(context: context)
            await NotificationManager.shared.sendNotificationForMessage(
                message,
                serverName: server.name,
                soundEnabled: settings.notificationSound
            )
        }
        
        // 保存上下文
        try? context.save()
    }
    
    /// 检查是否应该发送通知
    private func shouldSendNotification(for message: GotifyMessage, server: GotifyServer) async -> Bool {
        guard let context = modelContext else { return false }

        // 检查全局通知设置
        let settings = AppSettings.getOrCreate(context: context)
        guard settings.showNotifications else { return false }

        // 检查应用级别的通知设置
        let appId = message.appId
        let descriptor = FetchDescriptor<GotifyApplication>(
            predicate: #Predicate { app in
                app.appId == appId
            }
        )

        // 过滤出属于当前服务器的应用
        if let apps = try? context.fetch(descriptor) {
            if let app = apps.first(where: { $0.server?.id == server.id }) {
                return app.notificationEnabled
            }
        }

        // 默认发送通知
        return true
    }
    
    /// 加载未读消息数量
    private func loadUnreadCount() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<GotifyMessage>(
            predicate: #Predicate { !$0.isRead }
        )
        
        unreadCount = (try? context.fetchCount(descriptor)) ?? 0
        Task {
            await NotificationManager.shared.updateBadgeCount(unreadCount)
        }
    }
    
    /// 连接所有已启用的服务器
    func connectAllServers() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<GotifyServer>(
            predicate: #Predicate { $0.isEnabled }
        )
        
        if let servers = try? context.fetch(descriptor) {
            WebSocketManager.shared.connectAllEnabled(servers: servers)
        }
    }
    
    /// 标记消息为已读
    func markAsRead(_ message: GotifyMessage) {
        guard !message.isRead else { return }
        message.isRead = true
        unreadCount = max(0, unreadCount - 1)
        Task {
            await NotificationManager.shared.updateBadgeCount(unreadCount)
        }
    }
    
    /// 标记所有消息为已读
    func markAllAsRead() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<GotifyMessage>(
            predicate: #Predicate { !$0.isRead }
        )
        
        if let messages = try? context.fetch(descriptor) {
            for message in messages {
                message.isRead = true
            }
        }
        
        unreadCount = 0
        Task {
            await NotificationManager.shared.updateBadgeCount(0)
        }
    }
}

