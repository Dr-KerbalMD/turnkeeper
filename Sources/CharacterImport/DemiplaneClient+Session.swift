import CombatPadKit
import Foundation

/// A Demiplane campaign: its name and the IDs of its characters.
public struct DemiplaneCampaign: Sendable, Equatable {
    public var name: String
    public var characterIDs: [String]
}

/// The web app's endpoints, which need the signed-in session's cookies.
extension DemiplaneClient {
    /// Asks Demiplane to export the sheet PDF, waiting while it is built. Comes back at once when the
    /// character hasn't changed since the last export.
    public func exportSheet(id: String) async throws -> SheetExport {
        let operation = "Exporting the character sheet"
        let body: [String: Any] = [
            "functionName": "GENERATE_CHARACTER_PDF_LAMBDA_NAME",
            "payload": ["id": id, "isPregen": false, "templateName": "default"]
        ]
        var request = try sessionRequest(path: "/api/magic-missile", operation: operation)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        for _ in 0..<maximumPolls {
            let (data, response) = try await transport.send(request)
            switch response.statusCode {
            case 202: try await sleep(pollInterval)
            case 200: return try Self.sheetExport(data, operation: operation)
            case 401, 403: throw CharacterImportError.signInNeeded(operation: operation)
            default: throw CharacterImportError.rejected(operation: operation, status: response.statusCode, message: "")
            }
        }
        throw CharacterImportError.timedOut(operation: operation)
    }

    /// The campaign's name and its characters' IDs. Demiplane looks the campaign up in the game named by the
    /// page it is asked from (`Client-Pathname`), so a Starfinder campaign asked as Pathfinder is "not found".
    public func campaign(id: String, game: Game) async throws -> DemiplaneCampaign {
        let operation = "Reading the Demiplane campaign"
        var components = URLComponents(string: Self.appURL.absoluteString + "/api/getCampaign")!
        components.queryItems = [URLQueryItem(name: "campaignUuid", value: id)]
        var request = try sessionRequest(path: "/api/getCampaign", operation: operation)
        request.url = components.url
        request.setValue("/nexus/\(DemiplaneReference.nexusSlug(for: game))/campaigns/\(id)",
                         forHTTPHeaderField: "Client-Pathname")
        let json = try await signedInJSON(request, operation: operation)
        guard let response = json["campaignResponse"] as? [String: Any] else {
            throw CharacterImportError.notFound(operation: operation, id: id)
        }
        let name = (response["campaign"] as? [String: Any])?["name"] as? String ?? ""
        let characters = response["campaignUserCharacters"] as? [Any] ?? []
        var seen = Set<String>()
        let ids = characters.compactMap(Self.uuid(in:)).filter { seen.insert($0).inserted }
        return DemiplaneCampaign(name: name, characterIDs: ids)
    }

    /// A fresh GraphQL token from the session, as Demiplane's own pages get one.
    public func graphQLToken() async throws -> String {
        let operation = "Renewing the Demiplane token"
        let auth = try await signedInJSON(try sessionRequest(path: "/api/auth/token", operation: operation),
                                          operation: operation)
        guard let accessToken = auth["accessToken"] as? String, !accessToken.isEmpty else {
            throw CharacterImportError.signInNeeded(operation: operation)
        }
        var request = try sessionRequest(path: "/api/generate-graphql-token", operation: operation)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let json = try await signedInJSON(request, operation: operation)
        guard let token = (json["data"] as? [String: Any])?["token"] as? String, !token.isEmpty else {
            throw CharacterImportError.unexpectedResponse(operation: operation, detail: "no token")
        }
        return token
    }

    private func sessionRequest(path: String, operation: String) throws -> URLRequest {
        guard let session else { throw CharacterImportError.signInNeeded(operation: operation) }
        var request = URLRequest(url: Self.appURL.appendingPathComponent(path))
        request.setValue(session.cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue(Self.appURL.absoluteString, forHTTPHeaderField: "Origin")
        request.setValue(Self.appURL.absoluteString + "/", forHTTPHeaderField: "Referer")
        return request
    }

    /// Like `jsonObject`, but a 401 means the session has ended rather than the token.
    private func signedInJSON(_ request: URLRequest, operation: String) async throws -> [String: Any] {
        do {
            return try await jsonObject(request, operation: operation)
        } catch CharacterImportError.tokenExpired {
            throw CharacterImportError.signInNeeded(operation: operation)
        }
    }

    static func sheetExport(_ data: Data, operation: String) throws -> SheetExport {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let result = json["result"] as? [String: Any] ?? [:]
        guard let link = result["url"] as? String, let url = URL(string: link) else {
            throw CharacterImportError.unexpectedResponse(operation: operation, detail: "no PDF link")
        }
        return SheetExport(url: url, revision: result["targetRevision"] as? String ?? "")
    }

    /// The character UUID in a campaign character entry: its own `uuid`, or that of the character it holds.
    static func uuid(in value: Any) -> String? {
        guard let object = value as? [String: Any] else { return nil }
        for key in ["user_character", "userCharacter", "character"] {
            if let uuid = object[key].flatMap(uuid(in:)) { return uuid }
        }
        return object["uuid"] as? String
    }
}
