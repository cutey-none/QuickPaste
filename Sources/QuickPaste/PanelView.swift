import QuickPasteCore
import SwiftUI

final class PanelModel: ObservableObject {
    @Published var query = "" {
        didSet { selection = 0 }
    }
    @Published var selection = 0
}

struct PanelView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: HistoryStore
    let onSelect: (ClipItem) -> Void

    @FocusState private var searchFocused: Bool

    private var results: [ClipItem] { store.search(model.query) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索剪贴板历史", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($searchFocused)
            }
            .padding(14)

            Divider()

            if results.isEmpty {
                Text(store.items.isEmpty ? "还没有剪贴板记录" : "没有匹配的记录")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    list.frame(width: 340)
                    Divider()
                    preview
                }
            }

            Divider()
            Text("↑↓ 选择 · ↩ 粘贴 · ⌘1–9 快速选择 · ⌘⌫ 删除 · esc 关闭")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
        .frame(width: 800, height: 460)
        .background(.regularMaterial)
        .onAppear { searchFocused = true }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                        row(item, index: index)
                            .id(item.id)
                            .onTapGesture { onSelect(item) }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selection) { selection in
                guard results.indices.contains(selection) else { return }
                proxy.scrollTo(results[selection].id)
            }
        }
    }

    private var selectedItem: ClipItem? {
        let items = results
        return items.indices.contains(model.selection) ? items[model.selection] : nil
    }

    private func row(_ item: ClipItem, index: Int) -> some View {
        let selected = index == model.selection
        return HStack(spacing: 10) {
            if let url = store.imageURL(for: item), let image = item.image {
                ClipImageView(url: url, maxPixel: 96)
                    .scaledToFill()
                    .frame(width: 40, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.25)))
                Text("图片")
                Text(verbatim: "\(image.width) × \(image.height)")
                    .font(.caption)
                    .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ⏎ "))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.caption.monospaced())
                    .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .foregroundStyle(selected ? .white : .primary)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }

    // MARK: - 预览

    @ViewBuilder
    private var preview: some View {
        if let item = selectedItem {
            VStack(alignment: .leading, spacing: 10) {
                if let url = store.imageURL(for: item), let image = item.image {
                    // 小图不放大，避免发糊。
                    ClipImageView(url: url, maxPixel: 1200)
                        .scaledToFit()
                        .frame(maxWidth: CGFloat(image.width), maxHeight: CGFloat(image.height))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(item.text)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                Text(detail(of: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(item.id)
        } else {
            Color.clear
        }
    }

    private func detail(of item: ClipItem) -> String {
        let time = item.date.formatted(.relative(presentation: .named))
        if let image = item.image {
            return "图片 · \(image.width) × \(image.height) · \(time)"
        }
        return "\(item.text.count) 个字符 · \(time)"
    }
}
