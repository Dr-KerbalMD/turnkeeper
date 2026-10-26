import Foundation

/// A scenario's handout: a name and one image to show the players, such as a map or a letter. The image is a
/// file in the `ArtStore`, like pasted art.
public struct Handout: LibraryRecord, Hashable {
    public var id = UUID()
    public var scenarioID: UUID
    public var name: String
    /// The image file in the `ArtStore`; empty until an image is added.
    public var fileName = ""
    public var byteCount = 0
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?
    public var sharedVersions: [Date]?

    public init(scenarioID: UUID, name: String) {
        self.scenarioID = scenarioID
        self.name = name
    }

    public var hasImage: Bool { !fileName.isEmpty }

    /// The path the art views load, such as `Pasted/<id>.jpg`; empty without an image.
    public var imagePath: String { hasImage ? CustomArt.pathPrefix + fileName : "" }
}
