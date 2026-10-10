import Bestiary
import CombatPadKit
import Foundation

/// What a pasted or scanned Demiplane reference points at: a character sheet link (as in the sheet's QR
/// code), a bare character ID, or a campaign link.
public enum DemiplaneReference: Equatable, Sendable {
    /// A character's UUID, with the game when the link names it.
    case character(id: String, game: Game?)
    case campaign(id: String, game: Game?)

    /// Reads a link or ID, ignoring surrounding text. Nil when there is no UUID in it.
    public static func parse(_ text: String) -> DemiplaneReference? {
        let uuids = text.matches(of: uuidPattern).map { String(text[$0.range]).lowercased() }
        guard let last = uuids.last else { return nil }
        let game = game(in: text)
        if let campaign = text.firstMatch(of: campaignPattern) {
            return .campaign(id: String(campaign.output.id).lowercased(), game: game)
        }
        return .character(id: last, game: game)
    }

    /// The game for a Demiplane nexus slug, such as `pathfinder2e` in a link or `starfinder2e` from the API.
    public static func game(nexus slug: String) -> Game? {
        switch slug.lowercased() {
        case "pathfinder2e", "pathfinder-2e": return .pathfinder
        case "starfinder2e", "starfinder-2e": return .starfinder
        default: return nil
        }
    }

    /// The game's slug in Demiplane's page paths, such as `/nexus/starfinder2e/campaigns/…`.
    public static func nexusSlug(for game: Game) -> String {
        game == .starfinder ? "starfinder2e" : "pathfinder2e"
    }

    private static func game(in text: String) -> Game? {
        text.firstMatch(of: nexusPattern).flatMap { game(nexus: String($0.output.slug)) }
    }

    private static var uuidPattern: Regex<Substring> {
        /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
    }

    private static var campaignPattern: Regex<(Substring, id: Substring)> {
        /\/campaigns\/(?<id>[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/
    }

    private static var nexusPattern: Regex<(Substring, slug: Substring)> {
        /\/nexus\/(?<slug>[\w-]+)\//
    }
}
