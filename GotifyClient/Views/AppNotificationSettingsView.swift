//
//  AppNotificationSettingsView.swift
//  GotifyClient
//
//  应用通知设置视图
//

import SwiftUI
import SwiftData

/// 应用通知设置视图
struct AppNotificationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GotifyServer.name) private var servers: [GotifyServer]
    @Query(sort: \GotifyApplication.name) private var applications: [GotifyApplication]
    
    @State private var selectedServerId: UUID?
    @State private var searchText: String = ""
    
    /// 筛选后的应用列表
    private var filteredApplications: [GotifyApplication] {
        var filtered = applications
        
        // 按服务器筛选
        if let serverId = selectedServerId {
            filtered = filtered.filter { $0.server?.id == serverId }
        }
        
        // 按搜索文本筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.appDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        Group {
            if applications.isEmpty {
                emptyStateView
            } else {
                applicationList
            }
        }
        .navigationTitle("应用通知设置")
        .searchable(text: $searchText, prompt: "搜索应用")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                serverFilterMenu
            }
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("暂无应用", systemImage: "app.badge")
        } description: {
            Text("当从服务器接收到消息时，相关的应用信息将自动添加到这里")
        }
    }
    
    private var applicationList: some View {
        List {
            Section {
                batchOperationsView
            } header: {
                Text("批量操作")
            }
            
            Section {
                ForEach(filteredApplications) { app in
                    AppNotificationRowView(application: app)
                }
            } header: {
                Text("应用列表 (\(filteredApplications.count))")
            }
        }
    }
    
    private var batchOperationsView: some View {
        HStack {
            Button {
                setAllNotifications(enabled: true)
            } label: {
                Label("全部启用", systemImage: "bell.fill")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button {
                setAllNotifications(enabled: false)
            } label: {
                Label("全部禁用", systemImage: "bell.slash.fill")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
    
    private var serverFilterMenu: some View {
        Menu {
            Button {
                selectedServerId = nil
            } label: {
                HStack {
                    Text("所有服务器")
                    if selectedServerId == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            ForEach(servers) { server in
                Button {
                    selectedServerId = server.id
                } label: {
                    HStack {
                        Text(server.name)
                        if selectedServerId == server.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
    
    private func setAllNotifications(enabled: Bool) {
        for app in filteredApplications {
            app.notificationEnabled = enabled
            app.updatedAt = Date()
        }
    }
}

/// 应用通知行视图
struct AppNotificationRowView: View {
    @Bindable var application: GotifyApplication
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(application.name)
                    .font(.headline)
                
                if !application.appDescription.isEmpty {
                    Text(application.appDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let serverName = application.server?.name {
                    Text(serverName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $application.notificationEnabled)
                .labelsHidden()
                .onChange(of: application.notificationEnabled) { _, _ in
                    application.updatedAt = Date()
                }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        AppNotificationSettingsView()
    }
    .modelContainer(for: [GotifyApplication.self, GotifyServer.self], inMemory: true)
}
