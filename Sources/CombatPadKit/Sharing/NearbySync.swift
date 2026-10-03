import Foundation
import Network

/// The Bonjour service type the app advertises and browses for.
public let nearbyServiceType = "_combatpad._tcp"

/// Advertises this device so another can sync with it, and answers each device that joins with the right code.
public final class NearbyHost: @unchecked Sendable {
    public let code: String
    private let listener: NWListener
    private let queue = DispatchQueue(label: "combatpad.nearby.host")
    /// Merges what a joining device sent and returns this device's library to send back.
    private let respond: @Sendable (LibraryPackage) async -> LibraryPackage

    /// - Parameters:
    ///   - name: The name other devices see, or nil to listen without advertising (for tests).
    ///   - code: The pairing code the joining device must enter.
    ///   - respond: Merges an incoming library and returns this device's library.
    public init(name: String?, code: String, respond: @escaping @Sendable (LibraryPackage) async -> LibraryPackage)
        throws {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        listener = try NWListener(using: parameters)
        if let name { listener.service = NWListener.Service(name: name, type: nearbyServiceType) }
        self.code = code
        self.respond = respond
    }

    /// Starts listening and returns the port once ready.
    public func start() async throws -> NWEndpoint.Port {
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            Task { await self.answer(MessageChannel(connection: connection, queue: self.queue)) }
        }
        return try await withCheckedThrowingContinuation { continuation in
            let once = Once()
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready: once.run { continuation.resume(returning: listener.port ?? 0) }
                case let .failed(error):
                    once.run { continuation.resume(throwing: NearbyError.connectionFailed("\(error)")) }
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }

    public func stop() {
        listener.cancel()
    }

    private func answer(_ channel: MessageChannel) async {
        defer { channel.close() }
        do {
            try await channel.open()
            guard case let .hello(entered, package) = try await channel.receive() else { return }
            guard PairingCode.matches(entered, code) else {
                try await channel.send(.refused(reason: "the code doesn't match the one shown on the other device."))
                return
            }
            try await channel.send(.reply(package: await respond(package)))
        } catch {
            return
        }
    }
}

/// A device advertising for sync.
public struct NearbyPeer: Identifiable, Hashable, Sendable {
    public var name: String
    public var endpoint: NWEndpoint

    public var id: String { name }
}

/// Finds devices advertising for sync.
public final class NearbyBrowser: @unchecked Sendable {
    private let browser = NWBrowser(for: .bonjour(type: nearbyServiceType, domain: nil), using: .tcp)
    private let queue = DispatchQueue(label: "combatpad.nearby.browser")

    public init() {}

    /// Starts browsing; `update` is called with the current peers whenever they change.
    public func start(update: @escaping @Sendable ([NearbyPeer]) -> Void) {
        browser.browseResultsChangedHandler = { results, _ in
            let peers = results.compactMap { result -> NearbyPeer? in
                guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                return NearbyPeer(name: name, endpoint: result.endpoint)
            }
            update(peers.sorted { $0.name < $1.name })
        }
        browser.start(queue: queue)
    }

    public func stop() {
        browser.cancel()
    }
}

/// Joins a host: sends this device's library with the code and returns the host's library.
public enum NearbyClient {
    public static func sync(with endpoint: NWEndpoint, code: String, package: LibraryPackage) async throws
        -> LibraryPackage {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let channel = MessageChannel(connection: NWConnection(to: endpoint, using: parameters),
                                     queue: DispatchQueue(label: "combatpad.nearby.client"))
        defer { channel.close() }
        try await channel.open()
        try await channel.send(.hello(code: code, package: package))
        switch try await channel.receive() {
        case let .reply(reply): return reply
        case let .refused(reason): throw NearbyError.refused(reason)
        case .hello: throw NearbyError.unexpectedMessage
        }
    }
}
