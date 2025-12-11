//
//  MessageListView.swift
//  GotifyClient
//
//  消息列表视图
//

import SwiftUI
import SwiftData

/// 消息列表视图
struct MessageListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GotifyMessage.date, order: .reverse) private var messages: [GotifyMessage]
    @State private var selectedMessage: GotifyMessage?
    @State private var searchText: String = ""
    
    private var filteredMessages: [GotifyMessage] {
        if searchText.isEmpty {
            return messages
        }
        return messages.filter { message in
            message.title.localizedCaseInsensitiveContains(searchText) ||
            message.message.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        Group {
            if messages.isEmpty {
                emptyStateView
            } else {
                messageList
            }
        }
        .navigationTitle(L("message.title"))
        .searchable(text: $searchText, prompt: Text(L("message.search")))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        markAllAsRead()
                    } label: {
                        Label(L("message.markAllRead"), systemImage: "checkmark.circle")
                    }

                    Divider()

                    Button(role: .destructive) {
                        deleteAllMessages()
                    } label: {
                        Label(L("message.deleteAll"), systemImage: "trash")
                    }
                } label: {
                    Label(L("message.more"), systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(L("message.empty"), systemImage: "bell.slash")
        } description: {
            Text(L("message.emptyDescription"))
        }
    }
    
    private var messageList: some View {
        List(selection: $selectedMessage) {
            ForEach(filteredMessages) { message in
                MessageRowView(message: message)
                    .tag(message)
            }
            .onDelete(perform: deleteMessages)
        }
    }
    
    private func deleteMessages(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredMessages[index])
            }
        }
    }
    
    private func markAllAsRead() {
        AppState.shared.markAllAsRead()
    }
    
    private func deleteAllMessages() {
        withAnimation {
            for message in messages {
                modelContext.delete(message)
            }
        }
        AppState.shared.unreadCount = 0
        Task {
            await NotificationManager.shared.updateBadgeCount(0)
        }
    }
}

/// 消息行视图
struct MessageRowView: View {
    @Bindable var message: GotifyMessage
    @Query private var applications: [GotifyApplication]

    /// 获取消息对应的应用
    private var application: GotifyApplication? {
        applications.first { app in
            app.appId == message.appId && app.server?.id == message.server?.id
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 应用图标
            if let app = application {
                ApplicationIconView(application: app, size: 40)
            } else {
                // 默认图标
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.secondary)
                    .frame(width: 40, height: 40)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if !message.isRead {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                    }

                    Text(message.title.isEmpty ? L("message.noTitle") : message.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: message.priorityIconName)
                        .foregroundColor(priorityColor)
                        .font(.caption)
                }

                Text(message.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack {
                    if let serverName = message.server?.name {
                        Text(serverName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text(message.date, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !message.isRead {
                AppState.shared.markAsRead(message)
            }
        }
    }

    private var priorityColor: Color {
        switch message.priority {
        case 0: return .gray
        case 1...3: return .blue
        case 4...7: return .orange
        case 8...10: return .red
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        MessageListView()
    }
    .modelContainer(for: GotifyMessage.self, inMemory: true)
}
