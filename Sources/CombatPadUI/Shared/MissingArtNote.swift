import SwiftUI

/// Says which PDFs a creature's art needs when they have gone missing (R2.3a), such as after they were deleted
/// from Scrollkeeper. Shows nothing otherwise.
struct MissingArtNote: View {
    let key: String
    @Environment(AppModel.self) private var model

    var body: some View {
        let missing = model.missingArtSources(for: key)
        if !missing.isEmpty {
            Label("Art needs \(missing.formatted(.list(type: .or))), no longer found. Restore it in Scrollkeeper, "
                  + "or check Creature Art.", systemImage: "photo.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
