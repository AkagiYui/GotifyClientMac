//
//  GotifyAPIClient.swift
//  GotifyClient
//
//  Gotify REST API 客户端
//

import Foundation

/// Gotify REST API 客户端
@MainActor
final class GotifyAPIClient {
    /// 单例实例
    static let shared = GotifyAPIClient()
    
    private init() {}
    
    /// 获取服务器的应用列表
    /// - Parameter server: Gotify 服务器
    /// - Returns: 应用列表
    func fetchApplications(from server: GotifyServer) async throws -> [GotifyApplicationDTO] {
        guard let baseURL = server.baseURL else {
            throw APIError.invalidURL
        }
        
        let applicationsURL = baseURL.appendingPathComponent("application")

        var request = URLRequest(url: applicationsURL)
        request.httpMethod = "GET"
        request.setValue(server.clientToken, forHTTPHeaderField: "X-Gotify-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let applications = try decoder.decode([GotifyApplicationDTO].self, from: data)
        
        return applications
    }
    
    /// 下载应用图标
    /// - Parameters:
    ///   - imageUrl: 图片相对路径（如 "image/xxx.jpeg"）
    ///   - server: Gotify 服务器
    /// - Returns: 图片数据
    func downloadImage(imageUrl: String, from server: GotifyServer) async throws -> Data {
        guard let baseURL = server.baseURL else {
            throw APIError.invalidURL
        }
        
        let imageFullURL = baseURL.appendingPathComponent(imageUrl)

        var request = URLRequest(url: imageFullURL)
        request.httpMethod = "GET"
        request.setValue(server.clientToken, forHTTPHeaderField: "X-Gotify-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return data
    }
}

/// API 错误类型
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let statusCode):
            return "HTTP 错误: \(statusCode)"
        }
    }
}

