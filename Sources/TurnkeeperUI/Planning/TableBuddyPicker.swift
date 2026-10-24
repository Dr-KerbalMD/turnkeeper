import CharacterImport
import SwiftUI

/// Picks an iconic pregen to add as a Table Buddy: each with its portrait, name and class.
struct TableBuddyPicker: View {
    let partyID: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(model.tableBuddyChoices) { pregen in
                Button {
                    Task { await model.addTableBuddy(pregen.key, to: partyID) }
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        TableBuddyPortrait(url: model.pregenArtURL(pregen.key))
                        VStack(alignment: .leading) {
                            Text(pregen.name).font(.headline)
                            Text(pregen.className).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    // The whole row answers a tap, not just its portrait and name.
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Add Table Buddy")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .frame(minWidth: 360, minHeight: 480)
    }
}

/// A pregen's Community Use portrait, or a person symbol when there's none.
private struct TableBuddyPortrait: View {
    let url: URL?

    var body: some View {
        Group {
            if let url, let image = CGImageSource.firstImage(at: url) {
                Image(decorative: image, scale: 1).resizable().scaledToFit()
            } else {
                Image(systemName: "person.crop.square").font(.title).foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 56)
    }
}

private extension CGImageSource {
    /// A small thumbnail of the image at a URL, for a list row.
    static func firstImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 168]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
