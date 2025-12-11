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
        .navigationTitle(L("appNotification.title"))
        .searchable(text: $searchText, prompt: Text(L("appNotification.search")))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                serverFilterMenu
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(L("appNotification.empty"), systemImage: "app.badge")
        } description: {
            Text(L("appNotification.emptyDescription"))
        }
    }

    private var applicationList: some View {
        List {
            Section {
                batchOperationsView
            } header: {
                Text(L("appNotification.batchOperations"))
            }

            Section {
                ForEach(filteredApplications) { app in
                    AppNotificationRowView(application: app)
                }
            } header: {
                Text(L("appNotification.appList", filteredApplications.count))
            }
        }
    }

    private var batchOperationsView: some View {
        HStack {
            Button {
                setAllNotifications(enabled: true)
            } label: {
                Label(L("appNotification.enableAll"), systemImage: "bell.fill")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                setAllNotifications(enabled: false)
            } label: {
                Label(L("appNotification.disableAll"), systemImage: "bell.slash.fill")
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
                    Text(L("appNotification.allServers"))
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
            Label(L("appNotification.filter"), systemImage: "line.3.horizontal.decrease.circle")
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
    @Query(sort: \GotifyServer.name) private var servers: [GotifyServer]

    /// 是否显示服务器标签（当有多个服务器时）
    private var shouldShowServerBadge: Bool {
        servers.count > 1
    }

    var body: some View {
        HStack(spacing: 12) {
            // 应用图标
            ApplicationIconView(application: application, size: 44)

            // 应用信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(application.name)
                        .font(.headline)

                    // 应用 ID 标签
                    Text("#\(application.appId)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                if !application.appDescription.isEmpty {
                    Text(application.appDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // 服务器归属标签（仅在有多个服务器时显示）
                if shouldShowServerBadge, let serverName = application.server?.name {
                    HStack(spacing: 4) {
                        Image(systemName: "server.rack")
                            .font(.caption2)
                        Text(serverName)
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.8))
                    .clipShape(Capsule())
                }
            }

            Spacer()

            // 通知开关
            Toggle("", isOn: $application.notificationEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
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
