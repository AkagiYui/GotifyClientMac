//
//  ServerListView.swift
//  GotifyClient
//
//  服务器列表视图
//

import SwiftUI
import SwiftData

/// 服务器列表视图
struct ServerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GotifyServer.createdAt, order: .reverse) private var servers: [GotifyServer]
    @State private var showAddSheet = false
    @State private var serverToEdit: GotifyServer?
    
    var body: some View {
        Group {
            if servers.isEmpty {
                emptyStateView
            } else {
                serverList
            }
        }
        .navigationTitle("服务器")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("添加服务器", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ServerEditView(server: nil)
        }
        .sheet(item: $serverToEdit) { server in
            ServerEditView(server: server)
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("暂无服务器", systemImage: "server.rack")
        } description: {
            Text("点击右上角的添加按钮来添加你的第一个Gotify服务器")
        } actions: {
            Button("添加服务器") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var serverList: some View {
        List {
            ForEach(servers) { server in
                ServerRowView(server: server) {
                    serverToEdit = server
                }
            }
            .onDelete(perform: deleteServers)
        }
    }
    
    private func deleteServers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let server = servers[index]
                WebSocketManager.shared.disconnect(from: server)
                modelContext.delete(server)
            }
        }
    }
}

/// 服务器行视图
struct ServerRowView: View {
    @Bindable var server: GotifyServer
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(server.name)
                        .font(.headline)
                    
                    Image(systemName: server.connectionStatus.iconName)
                        .foregroundColor(statusColor)
                        .font(.caption)
                }
                
                Text(server.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $server.isEnabled)
                .labelsHidden()
                .onChange(of: server.isEnabled) { _, newValue in
                    if newValue {
                        WebSocketManager.shared.connect(to: server)
                    } else {
                        WebSocketManager.shared.disconnect(from: server)
                    }
                }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("编辑") {
                onEdit()
            }
            
            Button("重新连接") {
                WebSocketManager.shared.reconnect(to: server)
            }
            
            Divider()
            
            Button("删除", role: .destructive) {
                // 删除操作由onDelete处理
            }
        }
    }
    
    private var statusColor: Color {
        switch server.connectionStatus {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

#Preview {
    NavigationStack {
        ServerListView()
    }
    .modelContainer(for: GotifyServer.self, inMemory: true)
}
