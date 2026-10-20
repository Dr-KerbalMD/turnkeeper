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
