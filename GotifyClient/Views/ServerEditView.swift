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
                Section("基本信息") {
                    TextField("服务器名称", text: $name)
                        .textContentType(.name)
                    
                    TextField("服务器地址", text: $url)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                    
                    SecureField("客户端令牌", text: $clientToken)
                }
                
                Section {
                    Toggle("启用连接", isOn: $isEnabled)
                } footer: {
                    Text("启用后将自动连接到此服务器并接收消息")
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
                            Text(isTesting ? "测试中..." : "测试连接")
                        }
                    }
                    .disabled(url.isEmpty || clientToken.isEmpty || isTesting)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "编辑服务器" : "添加服务器")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveServer()
                    }
                    .disabled(name.isEmpty || url.isEmpty || clientToken.isEmpty)
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("成功", isPresented: $showSuccess) {
                Button("确定", role: .cancel) {}
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
            errorMessage = "服务器地址格式不正确"
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
            errorMessage = "服务器地址格式不正确"
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
                        successMessage = "连接成功！"
                        showSuccess = true
                        isTesting = false
                    }
                } else {
                    throw URLError(.badServerResponse)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "连接失败：\(error.localizedDescription)"
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
