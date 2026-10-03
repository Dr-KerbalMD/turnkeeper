import CombatPadKit
import ImageIO
import SwiftUI

/// A creature's art from the bundled `Generated` folder, loaded off the main thread and downsampled to the
/// size shown. Shows a placeholder when there is no art.
struct ArtImage: View {
    enum Shape {
        case circle
        case rectangle
    }

    let path: String
    let size: CGFloat
    var shape: Shape = .rectangle
    var contentMode: ContentMode = .fill
    /// Which part stays visible when filling: the top keeps faces in view.
    var alignment: Alignment = .center
    @Environment(AppModel.self) private var model
    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?

    var body: some View {
        content
            .frame(width: size, height: size, alignment: alignment)
            .clipShape(clip)
            .task(id: path) { image = await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(decorative: image, scale: displayScale).resizable().aspectRatio(contentMode: contentMode)
                .frame(width: size, height: size, alignment: alignment)
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: "pawprint").foregroundStyle(.secondary)
            }
        }
    }

    private var clip: AnyShape {
        shape == .circle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 6))
    }

    private func load() async -> CGImage? {
        guard let url = model.bestiary.url(for: path) else { return nil }
        let pixels = Int(size * displayScale)
        return await ArtLoader.shared.image(at: url, maxPixels: pixels)
    }
}

/// Loads and caches downsampled images.
actor ArtLoader {
    static let shared = ArtLoader()
    private let cache = NSCache<NSString, CGImage>()

    /// The image at `url`, scaled so its longest side is at most `maxPixels`; 0 means full size.
    func image(at url: URL, maxPixels: Int) -> CGImage? {
        let key = "\(url.path)#\(maxPixels)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let image: CGImage?
        if maxPixels > 0 {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixels
            ]
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        } else {
            image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        if let image { cache.setObject(image, forKey: key) }
        return image
    }
}

extension ArtReference {
    /// The best picture for a small circle: the portrait, since Foundry ring tokens have wide margins.
    var thumbnail: String { portrait.isEmpty ? token : portrait }
}
