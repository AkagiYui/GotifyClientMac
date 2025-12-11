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

        WebSocketManager.shared.onConnectionStatusChanged = { [weak self] server, status in
            // 连接状态已经在WebSocketManager中更新到server对象
            if status == .connected {
                server.lastConnectedAt = Date()
                // 连接成功后同步应用列表
                Task { @MainActor in
                    await self?.syncApplications(for: server)
                }
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
                soundEnabled: settings.notificationSound,
                modelContext: context
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

    /// 同步服务器的应用列表
    /// - Parameter server: 要同步的服务器
    func syncApplications(for server: GotifyServer) async {
        guard let context = modelContext else { return }

        do {
            // 从服务器获取应用列表
            let applicationDTOs = try await GotifyAPIClient.shared.fetchApplications(from: server)

            // 获取当前服务器的所有应用
            let serverId = server.id
            let descriptor = FetchDescriptor<GotifyApplication>(
                predicate: #Predicate { app in
                    app.server?.id == serverId
                }
            )
            let existingApps = (try? context.fetch(descriptor)) ?? []

            // 创建一个字典用于快速查找现有应用
            var existingAppsDict: [Int: GotifyApplication] = [:]
            for app in existingApps {
                existingAppsDict[app.appId] = app
            }

            // 更新或创建应用
            for appDTO in applicationDTOs {
                if let existingApp = existingAppsDict[appDTO.id] {
                    // 更新现有应用
                    existingApp.name = appDTO.name
                    existingApp.appDescription = appDTO.description
                    existingApp.imageUrl = appDTO.image
                    existingApp.updatedAt = Date()
                    existingAppsDict.removeValue(forKey: appDTO.id)
                } else {
                    // 创建新应用
                    let newApp = appDTO.toApplication(server: server)
                    context.insert(newApp)
                }
            }

            // 删除服务器上不存在的应用
            for (_, app) in existingAppsDict {
                context.delete(app)
            }

            // 保存上下文
            try? context.save()

            print("Successfully synced \(applicationDTOs.count) applications for server: \(server.name)")
        } catch {
            print("Failed to sync applications for server \(server.name): \(error)")
        }
    }

    /// 同步所有已连接服务器的应用列表
    func syncAllApplications() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<GotifyServer>(
            predicate: #Predicate { $0.isEnabled }
        )

        if let servers = try? context.fetch(descriptor) {
            for server in servers where server.connectionStatus == .connected {
                await syncApplications(for: server)
            }
        }
    }
}

