import SwiftUI

extension View {
    /// For names: each word capitalized and no autocorrect, so fantasy names aren't "fixed". The Mac
    /// keyboard has no autocapitalization, so there it only turns autocorrect off.
    func nameEntry() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.words).autocorrectionDisabled()
        #else
        autocorrectionDisabled()
        #endif
    }

    /// For titles such as encounter and scenario names: each word capitalized, autocorrect left on.
    func titleEntry() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.words)
        #else
        self
        #endif
    }
}
