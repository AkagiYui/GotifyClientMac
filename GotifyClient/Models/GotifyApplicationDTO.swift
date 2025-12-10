//
//  GotifyApplicationDTO.swift
//  GotifyClient
//
//  Gotify 应用数据传输对象
//

import Foundation

/// Gotify 应用的 JSON 解码结构
struct GotifyApplicationDTO: Codable {
    let id: Int
    let token: String
    let name: String
    let description: String
    let `internal`: Bool
    let image: String
    let defaultPriority: Int
    let lastUsed: String?
    
    /// 转换为 GotifyApplication 模型
    /// - Parameter server: 所属服务器
    /// - Returns: GotifyApplication 实例
    func toApplication(server: GotifyServer?) -> GotifyApplication {
        return GotifyApplication(
            appId: id,
            name: name,
            appDescription: description,
            imageUrl: image,
            notificationEnabled: true,
            server: server
        )
    }
}

