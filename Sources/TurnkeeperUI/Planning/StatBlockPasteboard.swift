import Bestiary
import TurnkeeperKit
import SwiftUI
import UniformTypeIdentifiers

/// Reads stat blocks from the pasteboard or a drop: Pluck's structured blocks first, else plain text.
enum StatBlockPasteboard {
    static let contentType = UTType(importedAs: PluckStatBlock.typeIdentifier, conformingTo: .json)
    static let acceptedTypes: [UTType] = [contentType, .utf8PlainText, .plainText]

    /// The stat blocks in dropped or pasted items, in order. On the main actor, where the items arrive.
    @MainActor
    static func blocks(from providers: [NSItemProvider]) async -> [PluckStatBlock] {
        var blocks: [PluckStatBlock] = []
        for provider in providers {
            blocks += await self.blocks(from: provider)
        }
        return blocks
    }

    @MainActor
    private static func blocks(from provider: NSItemProvider) async -> [PluckStatBlock] {
        if provider.hasItemConformingToTypeIdentifier(PluckStatBlock.typeIdentifier),
           let data = await data(from: provider, type: PluckStatBlock.typeIdentifier),
           let blocks = try? PluckStatBlock.blocks(from: data) {
            return blocks
        }
        for type in [UTType.utf8PlainText, .plainText] {
            guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { continue }
            if let data = await data(from: provider, type: type.identifier),
               let text = String(data: data, encoding: .utf8) {
                return PluckStatBlock.blocks(fromPlainText: text)
            }
        }
        return []
    }

    @MainActor
    private static func data(from provider: NSItemProvider, type: String) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: type, completionHandler: resume(continuation))
        }
    }

    /// Built outside the main actor: the provider calls back on its own queue.
    private nonisolated static func resume(
        _ continuation: CheckedContinuation<Data?, Never>
    ) -> @Sendable (Data?, (any Error)?) -> Void {
        { data, _ in continuation.resume(returning: data) }
    }
}

/// Accepts stat blocks pasted (⌘V on the Mac) or dropped onto the encounter, and reports what was added,
/// with Review… to check the first creature in the editor.
struct StatBlockImportModifier: ViewModifier {
    let encounterID: UUID
    let label: String
    @Environment(AppModel.self) private var model
    @State private var reviewing: CustomCreature?

    func body(content: Content) -> some View {
        content
            #if os(macOS)
            .onPasteCommand(of: StatBlockPasteboard.acceptedTypes) { providers in load(providers) }
            #endif
            .onDrop(of: StatBlockPasteboard.acceptedTypes, isTargeted: nil) { providers in
                load(providers)
                return true
            }
            .alert("Stat Blocks Added", isPresented: isShowingResult, presenting: model.statBlockImport) { result in
                Button("Review…") { reviewing = Self.firstToReview(in: result) }
                Button("OK", role: .cancel) {}
            } message: { result in
                Text(([result.summary] + result.warnings.prefix(4)).joined(separator: "\n"))
            }
            .sheet(item: $reviewing) { custom in
                CustomCreatureEditor(custom: model.library.customCreature(key: custom.key) ?? custom) {
                    model.library.save($0)
                }
            }
    }

    /// The first creature with notes to review, else the first one added.
    private static func firstToReview(in result: StatBlockImport) -> CustomCreature? {
        (result.items.first { !$0.warnings.isEmpty } ?? result.items.first)?.custom
    }

    private var isShowingResult: Binding<Bool> {
        Binding { [model] in model.statBlockImport != nil } set: { [model] in
            if !$0 { model.statBlockImport = nil }
        }
    }

    private func load(_ providers: [NSItemProvider]) {
        model.importStatBlocks(from: providers, encounterID: encounterID, currentLabel: label)
    }
}

/// The system Paste button for stat blocks: it reads what Pluck copied without iOS asking permission.
struct PasteStatBlocksRow: View {
    let encounterID: UUID
    let label: String
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack {
            PasteButton(supportedContentTypes: StatBlockPasteboard.acceptedTypes) { providers in
                model.importStatBlocks(from: providers, encounterID: encounterID, currentLabel: label)
            }
            .labelStyle(.titleAndIcon)
            Text("Stat blocks copied from Pluck, or drop them here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

extension CustomCreature: Identifiable {}
