import TurnkeeperKit
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import CharacterImport

@Suite("Demiplane references")
struct DemiplaneReferenceTests {
    private let character = "999a5a39-4e0c-4dfa-a6af-d3f47c704a87"

    @Test("A character sheet link names the character and its game")
    func sheetLink() {
        let link = "https://app.demiplane.com/nexus/pathfinder2e/character-sheet/\(character)"
        #expect(DemiplaneReference.parse(link) == DemiplaneReference(id: character, game: .pathfinder))
        let starfinder = "https://app.demiplane.com/nexus/starfinder2e/character-sheet/\(character.uppercased())?x=1"
        #expect(DemiplaneReference.parse(starfinder) == DemiplaneReference(id: character, game: .starfinder))
    }

    @Test("A bare ID, even with text around it, is a character of unknown game")
    func bareID() {
        #expect(DemiplaneReference.parse(" \(character)\n") == DemiplaneReference(id: character, game: nil))
        #expect(DemiplaneReference.parse("Kyra: \(character)") == DemiplaneReference(id: character, game: nil))
    }

    @Test("A campaign link is no reference, since campaigns aren't imported")
    func campaign() {
        let link = "https://app.demiplane.com/nexus/starfinder2e/campaigns/73aa3e65-37a9-4d36-b201-b4ed6699d01b"
        #expect(DemiplaneReference.parse(link) == nil)
    }

    @Test("Text without a UUID is no reference")
    func junk() {
        #expect(DemiplaneReference.parse("https://app.demiplane.com/nexus/pathfinder2e") == nil)
        #expect(DemiplaneReference.parse("") == nil)
    }

    @Test("Nexus slugs from links map to games")
    func nexus() {
        #expect(DemiplaneReference.game(nexus: "pathfinder2e") == .pathfinder)
        #expect(DemiplaneReference.game(nexus: "Starfinder-2e") == .starfinder)
        #expect(DemiplaneReference.game(nexus: "daggerheart") == nil)
    }

    @Test("A character sheet's QR code reads as its link")
    func qrCode() throws {
        let url = try #require(Bundle.module.url(forResource: "character-qr", withExtension: "png",
                                                 subdirectory: "Fixtures"))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(try QRCodeReader.reference(in: image) == DemiplaneReference(id: character, game: .pathfinder))
    }

    @Test("An image without a QR code has no reference")
    func noQRCode() throws {
        let context = try #require(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceGray(),
                                             bitmapInfo: CGImageAlphaInfo.none.rawValue))
        let image = try #require(context.makeImage())
        #expect(try QRCodeReader.reference(in: image) == nil)
    }
}
