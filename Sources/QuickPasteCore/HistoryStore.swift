import Combine
import CryptoKit
import Foundation

/// 图片条目的元数据，图片本身以 PNG 文件保存在 `HistoryStore.imageDirectory` 中。
public struct ClipImage: Codable, Equatable {
    /// 文件名，取 PNG 内容的 SHA-256，相同图片只保存一份。
    public let file: String
    public let width: Int
    public let height: Int

    public init(file: String, width: Int, height: Int) {
        self.file = file
        self.width = width
        self.height = height
    }
}

public struct ClipItem: Codable, Equatable, Identifiable {
    public let id: UUID
    /// 图片条目为空字符串。
    public let text: String
    public let date: Date
    public let image: ClipImage?

    public var isImage: Bool { image != nil }

    public init(id: UUID = UUID(), text: String, image: ClipImage? = nil, date: Date = Date()) {
        self.id = id
        self.text = text
        self.image = image
        self.date = date
    }
}

/// 剪贴板历史：最新的在前，重复内容移到最前，超出上限丢弃最旧的。
public final class HistoryStore: ObservableObject {
    @Published public private(set) var items: [ClipItem] = []

    /// 最多保留的条数，调小时立即删除超出的条目及其图片文件。
    public var limit: Int {
        didSet {
            guard limit != oldValue else { return }
            trimToLimit()
            save()
        }
    }
    public let imageDirectory: URL
    private let fileURL: URL?

    /// `fileURL` 为 nil 时历史只保存在内存中，图片写到临时目录。
    /// 图片默认保存在 `fileURL` 同级的 images 目录。
    public init(fileURL: URL?, imageDirectory: URL? = nil, limit: Int = 30) {
        self.fileURL = fileURL
        self.limit = limit
        self.imageDirectory = imageDirectory
            ?? fileURL?.deletingLastPathComponent().appendingPathComponent("images", isDirectory: true)
            ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("QuickPaste-\(UUID().uuidString)", isDirectory: true)
        load()
    }

    public func add(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        items.removeAll { !$0.isImage && $0.text == text }
        insert(ClipItem(text: text))
    }

    public func addImage(png: Data, width: Int, height: Int) {
        guard !png.isEmpty else { return }
        let file = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined() + ".png"
        let url = imageDirectory.appendingPathComponent(file)
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(
                    at: imageDirectory, withIntermediateDirectories: true)
                try png.write(to: url, options: .atomic)
            } catch {
                NSLog("QuickPaste: 保存图片失败 \(error)")
                return
            }
        }
        // 只移除旧条目，图片文件由新条目继续使用。
        items.removeAll { $0.image?.file == file }
        insert(ClipItem(text: "", image: ClipImage(file: file, width: width, height: height)))
    }

    public func imageURL(for item: ClipItem) -> URL? {
        item.image.map { imageDirectory.appendingPathComponent($0.file) }
    }

    public func remove(id: UUID) {
        items.filter { $0.id == id }.forEach(deleteImageFile)
        items.removeAll { $0.id == id }
        save()
    }

    public func clear() {
        items.forEach(deleteImageFile)
        items.removeAll()
        save()
    }

    /// 图片条目可以用“图片”或“image”搜到。
    public func search(_ query: String) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter {
            $0.isImage
                ? "图片 image".localizedCaseInsensitiveContains(q)
                : $0.text.localizedCaseInsensitiveContains(q)
        }
    }

    private func insert(_ item: ClipItem) {
        items.insert(item, at: 0)
        trimToLimit()
        save()
    }

    private func trimToLimit() {
        guard items.count > limit else { return }
        items[limit...].forEach(deleteImageFile)
        items.removeLast(items.count - limit)
    }

    private func deleteImageFile(of item: ClipItem) {
        guard let url = imageURL(for: item) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data)
        else { return }
        // 丢掉图片文件已不存在的条目。
        items = decoded.filter { item in
            imageURL(for: item).map { FileManager.default.fileExists(atPath: $0.path) } ?? true
        }
        trimToLimit()
        removeOrphanImages()
        if items.count != decoded.count { save() }
    }

    /// 删除图片目录中不再被任何条目引用的文件。
    private func removeOrphanImages() {
        let referenced = Set(items.compactMap(\.image?.file))
        let files = (try? FileManager.default.contentsOfDirectory(
            at: imageDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where !referenced.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
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
