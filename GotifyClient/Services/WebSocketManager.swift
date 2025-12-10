//
//  WebSocketManager.swift
//  GotifyClient
//
//  WebSocket连接管理器
//

import Foundation
import SwiftData
import Observation

/// WebSocket连接管理器，管理与多个Gotify服务器的WebSocket连接
@MainActor
@Observable
final class WebSocketManager {
    /// 单例实例
    static let shared = WebSocketManager()
    
    /// 活跃的WebSocket连接
    private var connections: [UUID: WebSocketConnection] = [:]
    
    /// 消息接收回调
    var onMessageReceived: ((GotifyMessageDTO, GotifyServer) -> Void)?
    
    /// 连接状态变化回调
    var onConnectionStatusChanged: ((GotifyServer, ConnectionStatus) -> Void)?
    
    private init() {}
    
    /// 连接到指定服务器
    func connect(to server: GotifyServer) {
        guard server.isEnabled else { return }
        guard let url = server.webSocketURL else {
            server.connectionStatus = .error
            onConnectionStatusChanged?(server, .error)
            return
        }
        
        // 如果已有连接，先断开
        disconnect(from: server)
        
        let connection = WebSocketConnection(
            serverId: server.id,
            url: url,
            onMessage: { [weak self] message in
                Task { @MainActor in
                    self?.onMessageReceived?(message, server)
                }
            },
            onStatusChange: { [weak self] status in
                Task { @MainActor in
                    server.connectionStatus = status
                    self?.onConnectionStatusChanged?(server, status)
                }
            }
        )
        
        connections[server.id] = connection
        connection.connect()
    }
    
    /// 断开指定服务器的连接
    func disconnect(from server: GotifyServer) {
        connections[server.id]?.disconnect()
        connections.removeValue(forKey: server.id)
        server.connectionStatus = .disconnected
    }
    
    /// 断开所有连接
    func disconnectAll() {
        for (_, connection) in connections {
            connection.disconnect()
        }
        connections.removeAll()
    }
    
    /// 重新连接指定服务器
    func reconnect(to server: GotifyServer) {
        disconnect(from: server)
        connect(to: server)
    }
    
    /// 连接所有已启用的服务器
    func connectAllEnabled(servers: [GotifyServer]) {
        for server in servers where server.isEnabled {
            connect(to: server)
        }
    }
    
    /// 获取服务器的连接状态
    func connectionStatus(for server: GotifyServer) -> ConnectionStatus {
        return connections[server.id]?.status ?? .disconnected
    }
}

/// 单个WebSocket连接
final class WebSocketConnection: NSObject, @unchecked Sendable {
    let serverId: UUID
    let url: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let onMessage: (GotifyMessageDTO) -> Void
    private let onStatusChange: (ConnectionStatus) -> Void
    
    private(set) var status: ConnectionStatus = .disconnected
    private var isReconnecting = false
    private var reconnectTask: Task<Void, Never>?
    
    init(
        serverId: UUID,
        url: URL,
        onMessage: @escaping (GotifyMessageDTO) -> Void,
        onStatusChange: @escaping (ConnectionStatus) -> Void
    ) {
        self.serverId = serverId
        self.url = url
        self.onMessage = onMessage
        self.onStatusChange = onStatusChange
        super.init()
    }
    
    func connect() {
        status = .connecting
        onStatusChange(.connecting)
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
    }
    
    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        status = .disconnected
        onStatusChange(.disconnected)
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage() // 继续接收下一条消息
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self.handleDisconnection()
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if let data = text.data(using: .utf8),
               let gotifyMessage = try? JSONDecoder().decode(GotifyMessageDTO.self, from: data) {
                onMessage(gotifyMessage)
            }
        case .data(let data):
            if let gotifyMessage = try? JSONDecoder().decode(GotifyMessageDTO.self, from: data) {
                onMessage(gotifyMessage)
            }
        @unknown default:
            break
        }
    }

    private func handleDisconnection() {
        guard !isReconnecting else { return }
        isReconnecting = true
        status = .error
        onStatusChange(.error)

        // 5秒后尝试重连
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self.isReconnecting = false
            self.connect()
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketConnection: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor in
            self.status = .connected
            self.onStatusChange(.connected)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor in
            self.handleDisconnection()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if error != nil {
            Task { @MainActor in
                self.handleDisconnection()
            }
        }
    }
}

