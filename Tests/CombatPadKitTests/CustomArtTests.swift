import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CombatPadKit

@Suite("Pasted artwork")
struct CustomArtTests {
    /// A store in a fresh temporary folder.
    private func temporaryStore() -> ArtStore {
        ArtStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("CombatPadArtTests-\(UUID().uuidString)", isDirectory: true))
    }

    /// A solid image of the given size, encoded as PNG, opaque or with transparency.
    private func image(width: Int, height: Int, opaque: Bool = true) throws -> Data {
        let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: alpha.rawValue))
        context.setFillColor(CGColor(red: 0.8, green: 0.1, blue: 0.1, alpha: opaque ? 1 : 0.5))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString,
                                                                        1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    @Test("Images are capped at 2048 px, as JPEG unless they have transparency")
    func preparing() throws {
        let large = try PreparedImage(try image(width: 4096, height: 1024))
        #expect(large.pixelSize == CGSize(width: 2048, height: 512) && large.fileExtension == "jpg")
        let clear = try PreparedImage(try image(width: 64, height: 64, opaque: false))
        #expect(clear.fileExtension == "png" && clear.pixelSize.width == 64)
        #expect(throws: ArtStoreError.unreadableImage) { try PreparedImage(Data("not an image".utf8)) }
    }

    @Test("The store writes, finds and sweeps files")
    func store() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let kept = try store.add(try image(width: 10, height: 10), for: "pf2e.monster-core.goblin")
        let stale = try store.add(try image(width: 10, height: 10), for: "pf2e.monster-core.goblin")
        #expect(kept.fileName.hasSuffix(".jpg") && kept.fileName != stale.fileName && kept.byteCount > 0)
        #expect(store.contains(kept.fileName) && store.contains(stale.fileName))
        store.sweep(keeping: [kept.fileName])
        #expect(store.contains(kept.fileName) && !store.contains(stale.fileName))
    }

    @Test("New art replaces the old, and the library never holds the image")
    func library() throws {
        var library = Library()
        let first = CustomArt(subject: "goblin", fileName: "a.jpg", byteCount: 3)
        library.save(first)
        library.save(CustomArt(subject: "goblin", fileName: "b.jpg", byteCount: 3))
        #expect(library.customArt(for: "goblin")?.fileName == "b.jpg")
        #expect(library.liveImageFileNames == ["b.jpg"])
        library.deleteCustomArt(for: "goblin")
        #expect(library.customArt(for: "goblin") == nil && library.liveImageFileNames.isEmpty)
        let json = try #require(String(bytes: try JSONEncoder().encode(library), encoding: .utf8))
        #expect(json.contains("a.jpg") && !json.contains("images"))
    }

    @Test("A campaign package carries its creatures' art and the image bytes")
    func package() throws {
        let store = temporaryStore()
        let received = temporaryStore()
        defer {
            try? FileManager.default.removeItem(at: store.directory)
            try? FileManager.default.removeItem(at: received.directory)
        }
        var library = Library()
        let campaign = Campaign(name: "Season 7", game: .pathfinder)
        let scenario = Scenario(campaignID: campaign.id, name: "#7-03")
        var encounter = Encounter(scenarioID: scenario.id, name: "Docks")
        var variant = encounter.variant(scenario.variantLabels[0])
        variant.slots = [EncounterSlot(creatureKey: "goblin")]
        encounter.setVariant(variant)
        library.save(campaign)
        library.save(scenario)
        library.save(encounter)
        library.save(try store.add(try image(width: 8, height: 8), for: "goblin"))
        library.save(try store.add(try image(width: 8, height: 8), for: "dragon"))

        let package = LibraryPackage.campaign(campaign.id, from: library, bestiaryRevision: "")
            .addingImages(from: store)
        #expect(package.library.customArt.map(\.subject) == ["goblin"])
        let decoded = try LibraryPackage.decode(package.encoded())
        #expect(decoded.images.keys.sorted() == package.library.liveImageFileNames.sorted())
        try decoded.writeImages(to: received)
        #expect(received.contains(try #require(decoded.library.customArt(for: "goblin")).fileName))
    }
}

@Suite("Handouts")
struct HandoutTests {
    @Test("Handouts belong to a scenario, keep their image file live, and go with it")
    func handouts() {
        var library = Library()
        let campaign = Campaign(name: "Season 7", game: .pathfinder)
        let scenario = Scenario(campaignID: campaign.id, name: "#7-03")
        library.save(campaign)
        library.save(scenario)
        var map = Handout(scenarioID: scenario.id, name: "Map of the Docks")
        #expect(!map.hasImage && map.imagePath.isEmpty)
        map.fileName = "map.jpg"
        library.save(map)
        library.save(Handout(scenarioID: scenario.id, name: "A Letter"))
        #expect(library.handouts(in: scenario.id).map(\.name) == ["A Letter", "Map of the Docks"])
        #expect(library.liveImageFileNames == ["map.jpg"] && map.imagePath == "Pasted/map.jpg")
        let package = LibraryPackage.campaign(campaign.id, from: library, bestiaryRevision: "")
        #expect(package.library.handouts.count == 2)
        library.deleteScenario(scenario.id)
        #expect(library.handouts(in: scenario.id).isEmpty && library.liveImageFileNames.isEmpty)
    }
}
