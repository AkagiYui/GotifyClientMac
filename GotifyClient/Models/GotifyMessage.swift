//
//  GotifyMessage.swift
//  GotifyClient
//
//  Gotify消息模型
//

import Foundation
import SwiftData

/// Gotify消息
@Model
final class GotifyMessage {
    /// 唯一标识符
    var id: UUID
    /// 服务器上的消息ID
    var messageId: Int
    /// 消息标题
    var title: String
    /// 消息内容
    var message: String
    /// 消息优先级
    var priority: Int
    /// 应用ID（服务器上的）
    var appId: Int
    /// 消息创建时间（服务器时间）
    var date: Date
    /// 是否已读
    var isRead: Bool
    /// 额外数据（JSON字符串）
    var extras: String?
    /// 所属服务器
    var server: GotifyServer?
    /// 本地接收时间
    var receivedAt: Date
    
    init(
        messageId: Int,
        title: String,
        message: String,
        priority: Int = 0,
        appId: Int,
        date: Date,
        extras: String? = nil,
        server: GotifyServer? = nil
    ) {
        self.id = UUID()
        self.messageId = messageId
        self.title = title
        self.message = message
        self.priority = priority
        self.appId = appId
        self.date = date
        self.isRead = false
        self.extras = extras
        self.server = server
        self.receivedAt = Date()
    }
    
    /// 获取优先级显示名称
    var priorityDisplayName: String {
        switch priority {
        case 0: return "最低"
        case 1...3: return "低"
        case 4...7: return "普通"
        case 8...10: return "高"
        default: return "未知"
        }
    }
    
    /// 获取优先级图标
    var priorityIconName: String {
        switch priority {
        case 0: return "chevron.down.2"
        case 1...3: return "chevron.down"
        case 4...7: return "minus"
        case 8...10: return "chevron.up.2"
        default: return "questionmark"
        }
    }
}

/// Gotify消息的JSON解码结构
struct GotifyMessageDTO: Codable {
    let id: Int
    let appid: Int
    let title: String
    let message: String
    let priority: Int
    let date: String
    let extras: [String: AnyCodable]?
    
    func toMessage(server: GotifyServer?) -> GotifyMessage {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsedDate = dateFormatter.date(from: date) ?? Date()
        
        var extrasJson: String? = nil
        if let extras = extras {
            if let data = try? JSONEncoder().encode(extras) {
                extrasJson = String(data: data, encoding: .utf8)
            }
        }
        
        return GotifyMessage(
            messageId: id,
            title: title,
            message: message,
            priority: priority,
            appId: appid,
            date: parsedDate,
            extras: extrasJson,
            server: server
        )
    }
}

/// 用于处理任意JSON值的包装类型
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

