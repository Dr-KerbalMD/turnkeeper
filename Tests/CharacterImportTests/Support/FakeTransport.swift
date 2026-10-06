import CombatPadKit
import Foundation
@testable import CharacterImport

/// Canned responses by URL path, used in order (the last one repeats), with the requests it was sent.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private var responses: [String: [(status: Int, body: Data)]] = [:]
    private(set) var requests: [URLRequest] = []
    private let lock = NSLock()

    func respond(to path: String, status: Int = 200, json: Any) {
        respond(to: path, status: status, body: (try? JSONSerialization.data(withJSONObject: json)) ?? Data())
    }

    func respond(to path: String, status: Int = 200, body: Data = Data()) {
        lock.withLock { responses[path, default: []].append((status, body)) }
    }

    func requests(to path: String) -> [URLRequest] {
        lock.withLock { requests.filter { $0.url?.path == path } }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url?.path ?? ""
        let response = lock.withLock { () -> (status: Int, body: Data)? in
            requests.append(request)
            guard var queue = responses[path], let first = queue.first else { return nil }
            if queue.count > 1 { queue.removeFirst() }
            responses[path] = queue
            return first
        }
        guard let response, let url = request.url else { throw URLError(.fileDoesNotExist) }
        return (response.body, HTTPURLResponse(url: url, statusCode: response.status, httpVersion: nil,
                                               headerFields: nil)!)
    }
}

/// A glossary that knows only Toughness and Guidance.
struct SmallGlossary: GlossarySource {
    func glossaryID(game: Game, kind: GlossaryIndex.Kind, name: String) -> String? {
        switch (kind, GlossaryIndex.normalize(name)) {
        case (.ability, "toughness"): return "pf2e.feats-srd.toughness"
        case (.spell, "guidance"): return "pf2e.spells-srd.guidance"
        default: return nil
        }
    }

    func glossaryEntry(_ id: String) -> GlossaryEntry? { nil }
}

enum TestData {
    static let characterID = "999a5a39-4e0c-4dfa-a6af-d3f47c704a87"
    static let graphQLPath = "/v1/graphql"
    static let exportPath = "/api/magic-missile"

    static func sheetPDF() throws -> Data {
        guard let url = Bundle.module.url(forResource: "ignatius", withExtension: "pdf", subdirectory: "Fixtures")
        else { throw URLError(.fileDoesNotExist) }
        return try Data(contentsOf: url)
    }

    static var character: [String: Any] { ["data": ["demiplane_user_character": [[
        "uuid": characterID, "name": "Dr Ignatius Constaline", "level": 15,
        "avatar_url": "https://example.com/avatar.png", "nexus": ["slug": "pathfinder2e"]
    ]]]] }

    static func exportDone(revision: String = "rev1") -> [String: Any] {
        ["success": true, "statusCode": 200, "message": "", "result": [
            "cacheStatus": "hit", "targetRevision": revision,
            "url": "https://content.demiplane.com/sheet.pdf?revision=\(revision)"
        ]]
    }

    /// An unsigned JWT that expires at the given time.
    static func token(expiring date: Date) -> String {
        let claims = Data(#"{"exp":\#(date.timeIntervalSince1970)}"#.utf8)
        let payload = claims.base64EncodedString().replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        return "eyJhbGciOiJub25lIn0.\(payload).signature"
    }
}
