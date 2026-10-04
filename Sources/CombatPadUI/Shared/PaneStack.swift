import CombatPadKit
import SwiftUI

/// The board's right half: the battle card over two notes panes, with grips to drag between them. A notes
/// pane dragged small collapses to its header, and a tap on the header opens it; double-tapping a grip
/// resets the split. The layout is kept per device.
struct PaneStack<Card: View, CreatureNotes: View, EncounterNotes: View>: View {
    @Binding var layout: SplitLayout
    let visible: Set<Int>
    let titles: [Int: String]
    @ViewBuilder let card: () -> Card
    @ViewBuilder let creatureNotes: () -> CreatureNotes
    @ViewBuilder let encounterNotes: () -> EncounterNotes
    @State private var dragStart: SplitLayout?

    static var gripHeight: CGFloat { 20 }

    var body: some View {
        GeometryReader { geometry in
            let shown = [SplitLayout.card, SplitLayout.creatureNotes, SplitLayout.encounterNotes]
                .filter { visible.contains($0) }
            let total = Double(geometry.size.height - CGFloat(shown.count - 1) * Self.gripHeight)
            let heights = layout.heights(total: total, visible: visible)
            VStack(spacing: 0) {
                ForEach(shown, id: \.self) { pane in
                    if let above = shown.last(where: { $0 < pane }) {
                        grip(above: above, below: pane, total: total)
                    }
                    content(pane).frame(height: max(0, heights[pane]))
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ pane: Int) -> some View {
        switch pane {
        case SplitLayout.card: card()
        case SplitLayout.creatureNotes: notesPane(pane, content: creatureNotes)
        default: notesPane(pane, content: encounterNotes)
        }
    }

    private func notesPane<Content: View>(_ pane: Int, content: () -> Content) -> some View {
        let isCollapsed = layout.collapsed.contains(pane)
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation { layout.toggle(pane) }
            } label: {
                Label(titles[pane] ?? "", systemImage: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !isCollapsed { content() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func grip(above: Int, below: Int, total: Double) -> some View {
        Capsule()
            .fill(.white.opacity(0.5))
            .frame(width: 44, height: 5)
            .frame(maxWidth: .infinity, minHeight: Self.gripHeight, maxHeight: Self.gripHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { drag in
                        let start = dragStart ?? layout
                        dragStart = start
                        var moved = start
                        moved.drag(above: above, below: below, by: drag.translation.height, total: total,
                                   visible: visible)
                        layout = moved
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .onTapGesture(count: 2) { withAnimation { layout.reset() } }
            .accessibilityLabel("Resize")
            .accessibilityHint("Drag to resize the card and notes; double-tap to reset")
            #if os(macOS)
            .onHover { inside in if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() } }
            #endif
    }
}

/// A `SplitLayout` saved per device as JSON in user defaults; a layout preference, not library data.
struct StoredSplitLayout: DynamicProperty {
    @AppStorage("cardNotesSplit") private var stored = ""

    var wrappedValue: SplitLayout {
        get { (try? JSONDecoder().decode(SplitLayout.self, from: Data(stored.utf8))) ?? SplitLayout() }
        nonmutating set {
            stored = (try? JSONEncoder().encode(newValue)).flatMap { String(bytes: $0, encoding: .utf8) } ?? ""
        }
    }

    var projectedValue: Binding<SplitLayout> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
