# Gotify Client

一个使用 Swift 和 SwiftUI 开发的 Gotify 客户端应用程序，支持 macOS 和 iOS 平台。

[![Build](https://github.com/AkagiYui/GotifyClientMac/actions/workflows/build.yml/badge.svg)](https://github.com/AkagiYui/GotifyClientMac/actions/workflows/build.yml)

## 项目简介

Gotify Client 是一个原生的 Gotify 推送通知客户端，可以让你在 macOS 和 iOS 设备上接收来自 Gotify 服务器的实时消息推送。应用程序通过 WebSocket 协议与 Gotify 服务器保持长连接，确保消息的即时送达。

### 支持的平台

- **macOS**: 15.0 及以上版本
- **iOS**: 18.0 及以上版本

## 功能介绍

### 核心功能

- ✅ **多服务器支持**: 同时连接多个 Gotify 服务器，统一管理消息
- ✅ **实时消息推送**: 通过 WebSocket 实时接收服务器推送的消息
- ✅ **系统通知集成**: 收到新消息时显示系统通知
- ✅ **应用级通知控制**: 可以为每个应用单独设置是否显示通知
- ✅ **消息管理**: 查看、搜索、标记已读、删除消息
- ✅ **深色模式支持**: 自动跟随系统主题切换

### macOS 专属功能

- ✅ **菜单栏图标**: 在菜单栏显示图标，显示未读消息数量
- ✅ **后台运行**: 关闭窗口后应用继续在后台运行，接收消息
- ✅ **隐藏 Dock 图标**: 关闭窗口后自动隐藏 Dock 图标
- ✅ **开机自启动**: 支持设置开机自动启动
- ✅ **后台启动**: 支持开机启动时隐藏主窗口

## 安装说明

### 从 GitHub Actions 下载

1. 访问项目的 [Actions 页面](https://github.com/AkagiYui/GotifyClientMac/actions)
2. 选择最新的成功构建
3. 在 Artifacts 部分下载对应平台的应用包：
   - `GotifyClient-macOS`: macOS 应用包
   - `GotifyClient-iOS-Simulator`: iOS 模拟器应用包

### 安装 macOS 版本

1. 下载并解压 `GotifyClient-macOS.zip`
2. 将 `GotifyClient.app` 拖入 `/Applications` 目录
3. 首次运行时，右键点击应用选择「打开」以绕过 Gatekeeper

### 安装 iOS 版本

由于 iOS 版本需要代码签名，建议通过 Xcode 直接部署到设备。

## 使用说明

### 添加 Gotify 服务器

1. 打开应用，点击「服务器」标签
2. 点击右上角的「+」按钮
3. 填写服务器信息：
   - **服务器名称**: 用于显示的名称（如「我的服务器」）
   - **服务器地址**: Gotify 服务器的完整 URL（如 `https://gotify.example.com`）
   - **客户端令牌**: 在 Gotify 服务器创建的客户端 Token
4. 点击「测试连接」验证配置是否正确
5. 点击「保存」完成添加

### 配置通知设置

#### 全局通知设置

1. 进入「设置」标签
2. 在「通知设置」部分可以：
   - 开启/关闭系统通知
   - 开启/关闭通知声音

#### 应用级通知设置

1. 进入「设置」→「管理应用通知」
2. 可以看到所有已连接服务器中的应用列表
3. 使用右上角的筛选按钮按服务器筛选
4. 为每个应用单独设置是否启用通知
5. 可以使用批量操作按钮一键启用/禁用所有应用通知

### 使用菜单栏功能（仅 macOS）

- **左键点击**: 打开主窗口
- **右键点击**: 显示快捷菜单
  - 打开主窗口
  - 全部标记为已读
  - 退出应用

### 设置开机启动（仅 macOS）

1. 进入「设置」标签
2. 在「启动设置」部分：
   - 开启「开机自动启动」
   - 可选开启「启动时隐藏主窗口」实现后台启动

## 从源码构建

### 前置要求

- macOS 15.0 或更高版本
- Xcode 16.0 或更高版本
- Apple Developer 账号（用于设备部署）

### 通过 Xcode 构建

1. 克隆仓库：
   ```bash
   git clone https://github.com/AkagiYui/GotifyClientMac.git
   cd GotifyClientMac
   ```

2. 使用 Xcode 打开项目：
   ```bash
   open GotifyClient.xcodeproj
   ```

3. 选择目标设备（My Mac 或 iOS 设备/模拟器）

4. 点击运行按钮（⌘R）或选择 Product → Run

### 通过命令行构建

#### 构建 macOS 版本

```bash
xcodebuild -project GotifyClient.xcodeproj \
  -scheme GotifyClient \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  clean build
```

构建产物位于: `build/Build/Products/Release/GotifyClient.app`

#### 构建 iOS 模拟器版本

```bash
xcodebuild -project GotifyClient.xcodeproj \
  -scheme GotifyClient \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -derivedDataPath build \
  clean build
```

构建产物位于: `build/Build/Products/Release-iphonesimulator/GotifyClient.app`

### 运行构建后的应用

#### macOS

```bash
open build/Build/Products/Release/GotifyClient.app
```

#### iOS 模拟器

```bash
xcrun simctl install booted build/Build/Products/Release-iphonesimulator/GotifyClient.app
xcrun simctl launch booted com.akagiyui.GotifyClient
```

## 技术栈

- **UI 框架**: SwiftUI
- **数据持久化**: SwiftData
- **网络通信**: URLSession WebSocket
- **通知**: UserNotifications
- **菜单栏**: NSStatusBar (macOS)
- **开机启动**: ServiceManagement (macOS)

## 许可证

MIT License

