import CoreText
import Foundation
import SwiftUI

/// PostScript names of the fonts converted into `Generated/Fonts` by the import.
enum FontName {
    static let condensed = "RobotoCondensed-Regular"
    static let condensedBold = "RobotoCondensed-Bold"
    static let condensedItalic = "RobotoCondensed-Italic"
    static let body = "Roboto-Regular"
    static let bodyBold = "Roboto-Bold"
    static let bodyItalic = "Roboto-Italic"
    static let actions = "Pathfinder2eActions"
}

enum Fonts {
    /// Registers every font in `Generated/Fonts` for this process. Missing fonts fall back to the system font.
    static func register(from generatedDirectory: URL?) {
        guard let folder = generatedDirectory?.appendingPathComponent("Fonts"),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return }
        for file in files where file.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// A custom font that scales with Dynamic Type relative to the body style.
    static func pad(_ name: String, size: CGFloat) -> Font {
        .custom(name, size: size, relativeTo: .body)
    }
}
