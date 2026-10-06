import Foundation

/// The Demiplane GraphQL token: a JWT, pasted by the GM or renewed from the web session.
public enum DemiplaneToken {
    /// The token without a leading "Bearer " or surrounding whitespace.
    public static func normalized(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.lowercased().hasPrefix("bearer ") ? String(trimmed.dropFirst(7)) : trimmed
    }

    /// When the token expires, from its `exp` claim; nil when it isn't a readable JWT.
    public static func expiry(of token: String) -> Date? {
        let parts = normalized(token).split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let claims = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let seconds = claims["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    public static func isExpired(_ token: String, at date: Date = Date()) -> Bool {
        expiry(of: token).map { $0 <= date } ?? false
    }
}
