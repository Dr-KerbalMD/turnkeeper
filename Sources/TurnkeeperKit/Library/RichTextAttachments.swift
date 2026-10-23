import Foundation
import UniformTypeIdentifiers

/// Images inside copied rich text: a PDF viewer such as QuickLook copies a selection as RTFD, with the image
/// as one of its attachments.
public enum RichTextAttachments {
    /// The flat RTFD pasteboard type.
    public static let flatRTFD = UTType("com.apple.flat-rtfd") ?? .rtfd

    /// The first image or PDF attached to flat RTFD data, in the order of the attachments' names.
    public static func firstImage(inFlatRTFD data: Data) -> Data? {
        guard let bundle = FileWrapper(serializedRepresentation: data), bundle.isDirectory else { return nil }
        let files = (bundle.fileWrappers ?? [:]).sorted { $0.key < $1.key }
        return files.lazy.compactMap { name, file in isImage(name) ? file.regularFileContents : nil }.first
    }

    private static func isImage(_ fileName: String) -> Bool {
        let type = UTType(filenameExtension: (fileName as NSString).pathExtension)
        return type?.conforms(to: .image) == true || type?.conforms(to: .pdf) == true
    }
}
