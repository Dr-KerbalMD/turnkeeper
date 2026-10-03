import Foundation

/// Messages between two devices syncing over the local network.
///
/// The joining device sends `hello` with the code shown on the host and its library. The host checks the
/// code and replies with its own library, or refuses. Both then merge what they received, so both end up
/// with the same records.
public enum NearbyMessage: Codable, Sendable {
    case hello(code: String, package: LibraryPackage)
    case reply(package: LibraryPackage)
    case refused(reason: String)
}

/// Splits a TCP byte stream into messages: each is a 4-byte big-endian length followed by JSON.
public enum NearbyFraming {
    /// Messages larger than this are refused, so a bad peer can't make us allocate without limit.
    public static let maximumLength = 64 * 1024 * 1024

    public static func frame(_ message: NearbyMessage) throws -> Data {
        let body = try JSONEncoder().encode(message)
        var length = UInt32(body.count).bigEndian
        return Data(bytes: &length, count: 4) + body
    }

    /// Takes one complete message off the front of `buffer`, or returns nil if it hasn't all arrived yet.
    public static func nextMessage(from buffer: inout Data) throws -> NearbyMessage? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.prefix(4).reduce(0) { $0 << 8 | Int($1) }
        guard length <= maximumLength else { throw NearbyError.messageTooLarge(length) }
        guard buffer.count >= 4 + length else { return nil }
        let body = buffer.dropFirst(4).prefix(length)
        buffer = Data(buffer.dropFirst(4 + length))
        return try JSONDecoder().decode(NearbyMessage.self, from: Data(body))
    }
}

/// A 4-digit code shown on the host and typed on the joining device.
public enum PairingCode {
    public static func make<Generator: RandomNumberGenerator>(using generator: inout Generator) -> String {
        String(format: "%04d", Int.random(in: 0...9999, using: &generator))
    }

    public static func matches(_ entered: String, _ expected: String) -> Bool {
        entered.filter(\.isNumber) == expected
    }
}

public enum NearbyError: Error, LocalizedError, Equatable {
    case messageTooLarge(Int)
    case refused(String)
    case connectionFailed(String)
    case unexpectedMessage

    public var errorDescription: String? {
        switch self {
        case let .messageTooLarge(length): return "Syncing failed: the other device sent \(length) bytes at once."
        case let .refused(reason): return "Syncing failed: \(reason)"
        case let .connectionFailed(reason): return "Syncing failed: the connection broke (\(reason))."
        case .unexpectedMessage: return "Syncing failed: the other device sent something unexpected."
        }
    }
}
