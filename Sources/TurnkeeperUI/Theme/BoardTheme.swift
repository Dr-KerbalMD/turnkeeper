import BattleCards
import Bestiary
import TurnkeeperKit
import SwiftUI

/// The look of the board and battle cards for a game: Pathfinder parchment, or Starfinder holo-panels.
struct BoardTheme: Equatable, Sendable {
    var game: Game
    var background: Color
    var surface: Color
    var ink: Color
    var secondaryInk: Color
    var accent: Color
    var rule: Color
    var titleFont: String
    var bodyFont: String

    static func forGame(_ game: Game) -> BoardTheme {
        game == .starfinder ? .starfinder : .pathfinder
    }

    static let pathfinder = BoardTheme(
        game: .pathfinder,
        background: Color(hex: 0x2B1F17),
        surface: Color(hex: 0xF1E5C8),
        ink: Color(hex: 0x231A12),
        secondaryInk: Color(hex: 0x5C4A38),
        accent: Color(hex: 0x6B1A12),
        rule: Color(hex: 0x6B1A12),
        titleFont: FontName.condensedBold,
        bodyFont: FontName.condensed
    )

    static let starfinder = BoardTheme(
        game: .starfinder,
        background: Color(hex: 0x030B14),
        surface: Color(hex: 0x0D3C47),
        ink: Color(hex: 0xEAF7FB),
        secondaryInk: Color(hex: 0x9FC7D2),
        accent: Color(hex: 0x27C8F2),
        rule: Color(hex: 0x27C8F2),
        titleFont: FontName.condensedBold,
        bodyFont: FontName.body
    )

    var isDark: Bool { game == .starfinder }
}

/// The magnets' colors.
extension Magnet {
    var color: Color {
        switch self {
        case .red: return Color(hex: 0xB3261E)
        case .blue: return Color(hex: 0x1F5FAF)
        case .green: return Color(hex: 0x2E7D32)
        case .gray: return Color(hex: 0x6B6B6B)
        }
    }
}

/// The border on a weak or elite creature's strip, so separate stacks of one creature stand apart.
extension CreatureTemplate {
    var borderColor: Color? {
        switch self {
        case .elite: return Color(hex: 0xE040FB)
        case .weak: return Color(hex: 0x80DEEA)
        case .normal: return nil
        }
    }
}

private struct BoardThemeKey: EnvironmentKey {
    static let defaultValue = BoardTheme.pathfinder
}

extension EnvironmentValues {
    var boardTheme: BoardTheme {
        get { self[BoardThemeKey.self] }
        set { self[BoardThemeKey.self] = newValue }
    }
}
