import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The folder of pasted images, next to `library.json`. Files are named by the `CustomArt` that points to
/// them, so a replaced image gets a new file and the old one is swept once nothing points to it.
public struct ArtStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `Art/` in the app's Application Support folder.
    public static func standard() throws -> ArtStore {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("Turnkeeper/Art", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return ArtStore(directory: folder)
    }

    public func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    public func contains(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName).path)
    }

    public func data(for fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }

    public func write(_ data: Data, as fileName: String) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url(for: fileName), options: .atomic)
        } catch {
            throw ArtStoreError.writeFailed(fileName, underlying: error.localizedDescription)
        }
    }

    /// Stores a pasted image for `subject`, downscaled, and returns the record that points to it.
    public func add(_ image: Data, for subject: String) throws -> CustomArt {
        let stored = try store(image)
        return CustomArt(subject: subject, fileName: stored.fileName, byteCount: stored.byteCount)
    }

    /// Stores an image, downscaled, under a new file name.
    public func store(_ image: Data) throws -> StoredImage {
        let prepared = try PreparedImage(image)
        let stored = StoredImage(fileName: "\(UUID().uuidString).\(prepared.fileExtension)",
                                 byteCount: prepared.data.count)
        try write(prepared.data, as: stored.fileName)
        return stored
    }

    /// Removes files no live record points to.
    public func sweep(keeping fileNames: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where !fileNames.contains(file) {
            try? FileManager.default.removeItem(at: url(for: file))
        }
    }
}

/// An image file in the store.
public struct StoredImage: Sendable, Equatable {
    public var fileName: String
    public var byteCount: Int
}

/// A pasted image ready to store: at most 2048 px on its long side, JPEG, or PNG when it has transparency. A PDF
/// is stored as an image of its first page.
public struct PreparedImage: Sendable {
    public static let maximumPixels = 2048

    public let data: Data
    public let fileExtension: String
    public let pixelSize: CGSize

    public init(_ original: Data) throws {
        // PDFs first: the Mac's ImageIO reads them too, but only at 1×, and the iPad's doesn't.
        let isPDF = original.starts(with: Data("%PDF".utf8))
        guard let image = isPDF ? PDFPageImage.firstPage(of: original, maximumPixels: Self.maximumPixels)
                                : Self.image(from: original) else {
            throw ArtStoreError.unreadableImage
        }
        let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)
        let type = hasAlpha ? UTType.png : .jpeg
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil)
        else { throw ArtStoreError.unreadableImage }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85]
                                   as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ArtStoreError.unreadableImage }
        data = output as Data
        fileExtension = hasAlpha ? "png" : "jpg"
        pixelSize = CGSize(width: image.width, height: image.height)
    }

    private static func image(from original: Data) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixels
        ]
        guard let source = CGImageSourceCreateWithData(original as CFData, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

public enum ArtStoreError: Error, LocalizedError, Equatable {
    case unreadableImage
    case writeFailed(String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case .unreadableImage: return "Adding the artwork failed: the pasted data isn't an image Turnkeeper can read."
        case let .writeFailed(name, underlying): return "Saving the artwork failed: \(name) (\(underlying))."
        }
    }
}
