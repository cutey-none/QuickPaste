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
                list
            }

            Divider()
            Text("↑↓ 选择 · ↩ 粘贴 · ⌘1–9 快速选择 · ⌘⌫ 删除 · esc 关闭")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
        .frame(width: 640, height: 420)
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

    private func row(_ item: ClipItem, index: Int) -> some View {
        let selected = index == model.selection
        return HStack(spacing: 10) {
            Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ⏎ "))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.date, style: .relative)
                .font(.caption)
                .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.caption.monospaced())
                    .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .foregroundStyle(selected ? .white : .primary)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
