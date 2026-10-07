import Combine
import Foundation

public struct ClipItem: Codable, Equatable, Identifiable {
    public let id: UUID
    public let text: String
    public let date: Date

    public init(id: UUID = UUID(), text: String, date: Date = Date()) {
        self.id = id
        self.text = text
        self.date = date
    }
}

/// 剪贴板历史：最新的在前，重复内容移到最前，超出上限丢弃最旧的。
public final class HistoryStore: ObservableObject {
    @Published public private(set) var items: [ClipItem] = []

    public let limit: Int
    private let fileURL: URL?

    /// `fileURL` 为 nil 时只保存在内存中。
    public init(fileURL: URL?, limit: Int = 200) {
        self.fileURL = fileURL
        self.limit = limit
        load()
    }

    public func add(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        items.removeAll { $0.text == text }
        items.insert(ClipItem(text: text), at: 0)
        if items.count > limit {
            items.removeLast(items.count - limit)
        }
        save()
    }

    public func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    public func clear() {
        items.removeAll()
        save()
    }

    public func search(_ query: String) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data)
        else { return }
        items = Array(decoded.prefix(limit))
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("QuickPaste: 保存历史失败 \(error)")
        }
    }
}
