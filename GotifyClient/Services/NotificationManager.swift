//
//  NotificationManager.swift
//  GotifyClient
//
//  系统通知管理器
//

import Foundation
import UserNotifications
import SwiftData

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 系统通知管理器
@MainActor
final class NotificationManager: NSObject, @unchecked Sendable {
    /// 单例实例
    static let shared = NotificationManager()
    
    /// 通知中心
    private let notificationCenter = UNUserNotificationCenter.current()
    
    /// 是否已获得通知权限
    private(set) var isAuthorized = false
    
    /// 点击通知时的回调
    var onNotificationClicked: ((String) -> Void)?
    
    private override init() {
        super.init()
        // 立即设置 delegate，确保能够处理通知显示
        // 这对于 iOS 尤其重要，因为用户可能已经在系统设置中授予了权限
        notificationCenter.delegate = self
        print("📱 NotificationManager initialized, delegate set")
    }
    
    /// 请求通知权限
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            isAuthorized = try await notificationCenter.requestAuthorization(options: options)
            print("📱 Notification authorization result: \(isAuthorized)")
            return isAuthorized
        } catch {
            print("❌ Failed to request notification authorization: \(error)")
            return false
        }
    }
    
    /// 检查通知权限状态
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }
    
    /// 发送本地通知
    func sendNotification(
        title: String,
        body: String,
        identifier: String,
        sound: Bool = true,
        userInfo: [String: Any] = [:],
        iconImageData: Data? = nil
    ) async {
        // 检查当前权限状态
        let status = await checkAuthorizationStatus()

        if status == .notDetermined {
            // 如果权限未确定，请求权限
            let authorized = await requestAuthorization()
            guard authorized else { return }
        } else if status != .authorized {
            // 如果权限被拒绝或其他状态，不发送通知
            print("Notification permission not granted. Status: \(status.rawValue)")
            return
        }

        // 更新授权状态
        isAuthorized = (status == .authorized)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo

        if sound {
            content.sound = .default
        }

        // 添加图标附件
        if let imageData = iconImageData {
            if let attachment = await createNotificationAttachment(from: imageData, identifier: identifier) {
                content.attachments = [attachment]
            }
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // 立即发送
        )

        do {
            try await notificationCenter.add(request)
            print("📬 Notification sent: \(title)")
        } catch {
            print("❌ Failed to send notification: \(error)")
        }
    }
    
    /// 为Gotify消息发送通知
    func sendNotificationForMessage(
        _ message: GotifyMessage,
        serverName: String,
        soundEnabled: Bool,
        modelContext: ModelContext
    ) async {
        // 获取应用名称
        let appName = await getApplicationName(for: message, modelContext: modelContext)

        // 构建通知标题：如果消息有标题则使用"[应用名] 标题"，否则使用"[应用名] 服务器名"
        let title: String
        if !message.title.isEmpty {
            title = appName.map { "[\($0)] \(message.title)" } ?? message.title
        } else {
            title = appName.map { "[\($0)] \(serverName)" } ?? serverName
        }

        let body = message.message

        // 获取应用图标数据
        let iconData = await getApplicationIconData(for: message, modelContext: modelContext)

        await sendNotification(
            title: title,
            body: body,
            identifier: "gotify-message-\(message.id.uuidString)",
            sound: soundEnabled,
            userInfo: [
                "messageId": message.id.uuidString,
                "serverId": message.server?.id.uuidString ?? ""
            ],
            iconImageData: iconData
        )
    }
    
    /// 更新应用图标badge数量
    func updateBadgeCount(_ count: Int) async {
        do {
            try await notificationCenter.setBadgeCount(count)
        } catch {
            print("Failed to update badge count: \(error)")
        }
    }
    
    /// 清除所有通知
    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Private Methods

    /// 获取应用名称
    private func getApplicationName(for message: GotifyMessage, modelContext: ModelContext) async -> String? {
        guard let server = message.server else { return nil }

        // 查询对应的应用
        let appId = message.appId
        let serverId = server.id
        let descriptor = FetchDescriptor<GotifyApplication>(
            predicate: #Predicate { app in
                app.appId == appId && app.server?.id == serverId
            }
        )

        guard let applications = try? modelContext.fetch(descriptor),
              let application = applications.first else {
            return nil
        }

        return application.name
    }

    /// 获取应用图标数据
    private func getApplicationIconData(for message: GotifyMessage, modelContext: ModelContext) async -> Data? {
        guard let server = message.server else { return nil }

        // 查询对应的应用
        let appId = message.appId
        let serverId = server.id
        let descriptor = FetchDescriptor<GotifyApplication>(
            predicate: #Predicate { app in
                app.appId == appId && app.server?.id == serverId
            }
        )

        guard let applications = try? modelContext.fetch(descriptor),
              let application = applications.first,
              let imageUrl = application.imageUrl else {
            return nil
        }

        // 从缓存管理器获取图标
        if let image = await ImageCacheManager.shared.getImage(imageUrl: imageUrl, from: server) {
            // 将图片转换为 PNG 数据
            #if os(macOS)
            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData) {
                return bitmapImage.representation(using: .png, properties: [:])
            }
            #else
            return image.pngData()
            #endif
        }

        return nil
    }

    /// 创建通知附件
    private func createNotificationAttachment(from imageData: Data, identifier: String) async -> UNNotificationAttachment? {
        // 创建临时文件
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "\(identifier)-icon.png"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            // 写入图片数据到临时文件
            try imageData.write(to: fileURL)

            // 创建附件选项
            // 在macOS上,附件会显示在通知内容中(不是左侧的应用图标位置)
            var options: [String: Any] = [
                UNNotificationAttachmentOptionsTypeHintKey: "public.png"
            ]

            #if os(macOS)
            // 在macOS上,设置缩略图裁剪矩形以更好地显示图标
            // 使用整个图片作为缩略图
            options[UNNotificationAttachmentOptionsThumbnailClippingRectKey] = CGRect(x: 0, y: 0, width: 1, height: 1)
            #endif

            // 创建附件
            let attachment = try UNNotificationAttachment(
                identifier: "app-icon",
                url: fileURL,
                options: options
            )

            return attachment
        } catch {
            print("Failed to create notification attachment: \(error)")
            return nil
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    /// 处理前台通知显示
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        print("📱 willPresent notification: \(notification.request.content.title)")
        return [.banner, .sound, .badge]
    }
    
    /// 处理通知点击
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let messageId = userInfo["messageId"] as? String {
            await MainActor.run {
                onNotificationClicked?(messageId)
            }
        }
    }
}

