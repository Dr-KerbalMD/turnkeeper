import Foundation

/// Sends HTTP requests: `URLSession` in the app, canned responses in tests.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPTransport {
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CharacterImportError.unexpectedResponse(operation: "Contacting Demiplane", detail: "not HTTP")
        }
        return (data, http)
    }
}

/// A signed-in Demiplane web session: the cookies its web pages send, as a `Cookie` header value.
public struct DemiplaneSession: Sendable, Equatable {
    public var cookieHeader: String

    public init(cookieHeader: String) {
        self.cookieHeader = cookieHeader
    }

    /// The session from a web view's cookies, or nil when it isn't signed in (no `access_token` cookie).
    public init?(cookies: [HTTPCookie]) {
        let demiplane = cookies.filter { $0.domain.hasSuffix("demiplane.com") }
        guard demiplane.contains(where: { $0.name == "access_token" && !$0.value.isEmpty }) else { return nil }
        self.init(cookieHeader: demiplane.map { "\($0.name)=\($0.value)" }.joined(separator: "; "))
    }
}
