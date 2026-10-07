import AppKit
import Carbon

/// 把文本或图片写回剪贴板，并在有辅助功能权限时模拟 ⌘V 粘贴到前台应用。
enum Paster {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// 弹出系统授权提示（引导用户到“隐私与安全性 → 辅助功能”）。
    static func requestTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// 同时写入 PNG 和 TIFF，兼容只认其中一种的应用。读取失败时返回 false。
    static func copyImage(at url: URL) -> Bool {
        guard let png = try? Data(contentsOf: url) else { return false }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(png, forType: .png)
        if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
        return true
    }

    static func pasteToFrontApp() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
