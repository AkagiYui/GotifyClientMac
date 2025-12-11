//
//  GotifyClientApp.swift
//  GotifyClient
//
//  Gotify客户端应用程序入口
//

import SwiftUI
import SwiftData

@main
struct GotifyClientApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            GotifyServer.self,
            GotifyMessage.self,
            GotifyApplication.self,
            AppSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        #if os(macOS)
        Window("Gotify Client", id: "main") {
            RootView()
                .onAppear {
                    setupMacOS()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                    if let window = notification.object as? NSWindow,
                       window.identifier?.rawValue == "main" {
                        appDelegate.windowWillClose()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button(L("menu.checkForUpdates")) {
                    // TODO: 实现更新检查
                }
            }
        }
        #else
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
        #endif
    }

    #if os(macOS)
    private func setupMacOS() {
        // 注入模型上下文到AppDelegate
        appDelegate.modelContext = sharedModelContainer.mainContext

        // 检查是否应该隐藏启动
        appDelegate.checkLaunchHidden()

        // 同步语言和外观设置
        let settings = AppSettings.getOrCreate(context: sharedModelContainer.mainContext)
        LocalizationManager.shared.syncFromSettings(settings)
        AppearanceManager.shared.syncFromSettings(settings)
    }
    #endif
}

// MARK: - Root View with Localization
/// 根视图，负责监听语言变化和外观变化并刷新整个应用
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var localizationManager = LocalizationManager.shared
    @State private var appearanceManager = AppearanceManager.shared
    /// 保持导航状态在语言切换时不丢失
    @State private var selectedTab: NavigationTab = .messages

    var body: some View {
        // 通过引用 refreshTrigger 确保视图在语言/外观变化时更新
        // 但不使用 .id() 来避免完全重建视图树
        let _ = localizationManager.refreshTrigger
        let _ = appearanceManager.refreshTrigger
        ContentView(selectedTab: $selectedTab)
            .environment(\.locale, localizationManager.currentLocale)
            .preferredColorScheme(appearanceManager.colorScheme)
            .onAppear {
                #if os(iOS)
                setupiOS()
                #endif
            }
    }

    #if os(iOS)
    private func setupiOS() {
        // 同步语言和外观设置
        let settings = AppSettings.getOrCreate(context: modelContext)
        LocalizationManager.shared.syncFromSettings(settings)
        AppearanceManager.shared.syncFromSettings(settings)
    }
    #endif
}
