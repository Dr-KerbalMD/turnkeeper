import Foundation

/// Reads and writes the library as `library.json`.
public struct LibraryFile: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `library.json` in the app's Application Support folder.
    public static func standard() throws -> LibraryFile {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("Turnkeeper", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return LibraryFile(url: folder.appendingPathComponent("library.json"))
    }

    /// The saved library, or an empty one when nothing has been saved yet.
    public func load() throws -> Library {
        guard FileManager.default.fileExists(atPath: url.path) else { return Library() }
        do {
            return try JSONDecoder().decode(Library.self, from: Data(contentsOf: url))
        } catch {
            throw LibraryFileError.unreadable(url.lastPathComponent, underlying: error.localizedDescription)
        }
    }

    /// Writes atomically, so a crash mid-save never leaves a half-written library.
    public func save(_ library: Library) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(library).write(to: url, options: .atomic)
    }
}

public enum LibraryFileError: Error, LocalizedError, Equatable {
    case unreadable(String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case let .unreadable(name, underlying):
            return "Loading the library failed: \(name) is unreadable (\(underlying))."
        }
    }
}
