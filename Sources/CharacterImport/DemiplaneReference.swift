import Bestiary
import TurnkeeperKit
import Foundation

/// The character a pasted or scanned Demiplane reference points at: a character sheet link (as in the sheet's
/// QR code) or a bare character ID.
public struct DemiplaneReference: Equatable, Sendable {
    /// The character's UUID.
    public var id: String
    /// The game, when the link names it.
    public var game: Game?

    public init(id: String, game: Game?) {
        self.id = id
        self.game = game
    }

    /// Reads a link or ID, ignoring surrounding text. Nil when there is no UUID in it, and for a campaign
    /// link, since campaigns aren't imported.
    public static func parse(_ text: String) -> DemiplaneReference? {
        guard text.firstMatch(of: campaignPattern) == nil,
              let last = text.matches(of: uuidPattern).last else { return nil }
        return DemiplaneReference(id: String(text[last.range]).lowercased(), game: game(in: text))
    }

    /// The game for a Demiplane nexus slug, such as `pathfinder2e` or `starfinder-2e`.
    public static func game(nexus slug: String) -> Game? {
        switch slug.lowercased() {
        case "pathfinder2e", "pathfinder-2e": return .pathfinder
        case "starfinder2e", "starfinder-2e": return .starfinder
        default: return nil
        }
    }

    /// The character's sheet page on Demiplane, under the link's game or `defaultGame`.
    public func sheetURL(defaultGame: Game) -> URL {
        let slug = Self.nexusSlug(for: game ?? defaultGame)
        return URL(string: "https://app.demiplane.com/nexus/\(slug)/character-sheet/\(id)")!
    }

    /// The game's slug in Demiplane's page paths, such as `/nexus/starfinder2e/character-sheet/…`.
    public static func nexusSlug(for game: Game) -> String {
        game == .starfinder ? "starfinder2e" : "pathfinder2e"
    }

    private static func game(in text: String) -> Game? {
        text.firstMatch(of: nexusPattern).flatMap { game(nexus: String($0.output.slug)) }
    }

    private static var uuidPattern: Regex<Substring> {
        /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
    }

    private static var campaignPattern: Regex<Substring> {
        /\/campaigns\//
    }

    private static var nexusPattern: Regex<(Substring, slug: Substring)> {
        /\/nexus\/(?<slug>[\w-]+)\//
    }
}
