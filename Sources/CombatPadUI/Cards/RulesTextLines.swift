import CombatPadKit
import Foundation

/// Rules text as card lines, with checks and damage adjusted by a presenter's template and conditions.
struct RulesTextLines {
    let presenter: StatBlockPresenter

    /// Paragraphs as indented lines; horizontal rules become breaks between lines.
    func lines(_ text: RulesText, isLimited: Bool) -> [CardLine] {
        text.paragraphs.compactMap { paragraph in
            guard case let .runs(runs) = paragraph else { return nil }
            return CardLine(runs.flatMap { segments(for: $0, isLimited: isLimited) }, isIndented: true)
        }
    }

    func segments(for run: RulesRun, isLimited: Bool) -> [CardSegment] {
        switch run {
        case let .text(string, .plain): return [.text(string)]
        case let .text(string, .bold): return [.bold(string)]
        case let .text(string, .italic): return [.italic(string)]
        case let .link(label, target, emphasis): return [.link(label, target: target, emphasis: emphasis)]
        case let .actions(cost): return [.actions(cost)]
        case let .check(check):
            let save = check.statistic == "flat" ? "flat check" : check.statistic.capitalized
            return [.text("DC "), .value(presenter.check(check), signed: false),
                    .text(" \(check.isBasic ? "basic " : "")\(save)")]
        case let .damage(parts):
            let damage = presenter.damage(parts, isLimited: isLimited).map { [CardSegment.damage($0)] }
            return CardSegment.joined(damage, separator: " plus ")
        }
    }
}
