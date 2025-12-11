//
//  ServerEditView.swift
//  GotifyClient
//
//  服务器编辑视图
//

import SwiftUI
import SwiftData

/// 服务器编辑视图
struct ServerEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let server: GotifyServer?
    
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var clientToken: String = ""
    @State private var isEnabled: Bool = true
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isTesting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var successMessage: String = ""
    
    private var isEditing: Bool { server != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(L("serverEdit.basicInfo")) {
                    TextField(L("serverEdit.name"), text: $name)
                        .textContentType(.name)

                    TextField(L("serverEdit.url"), text: $url)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif

                    SecureField(L("serverEdit.clientToken"), text: $clientToken)
                }

                Section {
                    Toggle(L("serverEdit.enableConnection"), isOn: $isEnabled)
                } footer: {
                    Text(L("serverEdit.enableDescription"))
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isTesting ? L("serverEdit.testing") : L("serverEdit.testConnection"))
                        }
                    }
                    .disabled(url.isEmpty || clientToken.isEmpty || isTesting)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? L("serverEdit.title.edit") : L("serverEdit.title.add"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save")) {
                        saveServer()
                    }
                    .disabled(name.isEmpty || url.isEmpty || clientToken.isEmpty)
                }
            }
            .alert(L("common.error"), isPresented: $showError) {
                Button(L("common.ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert(L("common.success"), isPresented: $showSuccess) {
                Button(L("common.ok"), role: .cancel) {}
            } message: {
                Text(successMessage)
            }
            .onAppear {
                if let server = server {
                    name = server.name
                    url = server.url
                    clientToken = server.clientToken
                    isEnabled = server.isEnabled
                }
            }
        }
    }
    
    private func saveServer() {
        // 验证URL格式
        guard let _ = URL(string: url) else {
            errorMessage = L("error.invalidUrl")
            showError = true
            return
        }
        
        if let server = server {
            // 编辑现有服务器
            server.name = name
            server.url = url
            server.clientToken = clientToken
            let wasEnabled = server.isEnabled
            server.isEnabled = isEnabled
            
            // 如果启用状态改变，重新连接
            if wasEnabled != isEnabled {
                if isEnabled {
                    WebSocketManager.shared.connect(to: server)
                } else {
                    WebSocketManager.shared.disconnect(from: server)
                }
            } else if isEnabled {
                // 如果配置改变，重新连接
                WebSocketManager.shared.reconnect(to: server)
            }
        } else {
            // 创建新服务器
            let newServer = GotifyServer(
                name: name,
                url: url,
                clientToken: clientToken,
                isEnabled: isEnabled
            )
            modelContext.insert(newServer)
            
            if isEnabled {
                WebSocketManager.shared.connect(to: newServer)
            }
        }
        
        dismiss()
    }
    
    private func testConnection() {
        isTesting = true

        // 简单的连接测试：尝试获取服务器版本
        guard let baseURL = URL(string: url) else {
            errorMessage = L("error.invalidUrl")
            showError = true
            isTesting = false
            return
        }

        let versionURL = baseURL.appendingPathComponent("version")

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(from: versionURL)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    await MainActor.run {
                        successMessage = L("success.connectionSuccess")
                        showSuccess = true
                        isTesting = false
                    }
                } else {
                    throw URLError(.badServerResponse)
                }
            } catch {
                await MainActor.run {
                    errorMessage = L("error.connectionFailed", error.localizedDescription)
                    showError = true
                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    ServerEditView(server: nil)
        .modelContainer(for: GotifyServer.self, inMemory: true)
}
