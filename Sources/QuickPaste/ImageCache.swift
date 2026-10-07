import AppKit
import ImageIO
import SwiftUI

/// 按需缩小并缓存历史中的图片，避免列表和预览直接解码原图。
enum ImageCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func cached(_ url: URL, maxPixel: Int) -> NSImage? {
        cache.object(forKey: key(url, maxPixel))
    }

    /// 在后台线程解码，结果写入缓存。
    static func load(_ url: URL, maxPixel: Int) async -> NSImage? {
        if let image = cached(url, maxPixel: maxPixel) { return image }
        let cgImage = await Task.detached(priority: .userInitiated) {
            downsample(url, maxPixel: maxPixel)
        }.value
        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(image, forKey: key(url, maxPixel))
        return image
    }

    private static func key(_ url: URL, _ maxPixel: Int) -> NSString {
        "\(url.lastPathComponent)@\(maxPixel)" as NSString
    }

    private static func downsample(_ url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// 异步显示缩小后的图片，加载完成前显示占位色块。
struct ClipImageView: View {
    let url: URL
    let maxPixel: Int
    @State private var image: NSImage?

    init(url: URL, maxPixel: Int) {
        self.url = url
        self.maxPixel = maxPixel
        _image = State(initialValue: ImageCache.cached(url, maxPixel: maxPixel))
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable()
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .task(id: url) {
            image = await ImageCache.load(url, maxPixel: maxPixel)
        }
    }
}
