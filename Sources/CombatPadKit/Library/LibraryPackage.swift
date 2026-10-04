import Foundation
import UniformTypeIdentifiers

public extension UTType {
    /// A `.combatpad` file: a JSON library package.
    static let combatPadLibrary = UTType(exportedAs: "io.github.scooper4711.combatpad.library", conformingTo: .json)
}

/// The contents of a `.combatpad` file, or of a nearby-sync exchange: some or all of a library.
public struct LibraryPackage: Codable, Sendable {
    public static let currentFormat = 1

    public var format: Int
    public var exportedAt: Date
    /// The bestiary import the creatures refer to, so a mismatch can be reported.
    public var bestiaryRevision: String
    public var library: Library
    /// The bytes of the pasted images the library's art records point to, by file name.
    public var images: [String: Data] = [:]

    public init(library: Library, bestiaryRevision: String, exportedAt: Date = Date()) {
        format = Self.currentFormat
        self.exportedAt = exportedAt
        self.bestiaryRevision = bestiaryRevision
        self.library = library
    }

    private enum CodingKeys: String, CodingKey {
        case format, exportedAt, bestiaryRevision, library, images
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(Int.self, forKey: .format)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        bestiaryRevision = try container.decode(String.self, forKey: .bestiaryRevision)
        library = try container.decode(Library.self, forKey: .library)
        images = try container.decodeIfPresent([String: Data].self, forKey: .images) ?? [:]
    }

    /// The package with the images its art records point to, read from `store`.
    public func addingImages(from store: ArtStore) -> LibraryPackage {
        var package = self
        for fileName in library.liveImageFileNames {
            package.images[fileName] = store.data(for: fileName)
        }
        return package
    }

    /// Writes the package's images that `store` doesn't have yet; do this before merging the library.
    public func writeImages(to store: ArtStore) throws {
        for (fileName, data) in images where !store.contains(fileName) {
            try store.write(data, as: fileName)
        }
    }

    /// A package of one campaign with its parties, scenarios, encounters and sessions.
    public static func campaign(_ id: UUID, from library: Library, bestiaryRevision: String) -> LibraryPackage {
        var subset = Library()
        subset.campaigns = library.campaigns.filter { $0.id == id }
        subset.parties = library.parties.filter { $0.campaignID == id }
        subset.scenarios = library.scenarios.filter { $0.campaignID == id }
        let scenarioIDs = Set(subset.scenarios.map(\.id))
        subset.encounters = library.encounters.filter { scenarioIDs.contains($0.scenarioID) }
        subset.sessions = library.sessions.filter { $0.campaignID == id }
        subset.customCreatures = library.customCreatures.filter { $0.campaignID == id }
        let subjects = Set(subset.encounters.flatMap { $0.variants.flatMap { $0.slots.map(\.creatureKey) } })
            .union(subset.customCreatures.map(\.key))
        subset.customArt = library.customArt.filter { subjects.contains($0.subject) }
        subset.handouts = library.handouts.filter { scenarioIDs.contains($0.scenarioID) }
        subset.creatureNotes = library.creatureNotes.filter { scenarioIDs.contains($0.scenarioID) }
        return LibraryPackage(library: subset, bestiaryRevision: bestiaryRevision)
    }

    /// JSON with sorted keys. Dates use the default encoding, seconds as a double, which round-trips
    /// exactly so modification times compare equal after a transfer.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> LibraryPackage {
        let decoder = JSONDecoder()
        let package = try decoder.decode(LibraryPackage.self, from: data)
        guard package.format <= currentFormat else { throw LibraryError.newerFormat(package.format) }
        return package
    }
}

public enum LibraryError: Error, LocalizedError, Equatable {
    case newerFormat(Int)

    public var errorDescription: String? {
        switch self {
        case let .newerFormat(format):
            return "Opening the library failed: it was saved in format \(format) by a newer Combat Pad."
        }
    }
}
