import Foundation
import Network

/// Sends and receives framed `NearbyMessage`s over one connection.
final class MessageChannel: @unchecked Sendable {
    private let connection: NWConnection
    private let queue: DispatchQueue
    /// Bytes received but not yet read as a message. Only touched on `queue`.
    private var buffer = Data()

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    func open() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = Once()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: once.run { continuation.resume() }
                case let .failed(error), let .waiting(error):
                    once.run { continuation.resume(throwing: NearbyError.connectionFailed("\(error)")) }
                case .cancelled: once.run { continuation.resume(throwing: NearbyError.connectionFailed("cancelled")) }
                default: break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ message: NearbyMessage) async throws {
        let data = try NearbyFraming.frame(message)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: NearbyError.connectionFailed("\(error)"))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func receive() async throws -> NearbyMessage {
        while true {
            if let message = try queue.sync(execute: { try NearbyFraming.nextMessage(from: &buffer) }) {
                return message
            }
            let chunk = try await receiveChunk()
            queue.sync { buffer.append(chunk) }
        }
    }

    func close() {
        connection.cancel()
    }

    private func receiveChunk() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: NearbyError.connectionFailed("\(error)"))
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: NearbyError.connectionFailed("closed early"))
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }
}

/// Runs a block only the first time, so a continuation is resumed exactly once.
final class Once: @unchecked Sendable {
    private var hasRun = false
    private let lock = NSLock()

    func run(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasRun else { return }
        hasRun = true
        block()
    }
}
