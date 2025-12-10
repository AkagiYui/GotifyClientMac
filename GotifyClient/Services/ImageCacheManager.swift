//
//  ImageCacheManager.swift
//  GotifyClient
//
//  图片缓存管理器
//

import Foundation
import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// 图片缓存管理器
@MainActor
final class ImageCacheManager {
    /// 单例实例
    static let shared = ImageCacheManager()
    
    /// 内存缓存
    private var memoryCache: [String: PlatformImage] = [:]
    
    /// 缓存目录
    private let cacheDirectory: URL
    
    private init() {
        // 获取缓存目录
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("GotifyImages", isDirectory: true)
        
        // 创建缓存目录
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// 获取图片
    /// - Parameters:
    ///   - imageUrl: 图片相对路径（如 "image/xxx.jpeg"）
    ///   - server: Gotify 服务器
    /// - Returns: 图片对象，如果不存在则返回 nil
    func getImage(imageUrl: String, from server: GotifyServer) async -> PlatformImage? {
        let cacheKey = getCacheKey(imageUrl: imageUrl, serverId: server.id)
        
        // 先检查内存缓存
        if let cachedImage = memoryCache[cacheKey] {
            return cachedImage
        }
        
        // 检查磁盘缓存
        let fileURL = getCacheFileURL(for: cacheKey)
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = PlatformImage(data: data) {
            // 加载到内存缓存
            memoryCache[cacheKey] = image
            return image
        }
        
        // 从服务器下载
        do {
            let imageData = try await GotifyAPIClient.shared.downloadImage(imageUrl: imageUrl, from: server)
            
            // 保存到磁盘
            try? imageData.write(to: fileURL)
            
            // 创建图片对象
            if let image = PlatformImage(data: imageData) {
                // 保存到内存缓存
                memoryCache[cacheKey] = image
                return image
            }
        } catch {
            print("Failed to download image: \(error)")
        }
        
        return nil
    }
    
    /// 获取缓存键
    private func getCacheKey(imageUrl: String, serverId: UUID) -> String {
        return "\(serverId.uuidString)-\(imageUrl.replacingOccurrences(of: "/", with: "-"))"
    }
    
    /// 获取缓存文件 URL
    private func getCacheFileURL(for cacheKey: String) -> URL {
        return cacheDirectory.appendingPathComponent(cacheKey)
    }
    
    /// 清除所有缓存
    func clearCache() {
        memoryCache.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// 清除指定服务器的缓存
    func clearCache(for serverId: UUID) {
        let serverPrefix = serverId.uuidString
        
        // 清除内存缓存
        memoryCache = memoryCache.filter { !$0.key.hasPrefix(serverPrefix) }
        
        // 清除磁盘缓存
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                if file.lastPathComponent.hasPrefix(serverPrefix) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }
}

