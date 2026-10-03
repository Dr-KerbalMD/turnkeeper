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

    public init(library: Library, bestiaryRevision: String, exportedAt: Date = Date()) {
        format = Self.currentFormat
        self.exportedAt = exportedAt
        self.bestiaryRevision = bestiaryRevision
        self.library = library
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
