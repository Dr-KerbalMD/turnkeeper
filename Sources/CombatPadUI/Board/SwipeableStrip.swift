import SwiftUI

/// An action revealed by swiping a strip: its name, icon and color, and what it does.
struct StripSwipeAction {
    let title: String
    let systemImage: String
    let color: Color
    let perform: () -> Void
}

/// Swipe actions for a strip on the ladder, which is a scroll view rather than a list. A sideways drag slides
/// the strip over its colored action, and letting go past the threshold fires it. Drags that start more up
/// and down than sideways are left alone, so the ladder still scrolls and strips can still be dragged into
/// place. Both actions are also accessibility actions.
struct SwipeableStrip: ViewModifier {
    /// Revealed by swiping left to right.
    let leading: StripSwipeAction?
    /// Revealed by swiping right to left.
    let trailing: StripSwipeAction?
    @State private var offset: CGFloat = 0
    @State private var isSideways: Bool?

    private static let threshold: CGFloat = 90

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background { revealed }
            .simultaneousGesture(swipe)
            .sensoryFeedback(.impact, trigger: isPastThreshold) { _, isPast in isPast }
            .accessibilityActions {
                if let leading { Button(leading.title, action: leading.perform) }
                if let trailing { Button(trailing.title, action: trailing.perform) }
            }
    }

    private var action: StripSwipeAction? { offset > 0 ? leading : offset < 0 ? trailing : nil }
    private var isPastThreshold: Bool { abs(offset) >= Self.threshold }

    @ViewBuilder private var revealed: some View {
        if let action {
            RoundedRectangle(cornerRadius: 10)
                .fill(action.color.opacity(isPastThreshold ? 1 : 0.55))
                .overlay(alignment: offset > 0 ? .leading : .trailing) {
                    Label(action.title, systemImage: action.systemImage)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                }
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let (sideways, upDown) = (value.translation.width, value.translation.height)
                if isSideways == nil { isSideways = abs(sideways) > abs(upDown) }
                guard isSideways == true else { return }
                offset = (sideways > 0 && leading == nil) || (sideways < 0 && trailing == nil) ? 0 : sideways
            }
            .onEnded { _ in
                let fired = isPastThreshold ? action : nil
                withAnimation(.snappy) { offset = 0 }
                isSideways = nil
                fired?.perform()
            }
    }
}
