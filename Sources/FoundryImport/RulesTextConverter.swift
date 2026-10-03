import CombatPadKit
import Foundation

/// Converts Foundry description HTML, enrichers included, into `RulesText`.
public struct RulesTextConverter {
    private var enrichers: EnricherConverter

    public init(localizer: Localizer) {
        enrichers = EnricherConverter(localizer: localizer)
    }

    /// Enricher names that could not be converted so far, for the import report.
    public var unparsedEnrichers: [String] { enrichers.unparsed }

    public mutating func convert(_ html: String) -> RulesText {
        guard !html.isEmpty else { return RulesText() }
        return RulesText(HTMLFlattener.markup(from: enrichers.convert(html)))
    }
}
