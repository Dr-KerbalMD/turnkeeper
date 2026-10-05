import CombatPadKit
import Foundation

/// A character as Demiplane's GraphQL API describes it: identity only, no computed statistics.
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

/// Talks to Demiplane: the GraphQL API with the bearer token, and the web app's own endpoints with the
/// signed-in session's cookies. Undocumented; see `docs/specs/combat-pad/design.md`.
public struct DemiplaneClient: Sendable {
    public var transport: any HTTPTransport
    public var token: String?
    public var session: DemiplaneSession?
    /// How long to wait between asking whether an export is ready, and how many times to ask.
    public var pollInterval: Duration = .seconds(2)
    public var maximumPolls = 45
    public var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }

    static let graphQLURL = URL(string: "https://apiv4.demiplane.com/v1/graphql")!
    static let appURL = URL(string: "https://app.demiplane.com")!

    public init(transport: any HTTPTransport, token: String?, session: DemiplaneSession?) {
        self.transport = transport
        self.token = token
        self.session = session
    }

    /// The character's name, level, game and avatar.
    public func character(id: String) async throws -> DemiplaneCharacter {
        let operation = "Looking up the Demiplane character"
        let query = """
            query character($id: uuid!) { demiplane_user_character(where: {uuid: {_eq: $id}, \
            deleted_at: {_is_null: true}}) { uuid name level avatar_url nexus { slug } } }
            """
        let body: [String: Any] = ["query": query, "variables": ["id": id]]
        var request = URLRequest(url: Self.graphQLURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let json = try await jsonObject(request, operation: operation)
        try Self.checkGraphQLErrors(json, operation: operation)
        let rows = ((json["data"] as? [String: Any])?["demiplane_user_character"] as? [[String: Any]]) ?? []
        guard let row = rows.first else { throw CharacterImportError.notFound(operation: operation, id: id) }
        let nexus = (row["nexus"] as? [String: Any])?["slug"] as? String ?? ""
        return DemiplaneCharacter(
            id: id, name: row["name"] as? String ?? "", level: row["level"] as? Int ?? 0,
            game: DemiplaneReference.game(nexus: nexus),
            avatarURL: (row["avatar_url"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
        )
    }

    /// The sheet PDF at a URL from `exportSheet`, or `publicSheetURL` when there is no session.
    public func sheetPDF(at url: URL) async throws -> Data {
        let (data, response) = try await transport.send(URLRequest(url: url))
        switch response.statusCode {
        case 200: return data
        case 403, 404: throw CharacterImportError.notExported(operation: "Downloading the character sheet")
        default: throw CharacterImportError.rejected(operation: "Downloading the character sheet",
                                                     status: response.statusCode, message: "")
        }
    }

    /// Where an already exported sheet lives, for importing without a session.
    public static func publicSheetURL(id: String, game: Game) -> URL {
        let slug = game == .starfinder ? "starfinder-2e" : "pathfinder-2e"
        return URL(string: "https://content.demiplane.com/nexus/\(slug)/character/pdf/v2/user/\(id)/default.pdf")!
    }

    func jsonObject(_ request: URLRequest, operation: String) async throws -> [String: Any] {
        let (data, response) = try await transport.send(request)
        if response.statusCode == 401 { throw CharacterImportError.tokenExpired(operation: operation) }
        guard (200..<300).contains(response.statusCode) else {
            throw CharacterImportError.rejected(operation: operation, status: response.statusCode,
                                                message: String(data: data.prefix(200), encoding: .utf8) ?? "")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CharacterImportError.unexpectedResponse(operation: operation, detail: "not a JSON object")
        }
        return json
    }

    /// GraphQL reports errors in the body; an expired or rejected token reads "JWT" or "could not verify".
    static func checkGraphQLErrors(_ json: [String: Any], operation: String) throws {
        guard let errors = json["errors"] as? [[String: Any]], let first = errors.first else { return }
        let message = first["message"] as? String ?? ""
        let lowered = message.lowercased()
        if lowered.contains("jwt") || lowered.contains("could not verify") {
            throw CharacterImportError.tokenExpired(operation: operation)
        }
        throw CharacterImportError.rejected(operation: operation, status: 200, message: message)
    }
}
