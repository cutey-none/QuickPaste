import AppKit
import Carbon
import QuickPasteCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var store: HistoryStore!
    private var monitor: ClipboardMonitor!
    private var panel: PanelController!
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem!
    private let launchAtLoginItem = NSMenuItem(
        title: "开机启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = HistoryStore(fileURL: Self.historyURL)
        panel = PanelController(store: store)
        monitor = ClipboardMonitor(
            onNewText: { [weak self] text in self?.store.add(text) },
            onNewImage: { [weak self] png, width, height in
                self?.store.addImage(png: png, width: width, height: height)
            })
        monitor.start()

        hotKey = HotKey(keyCode: kVK_ANSI_V, modifiers: cmdKey | shiftKey) { [weak self] in
            self?.panel.toggle()
        }
        setUpStatusItem()
    }

    private static var historyURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QuickPaste", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    // MARK: - 菜单栏

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard", accessibilityDescription: "QuickPaste")

        let menu = NSMenu()
        menu.delegate = self

        let open = NSMenuItem(title: "打开剪贴板", action: #selector(openPanel), keyEquivalent: "v")
        open.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(open)
        menu.addItem(NSMenuItem(title: "清空历史", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 QuickPaste", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func openPanel() {
        panel.show()
    }

    @objc private func clearHistory() {
        store.clear()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "无法修改开机启动设置"
            alert.runModal()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
