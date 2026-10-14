import AppNotices
import Foundation

extension AboutInfo {
    /// Turnkeeper's About screen. The credits match the README's Paizo notices.
    static let turnkeeper = AboutInfo(
        appName: "Turnkeeper",
        tagline: "An unofficial, free encounter builder and initiative tracker for Pathfinder and Starfinder.",
        credits: [
            "Creature and rules text comes from the pf2e system for Foundry VTT and is used under the ORC License "
                + "and the Open Game License 1.0a.",
            "The battle cards' parchment, frames and panels are Rexard game dev assets, used under license.",
            "The action icons are Paizo's Pathfinder-Icons font, used unaltered under the Paizo Compatibility "
                + "License."
        ],
        // A literal URL that is known to parse. The repository is private, so this is the author's profile.
        // swiftlint:disable:next force_unwrapping
        contactURL: URL(string: "https://github.com/scooper4711")!
    )
}
