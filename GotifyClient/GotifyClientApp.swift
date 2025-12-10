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
            ContentView()
                .onAppear {
                    setupMacOS()
                }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("检查更新...") {
                    // TODO: 实现更新检查
                }
            }
        }
        #else
        WindowGroup {
            ContentView()
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
    }
    #endif
}
