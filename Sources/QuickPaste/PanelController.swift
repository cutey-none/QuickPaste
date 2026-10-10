import AppKit
import Carbon
import QuickPasteCore
import SwiftUI

/// 可成为 key window 的无边框浮动面板，用于接收搜索框输入。
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// 管理屏幕中央的剪贴板面板：显示/隐藏、键盘操作、选中后粘贴。
final class PanelController: NSObject, NSWindowDelegate {
    private let store: HistoryStore
    private let model = PanelModel()
    private var panel: NSPanel!
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(store: HistoryStore) {
        self.store = store
        super.init()

        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: PanelView.size),
            styleMask: [.borderless],
            backing: .buffered, defer: true)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: PanelView(model: model, store: store) { [weak self] item in
                self?.select(item)
            })
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        model.query = ""
        model.selection = 0
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - 选择与粘贴

    private var results: [ClipItem] { store.search(model.query) }

    private func select(_ item: ClipItem) {
        if let url = store.imageURL(for: item) {
            guard Paster.copyImage(at: url) else { return }
        } else {
            Paster.copy(item.text)
        }
        hide()
        previousApp?.activate()

        guard Paster.isTrusted else {
            // 没有辅助功能权限：内容已在剪贴板中，提示用户授权以启用自动粘贴。
            Paster.requestTrust()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Paster.pasteToFrontApp()
        }
    }

    // MARK: - 键盘

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// 返回 true 表示事件已处理，不再传给搜索框。
    private func handle(_ event: NSEvent) -> Bool {
        let items = results
        let command = event.modifierFlags.contains(.command)

        switch Int(event.keyCode) {
        case kVK_Escape:
            hide()
        case kVK_UpArrow:
            model.selection = max(model.selection - 1, 0)
        case kVK_DownArrow:
            model.selection = min(model.selection + 1, max(items.count - 1, 0))
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if items.indices.contains(model.selection) { select(items[model.selection]) }
        case kVK_Delete where command:
            guard items.indices.contains(model.selection) else { return true }
            store.remove(id: items[model.selection].id)
            model.selection = min(model.selection, max(items.count - 2, 0))
        default:
            guard command,
                  let digit = event.charactersIgnoringModifiers.flatMap(Int.init),
                  (1...9).contains(digit)
            else { return false }
            if items.indices.contains(digit - 1) { select(items[digit - 1]) }
        }
        return true
    }
}
