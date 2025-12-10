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
    case messages = "消息"
    case servers = "服务器"
    case settings = "设置"

    var icon: String {
        switch self {
        case .messages: return "bell.fill"
        case .servers: return "server.rack"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: NavigationTab = .messages
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
                    Label(tab.rawValue, systemImage: tab.icon)
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
        List(selection: $selectedTab) {
            ForEach(NavigationTab.allCases, id: \.self) { tab in
                NavigationLink(value: tab) {
                    Label {
                        HStack {
                            Text(tab.rawValue)
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
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }
}
#endif

#Preview {
    ContentView()
        .modelContainer(for: [
            GotifyServer.self,
            GotifyMessage.self,
            GotifyApplication.self,
            AppSettings.self
        ], inMemory: true)
}
