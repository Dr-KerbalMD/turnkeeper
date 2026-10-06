import Foundation

/// Looks up `@Localize[PF2E.Some.Key]` keys in the system's language files.
public struct Localizer: Sendable {
    private let roots: [JSONValue]

    public init(roots: [JSONValue]) {
        self.roots = roots
    }

    /// Loads every English language file in `<pf2e repo>/static/lang`.
    public init(languageDirectory: URL) throws {
        let files = try FileManager.default.contentsOfDirectory(at: languageDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasSuffix("en.json") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        roots = try files.map(JSONValue.init(contentsOf:))
    }

    /// A localizer that looks in `roots` before these files.
    public func preferring(_ roots: [JSONValue]) -> Localizer {
        Localizer(roots: roots + self.roots)
    }

    public func text(for key: String) -> String? {
        for root in roots {
            let value = root[path: key]
            if case let .string(text) = value { return text }
        }
        return nil
    }
}
