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

            appearanceSettingsSection

            languageSettingsSection

            aboutSection

            #if DEBUG
            debugSection
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle(L("settings.title"))
    }

    #if os(macOS)
    private var launchSettingsSection: some View {
        Section(L("settings.launch")) {
            Toggle(L("settings.launchAtLogin"), isOn: Binding(
                get: { settings.launchAtLogin },
                set: { newValue in
                    settings.launchAtLogin = newValue
                    settings.updatedAt = Date()
                    updateLoginItem(enabled: newValue)
                }
            ))

            Toggle(L("settings.launchHidden"), isOn: Binding(
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
        Section(L("settings.notifications")) {
            Toggle(L("settings.showNotifications"), isOn: Binding(
                get: { settings.showNotifications },
                set: { newValue in
                    settings.showNotifications = newValue
                    settings.updatedAt = Date()
                }
            ))

            Toggle(L("settings.notificationSound"), isOn: Binding(
                get: { settings.notificationSound },
                set: { newValue in
                    settings.notificationSound = newValue
                    settings.updatedAt = Date()
                }
            ))
            .disabled(!settings.showNotifications)
        }
    }

    private var appearanceSettingsSection: some View {
        Section(L("settings.appearance")) {
            Picker(L("settings.selectAppearance"), selection: Binding(
                get: { settings.appearance },
                set: { newValue in
                    settings.appearance = newValue
                    settings.updatedAt = Date()
                    AppearanceManager.shared.setAppearance(newValue)
                }
            )) {
                ForEach(AppAppearance.allCases, id: \.self) { appearance in
                    Text(appearance.displayName)
                        .tag(appearance)
                }
            }
        }
    }

    private var languageSettingsSection: some View {
        Section(L("settings.language")) {
            Picker(L("settings.selectLanguage"), selection: Binding(
                get: { settings.language },
                set: { newValue in
                    settings.language = newValue
                    settings.updatedAt = Date()
                    LocalizationManager.shared.setLanguage(newValue)
                }
            )) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Text(language.displayName)
                        .tag(language)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section(L("settings.about")) {
            HStack {
                Text(L("settings.version"))
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(L("settings.buildVersion"))
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://github.com/AkagiYui/GotifyClientMac")!) {
                HStack {
                    Text(L("settings.githubRepo"))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Debug Info") {
            // 语言设置
            DebugInfoRow(label: "Language Code", value: LocalizationManager.shared.effectiveLanguageCode)
            DebugInfoRow(label: "Language Setting", value: LocalizationManager.shared.currentLanguage.rawValue)
            DebugInfoRow(label: "System Languages", value: Locale.preferredLanguages.prefix(3).joined(separator: ", "))

            // 应用信息
            DebugInfoRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "N/A")
            DebugInfoRow(label: "Build Config", value: "DEBUG")

            // 系统信息
            DebugInfoRow(label: "macOS Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
            DebugInfoRow(label: "Process ID", value: "\(ProcessInfo.processInfo.processIdentifier)")

            // 数据存储
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.bundleIdentifier ?? "") {
                DebugInfoRow(label: "Container", value: containerURL.path)
            }

            // 内存使用
            DebugInfoRow(label: "Memory Usage", value: formatMemoryUsage())
        }
    }

    private func formatMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            return String(format: "%.1f MB", usedMB)
        }
        return "N/A"
    }
    #endif
}

#if DEBUG
/// 调试信息行组件
private struct DebugInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }
}
#endif

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: AppSettings.self, inMemory: true)
}
