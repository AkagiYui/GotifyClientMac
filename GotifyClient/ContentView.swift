//
//  ContentView.swift
//  GotifyClient
//
//  主内容视图
//

import SwiftUI
import SwiftData

/// 导航标签页
enum NavigationTab: String, CaseIterable {
    case messages
    case servers
    case appNotifications
    case settings

    var icon: String {
        switch self {
        case .messages: return "bell.fill"
        case .servers: return "server.rack"
        case .appNotifications: return "app.badge"
        case .settings: return "gearshape.fill"
        }
    }

    /// 本地化显示名称
    @MainActor
    var localizedName: String {
        switch self {
        case .messages:
            return L("tab.messages")
        case .servers:
            return L("tab.servers")
        case .appNotifications:
            return L("tab.appNotifications")
        case .settings:
            return L("tab.settings")
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: NavigationTab
    @State private var appState = AppState.shared

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            detailView
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            appState.initialize(modelContext: modelContext)
        }
        #else
        TabView(selection: $selectedTab) {
            ForEach(NavigationTab.allCases, id: \.self) { tab in
                NavigationStack {
                    tabContent(for: tab)
                }
                .tabItem {
                    Label(tab.localizedName, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .onAppear {
            appState.initialize(modelContext: modelContext)
        }
        #endif
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .messages:
            MessageListView()
        case .servers:
            ServerListView()
        case .appNotifications:
            AppNotificationSettingsView()
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    private func tabContent(for tab: NavigationTab) -> some View {
        switch tab {
        case .messages:
            MessageListView()
        case .servers:
            ServerListView()
        case .appNotifications:
            AppNotificationSettingsView()
        case .settings:
            SettingsView()
        }
    }
}

#if os(macOS)
/// 侧边栏视图（macOS）
struct SidebarView: View {
    @Binding var selectedTab: NavigationTab
    @Query(filter: #Predicate<GotifyMessage> { !$0.isRead })
    private var unreadMessages: [GotifyMessage]

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标签页区域（消息、服务器和应用通知）
            List(selection: $selectedTab) {
                ForEach([NavigationTab.messages, NavigationTab.servers, NavigationTab.appNotifications], id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            HStack {
                                Text(tab.localizedName)
                                Spacer()
                                if tab == .messages && !unreadMessages.isEmpty {
                                    Text("\(unreadMessages.count)")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                            }
                        } icon: {
                            Image(systemName: tab.icon)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Gotify")

            // 底部设置标签页区域
            List(selection: $selectedTab) {
                NavigationLink(value: NavigationTab.settings) {
                    Label {
                        Text(NavigationTab.settings.localizedName)
                    } icon: {
                        Image(systemName: NavigationTab.settings.icon)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(height: 44)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }
}
#endif

#Preview {
    @Previewable @State var selectedTab: NavigationTab = .messages
    ContentView(selectedTab: $selectedTab)
        .modelContainer(for: [
            GotifyServer.self,
            GotifyMessage.self,
            GotifyApplication.self,
            AppSettings.self
        ], inMemory: true)
}
