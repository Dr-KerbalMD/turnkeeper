import Bestiary
import TurnkeeperKit
import Foundation

/// A shared character's identity, read from its sheet page: Demiplane's server embeds the character there for
/// anyone allowed to view it.
extension DemiplaneClient {
    /// The character's name, level, game and avatar from its sheet page; nil when the page doesn't include it
    /// (the character isn't shared, or the page has changed).
    public func sharedCharacter(id: String, game: Game) async throws -> DemiplaneCharacter? {
        let url = DemiplaneReference(id: id, game: game).sheetURL(defaultGame: game)
        let request = URLRequest(url: url, cachePolicy: Self.uncached)
        let (data, response) = try await transport.send(request)
        guard response.statusCode == 200, let html = String(data: data, encoding: .utf8) else { return nil }
        return Self.sharedCharacter(id: id, inPage: html)
    }

    /// Reads the `characterSheetContent.character` record the page embeds in its (string-escaped) React data.
    static func sharedCharacter(id: String, inPage html: String) -> DemiplaneCharacter? {
        guard let start = html.range(of: #"\"characterSheetContent\":{\"character\":{"#) else { return nil }
        // The character's own fields come before its large "data" field.
        let record = String(html[start.upperBound...].prefix(4000))
            .replacingOccurrences(of: #"\""#, with: "\"").replacingOccurrences(of: #"\\"#, with: #"\"#)
        guard field("uuid", in: record) == id else { return nil }
        return DemiplaneCharacter(
            id: id, name: field("name", in: record) ?? "",
            level: field("level", in: record).flatMap(Int.init) ?? 0,
            game: field("nexus_id", in: record).flatMap(game(nexusID:)),
            avatarURL: field("avatar_url", in: record).flatMap { $0.isEmpty ? nil : URL(string: $0) }
        )
    }

    /// Demiplane's nexus IDs: 1 is Pathfinder 2e, 100 is Starfinder 2e.
    static func game(nexusID: String) -> Game? {
        switch nexusID {
        case "1": return .pathfinder
        case "100": return .starfinder
        default: return nil
        }
    }

    /// The first value of `"name":` in the record: a string (decoded) or a bare number; nil for null.
    private static func field(_ name: String, in record: String) -> String? {
        let pattern = #"""
            "\#(name)":(?:"((?:[^"\\]|\\.)*)"|(-?\d+))
            """#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: record, range: NSRange(record.startIndex..., in: record))
        else { return nil }
        if let number = Range(match.range(at: 2), in: record) { return String(record[number]) }
        guard let text = Range(match.range(at: 1), in: record) else { return nil }
        let quoted = "\"\(record[text])\""
        return (try? JSONSerialization.jsonObject(with: Data(quoted.utf8), options: .fragmentsAllowed)) as? String
    }
}
