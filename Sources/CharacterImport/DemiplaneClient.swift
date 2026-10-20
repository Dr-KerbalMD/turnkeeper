import Bestiary
import TurnkeeperKit
import Foundation

/// A character as its sheet page describes it: identity only, no computed statistics.
public struct DemiplaneCharacter: Sendable, Equatable {
    public var id: String
    public var name: String
    public var level: Int
    public var game: Game?
    public var avatarURL: URL?
}

/// Where the exported sheet PDF is, and the revision of the character it was made from.
public struct SheetExport: Sendable, Equatable {
    public var url: URL
    public var revision: String
}

/// Talks to Demiplane's web app as anyone with a shared character's link can: no account, cookies or token.
/// Undocumented; see `docs/specs/turnkeeper/design.md`.
public struct DemiplaneClient: Sendable {
    public var transport: any HTTPTransport
    /// How long to wait between asking whether an export is ready, and how many times to ask.
    public var pollInterval: Duration = .seconds(2)
    public var maximumPolls = 45
    public var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }

    static let appURL = URL(string: "https://app.demiplane.com")!
    /// Every request skips the URL cache: the sheet's address never changes, so a cached copy would hide a
    /// player's rebuild.
    static let uncached = URLRequest.CachePolicy.reloadIgnoringLocalCacheData

    public init(transport: any HTTPTransport) {
        self.transport = transport
    }

    /// The sheet PDF at a URL from `exportSheet`.
    public func sheetPDF(at url: URL) async throws -> Data {
        let operation = "Downloading the character sheet"
        let (data, response) = try await transport.send(URLRequest(url: url, cachePolicy: Self.uncached))
        switch response.statusCode {
        case 200: return data
        case 401, 403, 404: throw CharacterImportError.notShared(operation: operation)
        default: throw CharacterImportError.rejected(operation: operation, status: response.statusCode, message: "")
        }
    }
}
