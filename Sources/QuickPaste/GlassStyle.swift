import SwiftUI

/// 原生液态玻璃与旧系统材质共用的表面，遵循系统辅助功能设置。
private struct GlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if reduceTransparency {
                content.background(tint, in: shape)
                    .background(Color(nsColor: .windowBackgroundColor), in: shape)
            } else {
                translucent(content, shape: shape)
            }
        }
        .overlay {
            Group {
                if reduceTransparency {
                    shape.strokeBorder(.primary.opacity(0.12), lineWidth: 0.75)
                } else {
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.08)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.75)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func translucent(_ content: Content, shape: RoundedRectangle) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.tint(tint), in: shape)
        } else {
            content.background(tint, in: shape)
                .background(.ultraThinMaterial, in: shape)
        }
        #else
        content.background(tint, in: shape)
            .background(.ultraThinMaterial, in: shape)
        #endif
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat, tint: Color = .clear) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: tint))
    }
}
