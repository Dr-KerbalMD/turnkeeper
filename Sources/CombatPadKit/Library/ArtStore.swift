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
        ).appendingPathComponent("Combat Pad/Art", isDirectory: true)
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
        let prepared = try PreparedImage(image)
        let id = UUID()
        var art = CustomArt(subject: subject, fileName: "\(id.uuidString).\(prepared.fileExtension)",
                            byteCount: prepared.data.count)
        art.id = id
        try write(prepared.data, as: art.fileName)
        return art
    }

    /// Removes files no live record points to.
    public func sweep(keeping fileNames: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where !fileNames.contains(file) {
            try? FileManager.default.removeItem(at: url(for: file))
        }
    }
}

/// A pasted image ready to store: at most 2048 px on its long side, JPEG, or PNG when it has transparency.
public struct PreparedImage: Sendable {
    public static let maximumPixels = 2048

    public let data: Data
    public let fileExtension: String
    public let pixelSize: CGSize

    public init(_ original: Data) throws {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maximumPixels
        ]
        guard let source = CGImageSourceCreateWithData(original as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
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
}

public enum ArtStoreError: Error, LocalizedError, Equatable {
    case unreadableImage
    case writeFailed(String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case .unreadableImage: return "Adding the artwork failed: the pasted data isn't an image Combat Pad can read."
        case let .writeFailed(name, underlying): return "Saving the artwork failed: \(name) (\(underlying))."
        }
    }
}
