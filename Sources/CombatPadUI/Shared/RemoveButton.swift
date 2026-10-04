import SwiftUI

/// A small trash button for a list row. Swipe-to-delete is iOS only, so rows show this on the Mac and the
/// iPad alike. Borderless, so a tap elsewhere in a form row doesn't trigger it.
struct RemoveButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: "trash", role: .destructive, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help(title)
            .accessibilityIdentifier(title)
    }
}
