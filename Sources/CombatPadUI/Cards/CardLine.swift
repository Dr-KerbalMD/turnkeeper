import CombatPadKit
import SwiftUI

/// One piece of a card line.
enum CardSegment: Hashable {
    case text(String)
    case bold(String)
    case italic(String)
    /// A number that the template or conditions may have changed, shown with its sign when `signed`.
    case value(AdjustedValue, signed: Bool)
    /// Damage with its adjusted constant, such as "2d8+13 bludgeoning".
    case damage(AdjustedDamage)
    case actions(ActionCost)
}

/// A line of a battle card: segments that wrap as one paragraph, optionally indented.
struct CardLine: Hashable, Identifiable {
    var id = UUID()
    var segments: [CardSegment]
    var isIndented = false

    init(_ segments: [CardSegment], isIndented: Bool = false) {
        self.segments = segments
        self.isIndented = isIndented
    }

    /// "Label value" with a bold label, the common stat-block form.
    static func labeled(_ label: String, _ rest: [CardSegment]) -> CardLine {
        CardLine([.bold(label + " ")] + rest)
    }

    /// The values in the line that any modifier touched, even ones that cancel out, for its breakdown.
    var modifiedValues: [AdjustedValue] {
        segments.compactMap { segment in
            switch segment {
            case let .value(value, _) where !value.modifiers.isEmpty: return value
            case let .damage(damage) where !damage.bonus.modifiers.isEmpty: return damage.bonus
            default: return nil
            }
        }
    }

    /// "AC 26 → 24: off-guard −2; frightened 1 −1" for each changed value.
    var breakdown: String {
        modifiedValues.map { value in
            let parts = value.modifiers.map { "\($0.label) \(signed($0.value))" }.joined(separator: ", ")
            return "\(value.base) → \(value.value): \(parts)"
        }
        .joined(separator: "\n")
    }
}

/// A titled group of lines, such as DEFENSE on a Starfinder card.
struct CardSection: Identifiable {
    var id: String { title }
    var title: String
    /// Shown at the right of the section header, such as "HP 200".
    var trailing: [CardSegment] = []
    var lines: [CardLine]
}

func signed(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "−\(abs(value))"
}

/// Renders a line as one wrapping text, tinting changed values: red when worse, green when better.
struct CardLineView: View {
    let line: CardLine
    let style: CardTextStyle

    var body: some View {
        segments
            .font(.pad(style.body, size: style.size))
            .foregroundStyle(style.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, line.isIndented ? style.size : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(BreakdownModifier(breakdown: line.breakdown))
    }

    private var segments: Text {
        line.segments.reduce(Text("")) { text, segment in Text("\(text)\(render(segment))") }
    }

    private func render(_ segment: CardSegment) -> Text {
        switch segment {
        case let .text(string): return Text(string)
        case let .bold(string): return Text(string).font(.pad(style.bold, size: style.size))
        case let .italic(string): return Text(string).font(.pad(style.italic, size: style.size))
        case let .value(value, isSigned): return tinted(isSigned ? signed(value.value) : "\(value.value)", value)
        case let .damage(damage): return Text("\(tinted(damage.formula, damage.bonus))\(typeSuffix(damage.part))")
        case let .actions(cost): return ActionGlyph.text(cost, size: style.size, color: style.ink)
        }
    }

    private func tinted(_ string: String, _ value: AdjustedValue) -> Text {
        guard value.isChanged else { return Text(string) }
        return Text(string).foregroundColor(value.change < 0 ? style.worse : style.better).bold()
    }

    private func typeSuffix(_ part: DamagePart) -> String {
        let persistent = part.isPersistent && !part.type.contains("bleed") ? "persistent " : ""
        return part.type.isEmpty ? "" : " \(persistent)\(part.type)"
    }
}

/// Fonts and colors for card text.
struct CardTextStyle {
    var body: String
    var bold: String
    var italic: String
    var size: CGFloat
    var ink: Color
    var worse: Color
    var better: Color
}

/// Shows a line's breakdown on hover (Mac) and long-press (iPad) when any of its numbers changed.
private struct BreakdownModifier: ViewModifier {
    let breakdown: String

    func body(content: Content) -> some View {
        if breakdown.isEmpty {
            content
        } else {
            content
                .help(breakdown)
                .contextMenu { Text(breakdown) }
        }
    }
}

/// Action glyphs in the Pathfinder action font, falling back to symbols if the font is missing.
enum ActionGlyph {
    private static let characters: [ActionCost: String] = [
        .one: "1", .two: "2", .three: "3", .free: "F", .reaction: "R"
    ]

    static func text(_ cost: ActionCost, size: CGFloat, color: Color) -> Text {
        guard let character = characters[cost] else { return Text("") }
        return Text(character).font(.custom(FontName.actions, size: size * 1.1)).foregroundColor(color)
    }
}
