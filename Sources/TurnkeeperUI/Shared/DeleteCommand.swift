import SwiftUI

extension View {
    /// On the Mac, the Delete key removes the selected row, standing in for swipe to delete. Elsewhere swiping
    /// does it, so this does nothing.
    func deleteCommand(perform action: @escaping () -> Void) -> some View {
        #if os(macOS)
        onDeleteCommand(perform: action)
        #else
        self
        #endif
    }
}
