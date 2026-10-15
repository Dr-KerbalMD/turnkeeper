import SwiftUI

extension Binding {
    /// A binding that only reports `get`, for presentations the model ends: dismissing the sheet or alert on its
    /// own must not change anything, since the model's buttons answer or cancel.
    static func readOnly(_ get: @escaping () -> Value) -> Binding {
        Binding(get: get, set: { _ in
            // Ignored: the presented buttons update the model, which closes the presentation.
        })
    }
}

extension Button where Label == Text {
    /// An alert's cancel button, which only dismisses the alert.
    static func cancel(_ title: LocalizedStringKey = "Cancel") -> Button {
        Button(title, role: .cancel) {
            // Nothing to undo: SwiftUI dismisses the alert.
        }
    }
}
