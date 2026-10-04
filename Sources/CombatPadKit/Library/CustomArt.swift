import Foundation

/// Art pasted in for a creature, shown everywhere in place of the bundled art. The library only points to
/// the image; the file lives in the `ArtStore`, and packages carry its bytes alongside the library.
public struct CustomArt: LibraryRecord, Hashable {
    public var id = UUID()
    /// The creature the art is for: a bestiary key or a custom creature's `custom.<id>` key.
    public var subject: String
    /// The image file in the `ArtStore`, such as `<id>.jpg`.
    public var fileName: String
    public var byteCount: Int
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?

    /// Art paths starting with this are pasted art in the `ArtStore`, not bundled art.
    public static let pathPrefix = "Pasted/"

    public init(subject: String, fileName: String, byteCount: Int) {
        self.subject = subject
        self.fileName = fileName
        self.byteCount = byteCount
    }

    /// The path the art views load, such as `Pasted/<id>.jpg`.
    public var path: String { Self.pathPrefix + fileName }
}

public extension ArtReference {
    /// The same art references with pasted art taking the place of the portrait, token and thumbnail. The card
    /// back is cleared, so the player view frames the pasted art in a drawn card back.
    func replacing(with art: CustomArt) -> ArtReference {
        var replaced = self
        replaced.portrait = art.path
        replaced.token = art.path
        replaced.cardBack = ""
        return replaced
    }
}
