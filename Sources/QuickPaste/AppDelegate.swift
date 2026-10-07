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
    private let limitMenu = NSMenu()

    private static let limitKey = "historyLimit"
    private static let defaultLimit = 30
    private static let limitPresets = [10, 30, 50, 100, 200]

    /// 保存在 UserDefaults，也可以用 `defaults write <bundle id> historyLimit -int N` 修改。
    private static var savedLimit: Int {
        let value = UserDefaults.standard.integer(forKey: limitKey)
        return value > 0 ? value : defaultLimit
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = HistoryStore(fileURL: Self.historyURL, limit: Self.savedLimit)
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
        let limitItem = NSMenuItem(title: "保留条数", action: nil, keyEquivalent: "")
        limitItem.submenu = limitMenu
        menu.addItem(limitItem)
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 QuickPaste", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        rebuildLimitMenu()
    }

    // MARK: - 保留条数

    private func rebuildLimitMenu() {
        limitMenu.removeAllItems()
        let current = store.limit
        for count in Self.limitPresets {
            let item = NSMenuItem(title: "\(count) 条", action: #selector(chooseLimit(_:)), keyEquivalent: "")
            item.tag = count
            item.state = count == current ? .on : .off
            item.target = self
            limitMenu.addItem(item)
        }
        limitMenu.addItem(.separator())
        let isCustom = !Self.limitPresets.contains(current)
        let custom = NSMenuItem(
            title: isCustom ? "自定义（\(current) 条）…" : "自定义…",
            action: #selector(chooseCustomLimit), keyEquivalent: "")
        custom.state = isCustom ? .on : .off
        custom.target = self
        limitMenu.addItem(custom)
    }

    @objc private func chooseLimit(_ sender: NSMenuItem) {
        setLimit(sender.tag)
    }

    @objc private func chooseCustomLimit() {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = String(store.limit)
        let alert = NSAlert()
        alert.messageText = "保留条数"
        alert.informativeText = "超出的旧记录（包括图片）会被删除。"
        alert.accessoryView = field
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn,
              let count = Int(field.stringValue.trimmingCharacters(in: .whitespaces)), count > 0
        else { return }
        setLimit(count)
    }

    private func setLimit(_ count: Int) {
        UserDefaults.standard.set(count, forKey: Self.limitKey)
        store.limit = count
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
