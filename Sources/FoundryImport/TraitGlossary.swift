import CombatPadKit
import Foundation

/// Trait descriptions from the system's language files. The localization key comes from
/// `traitDescriptions` in `src/scripts/config/traits.ts`, else `PF2E.TraitDescription<Slug>`. A trait with a
/// value, such as `reach-10` or `deadly-d10`, uses the description of `reach` or `deadly`.
struct TraitGlossary {
    /// Slug → localization key, from `traits.ts`.
    private let descriptionKeys: [String: String]
    private let localizers: [Game: Localizer]

    init(descriptionKeys: [String: String] = [:], localizers: [Game: Localizer] = [:]) {
        self.descriptionKeys = descriptionKeys
        self.localizers = localizers
    }

    /// Reads `traits.ts` from the repository. Starfinder prefers `sf2e-overrides-en.json`.
    init(repository: URL, localizer: Localizer) {
        let config = repository.appendingPathComponent("src/scripts/config/traits.ts")
        let source = (try? String(contentsOf: config, encoding: .utf8)) ?? ""
        let overrides = repository.appendingPathComponent("static/lang/sf2e-overrides-en.json")
        let starfinder = (try? JSONValue(contentsOf: overrides)).map { localizer.preferring([$0]) } ?? localizer
        self.init(descriptionKeys: Self.descriptionKeys(in: source),
                  localizers: [.pathfinder: localizer, .starfinder: starfinder])
    }

    /// The slug that has a description: the trait itself, or the trait without its trailing values.
    func describedSlug(_ slug: String, game: Game) -> String? {
        var words = slug.split(separator: "-").map(String.init)
        while !words.isEmpty {
            let candidate = words.joined(separator: "-")
            if description(ofExactly: candidate, game: game) != nil { return candidate }
            words.removeLast()
        }
        return nil
    }

    /// The description HTML of a trait that `describedSlug` returned.
    func description(of slug: String, game: Game) -> String {
        description(ofExactly: slug, game: game) ?? ""
    }

    private func description(ofExactly slug: String, game: Game) -> String? {
        guard !slug.isEmpty, slug.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return nil }
        let key = descriptionKeys[slug] ?? "PF2E.TraitDescription" + Self.pascalCase(slug)
        let text = localizers[game]?.text(for: key) ?? ""
        return text.isEmpty ? nil : text
    }

    private static func pascalCase(_ slug: String) -> String {
        slug.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// The `slug: "PF2E.Key"` pairs of every `const …Descriptions = { … };` object.
    static func descriptionKeys(in source: String) -> [String: String] {
        let block = /const \w+Descriptions\b[^=]*= \{(?<body>[^}]*)\}/
        let pair = /^\s*"?(?<slug>[\w-]+)"?:\s*"(?<key>[\w.]+)",?\s*$/.anchorsMatchLineEndings()
        var keys: [String: String] = [:]
        for match in source.matches(of: block) {
            for entry in match.output.body.matches(of: pair) {
                keys[String(entry.output.slug)] = String(entry.output.key)
            }
        }
        return keys
    }
}
