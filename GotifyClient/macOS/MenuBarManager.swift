//
//  MenuBarManager.swift
//  GotifyClient
//
//  macOS菜单栏管理器
//

#if os(macOS)
import AppKit
import SwiftUI
import Observation

/// macOS菜单栏管理器
@MainActor
@Observable
final class MenuBarManager: NSObject {
    /// 单例实例
    static let shared = MenuBarManager()
    
    /// 状态栏项
    private var statusItem: NSStatusItem?
    
    /// 未读消息数量
    var unreadCount: Int = 0 {
        didSet {
            updateStatusItemImage()
        }
    }
    
    /// 打开主窗口的回调
    var onOpenMainWindow: (() -> Void)?
    
    /// 退出应用的回调
    var onQuitApp: (() -> Void)?
    
    private override init() {
        super.init()
    }
    
    /// 设置菜单栏项
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        updateStatusItemImage()
        
        // 设置左键点击行为
        if let button = statusItem?.button {
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    /// 更新状态栏图标
    private func updateStatusItemImage() {
        guard let button = statusItem?.button else { return }
        
        let imageName = unreadCount > 0 ? "bell.badge.fill" : "bell.fill"
        let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Gotify")
        image?.isTemplate = true
        button.image = image
        
        // 显示未读数量
        if unreadCount > 0 {
            button.title = " \(unreadCount > 99 ? "99+" : "\(unreadCount)")"
        } else {
            button.title = ""
        }
    }
    
    /// 状态栏项点击处理
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            openMainWindow()
        }
    }
    
    /// 显示上下文菜单
    private func showContextMenu() {
        let menu = NSMenu()
        
        let openItem = NSMenuItem(
            title: "打开主窗口",
            action: #selector(openMainWindowAction),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)
        
        let markAllReadItem = NSMenuItem(
            title: "全部标记为已读",
            action: #selector(markAllAsReadAction),
            keyEquivalent: ""
        )
        markAllReadItem.target = self
        menu.addItem(markAllReadItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitAppAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // 清除菜单，以便下次左键点击生效
    }
    
    /// 打开主窗口
    @objc private func openMainWindowAction() {
        openMainWindow()
    }
    
    private func openMainWindow() {
        onOpenMainWindow?()
    }
    
    /// 全部标记为已读
    @objc private func markAllAsReadAction() {
        AppState.shared.markAllAsRead()
        unreadCount = 0
    }
    
    /// 退出应用
    @objc private func quitAppAction() {
        onQuitApp?()
    }
    
    /// 移除菜单栏项
    func removeMenuBar() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }
}
#endif
