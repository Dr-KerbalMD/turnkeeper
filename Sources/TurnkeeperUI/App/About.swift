import AppNotices
import Bestiary
import Foundation

extension AboutInfo {
    /// Turnkeeper's About screen, with the licenses the import copied into `Generated/Licenses`.
    static var turnkeeper: AboutInfo {
        guard let generated = BestiaryStore.locateGeneratedDirectory() else { return turnkeeperNotices }
        return turnkeeperNotices.licensed(by: generated.appendingPathComponent("Licenses"))
    }

    /// The notices and credits, which match the README's Paizo notices.
    private static let turnkeeperNotices = AboutInfo(
        appName: "Turnkeeper",
        tagline: "An unofficial, free encounter builder and initiative tracker for Pathfinder and Starfinder.",
        credits: [
            "Creature and rules text comes from the pf2e system for Foundry VTT and is used under the ORC License "
                + "and the Open Game License 1.0a.",
            "The battle cards' parchment, frames and panels are Rexard game dev assets, used under license.",
            "The action icons are Paizo's Pathfinder-Icons font, used unaltered under the Paizo Compatibility "
                + "License.",
            "The Roboto and Roboto Condensed fonts are by Google, used under the Apache License 2.0.",
            "The condition icons are from game-icons.net, by DarkZaitzev, Delapouite, Lorc, Sbed, Skoll and "
                + "Zeromancer, used under the Creative Commons Attribution 3.0 license."
        ],
        // A literal URL that is known to parse.
        // swiftlint:disable:next force_unwrapping
        contactURL: URL(string: "https://github.com/scooper4711/turnkeeper/issues")!
    )
}
