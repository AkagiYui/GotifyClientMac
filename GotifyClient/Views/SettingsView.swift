//
//  SettingsView.swift
//  GotifyClient
//
//  设置视图
//

import SwiftUI
import SwiftData
#if os(macOS)
import ServiceManagement
#endif

/// 设置视图
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [AppSettings]
    
    private var settings: AppSettings {
        settingsQuery.first ?? AppSettings.getOrCreate(context: modelContext)
    }
    
    var body: some View {
        Form {
            #if os(macOS)
            launchSettingsSection
            #endif

            notificationSettingsSection

            aboutSection
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }
    
    #if os(macOS)
    private var launchSettingsSection: some View {
        Section("启动设置") {
            Toggle("开机自动启动", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { newValue in
                    settings.launchAtLogin = newValue
                    settings.updatedAt = Date()
                    updateLoginItem(enabled: newValue)
                }
            ))
            
            Toggle("开机启动时隐藏主窗口", isOn: Binding(
                get: { settings.launchHidden },
                set: { newValue in
                    settings.launchHidden = newValue
                    settings.updatedAt = Date()
                }
            ))
            .disabled(!settings.launchAtLogin)
        }
    }
    
    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }
    #endif
    
    private var notificationSettingsSection: some View {
        Section("通知设置") {
            Toggle("显示系统通知", isOn: Binding(
                get: { settings.showNotifications },
                set: { newValue in
                    settings.showNotifications = newValue
                    settings.updatedAt = Date()
                }
            ))

            Toggle("通知声音", isOn: Binding(
                get: { settings.notificationSound },
                set: { newValue in
                    settings.notificationSound = newValue
                    settings.updatedAt = Date()
                }
            ))
            .disabled(!settings.showNotifications)
        }
    }

    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("构建版本")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    .foregroundColor(.secondary)
            }
            
            Link(destination: URL(string: "https://github.com/AkagiYui/GotifyClientMac")!) {
                HStack {
                    Text("GitHub 仓库")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: AppSettings.self, inMemory: true)
}
