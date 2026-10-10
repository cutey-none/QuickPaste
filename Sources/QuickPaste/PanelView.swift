import QuickPasteCore
import SwiftUI

final class PanelModel: ObservableObject {
    @Published var query = "" {
        didSet { selection = 0 }
    }
    @Published var selection = 0
}

struct PanelView: View {
    static let size = CGSize(width: 860, height: 540)

    @ObservedObject var model: PanelModel
    @ObservedObject var store: HistoryStore
    let onSelect: (ClipItem) -> Void

    @FocusState private var searchFocused: Bool
    @AppStorage("darkAppearance") private var darkAppearance = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredItem: UUID?

    private var results: [ClipItem] { store.search(model.query) }

    var body: some View {
        VStack(spacing: 16) {
            header
            search
            if results.isEmpty {
                emptyState
            } else {
                HStack(spacing: 16) {
                    list.frame(width: 320)
                    preview
                }
                .frame(maxHeight: .infinity)
            }
            footer
        }
        .padding(20)
        .frame(width: Self.size.width, height: Self.size.height)
        .glassSurface(cornerRadius: 28,
                      tint: darkAppearance ? .black.opacity(0.28) : .white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .preferredColorScheme(darkAppearance ? .dark : .light)
        .onAppear { searchFocused = true }
        .onChange(of: darkAppearance) { _ in searchFocused = true }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .glassSurface(cornerRadius: 12, tint: .accentColor.opacity(0.08))
            Text("QuickPaste").font(.system(size: 18, weight: .semibold, design: .rounded))
            Text("剪贴板历史").font(.callout).foregroundStyle(.secondary)
            Spacer()
            Toggle(isOn: $darkAppearance) {
                Label("深色", systemImage: "moon.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("关闭为亮色，开启为暗色；自动记住你的选择")
            .accessibilityLabel("深色外观")
            keycap("⌘⇧V")
        }
    }

    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("搜索文本或图片…", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)
                .accessibilityLabel("搜索剪贴板历史")
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
            Text("\(results.count) 条")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .glassSurface(cornerRadius: 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: store.items.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.accentColor)
            Text(store.items.isEmpty ? "还没有剪贴板记录" : "没有匹配的记录")
                .font(.headline)
            Text(store.items.isEmpty ? "复制文本或图片后，会自动出现在这里。" : "试试其他关键词，或搜索“图片”。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                        row(item, index: index).id(item.id)
                    }
                }
                .padding(4)
            }
            .onChange(of: model.selection) { selection in
                guard results.indices.contains(selection) else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                    proxy.scrollTo(results[selection].id)
                }
            }
            .onChange(of: model.query) { _ in
                if let first = results.first { proxy.scrollTo(first.id, anchor: .top) }
            }
        }
    }

    private var selectedItem: ClipItem? {
        let items = results
        return items.indices.contains(model.selection) ? items[model.selection] : nil
    }

    private func row(_ item: ClipItem, index: Int) -> some View {
        let selected = index == model.selection
        return Button { onSelect(item) } label: {
            HStack(spacing: 12) {
                thumbnail(item)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.isImage ? "图片" : item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(item.date, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if index < 9 { keycap("⌘\(index + 1)") }
            }
            .padding(.horizontal, 12)
            .frame(height: 62)
            .foregroundStyle(.primary)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                        }
                } else if hoveredItem == item.id {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.primary.opacity(0.05))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .onHover { hoveredItem = $0 ? item.id : nil }
        .accessibilityLabel(item.isImage ? "图片" : item.text)
        .accessibilityValue(selected ? "已选中" : "")
        .accessibilityHint("粘贴到之前的应用")
    }

    @ViewBuilder
    private func thumbnail(_ item: ClipItem) -> some View {
        if let url = store.imageURL(for: item) {
            ClipImageView(url: url, maxPixel: 96)
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: "text.alignleft")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let item = selectedItem {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(item.isImage ? "图片预览" : "文本预览",
                          systemImage: item.isImage ? "photo" : "text.alignleft")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Divider().opacity(0.5)
                if let url = store.imageURL(for: item), let image = item.image {
                    ClipImageView(url: url, maxPixel: 1200)
                        .scaledToFit()
                        .frame(maxWidth: CGFloat(image.width), maxHeight: CGFloat(image.height))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(item.text)
                            .font(.system(size: 14))
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity)
                }
                Divider().opacity(0.5)
                HStack(spacing: 8) {
                    Text(detail(of: item))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button { onSelect(item) } label: {
                        HStack(spacing: 6) {
                            Text("粘贴").fontWeight(.medium)
                            Image(systemName: "return")
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassSurface(cornerRadius: 12, tint: .accentColor.opacity(0.12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("粘贴到之前的应用")
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.06), lineWidth: 1)
            }
            .id(item.id)
        } else {
            Color.clear
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            shortcut("↑↓", label: "选择")
            shortcut("↩", label: "粘贴")
            shortcut("⌘1–9", label: "快速粘贴")
            Spacer(minLength: 0)
            shortcut("⌘⌫", label: "删除")
            shortcut("esc", label: "关闭")
        }
    }

    private func shortcut(_ key: String, label: String) -> some View {
        HStack(spacing: 5) {
            keycap(key)
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private func keycap(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
    }

    private func detail(of item: ClipItem) -> String {
        if let image = item.image { return "\(image.width) × \(image.height) 像素" }
        return "\(item.text.count) 个字符"
    }
}
