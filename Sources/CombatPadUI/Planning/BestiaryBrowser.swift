import CombatPadKit
import SwiftUI

/// Searches and filters the bestiary and adds creatures to an encounter. Stays open so several can be added.
struct BestiaryBrowser: View {
    let game: Game
    let partyLevel: Int?
    let add: (String) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var filter = BestiaryFilter()
    @State private var hasSetUpFilter = false

    private var sources: [String] {
        let entries = model.bestiary.index.entries.filter { filter.games == .both || $0.game == game }
        return Set(entries.map(\.source.title).filter { !$0.isEmpty }).sorted()
    }
    @State private var added: [String: Int] = [:]
    @State private var previewKey: String?

    var body: some View {
        NavigationStack {
            let results = filter.results(in: model.bestiary.index.entries, defaultGame: game)
            List {
                Section { FilterControls(filter: $filter, partyLevel: partyLevel, sources: sources) }
                Section("\(results.count) found") {
                    ForEach(results.prefix(400)) { entry in
                        BestiaryRow(entry: entry, partyLevel: partyLevel, addedCount: added[entry.key] ?? 0) {
                            add(entry.key)
                            added[entry.key, default: 0] += 1
                        } preview: {
                            previewKey = entry.key
                        }
                    }
                }
            }
            .searchable(text: $filter.text, prompt: "Name or trait")
            .navigationTitle("Bestiary")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: Binding(get: { previewKey.map(PreviewKey.init) }, set: { previewKey = $0?.id })) { key in
                CreaturePreview(key: key.id)
            }
        }
        .frame(minWidth: 560, minHeight: 640)
        .onAppear {
            guard !hasSetUpFilter else { return }
            hasSetUpFilter = true
            filter.useLevels(around: partyLevel)
        }
    }
}

private struct PreviewKey: Identifiable {
    var id: String
}

/// The browser's search and filters.
struct BestiaryFilter: Equatable {
    enum GameChoice: String, CaseIterable {
        case campaign = "This game"
        case both = "Both games"
    }

    enum KindChoice: String, CaseIterable {
        case all = "All"
        case creatures = "Creatures"
        case hazards = "Complex hazards"
    }

    var text = ""
    var games = GameChoice.campaign
    var kind = KindChoice.all
    var minimumLevel = EncounterBudget.lowestLevel
    var maximumLevel = EncounterBudget.highestLevel
    var rarity = "any"
    /// A book title, or "any".
    var source = "any"

    /// Party level −4 to +4, the levels the XP table covers; every level when there's no party.
    mutating func useLevels(around partyLevel: Int?) {
        let range = partyLevel.map { EncounterBudget(partyLevel: $0, partySize: 4).tableLevels }
            ?? EncounterBudget.lowestLevel...EncounterBudget.highestLevel
        minimumLevel = range.lowerBound
        maximumLevel = range.upperBound
    }

    func results(in entries: [BestiaryIndexEntry], defaultGame: Game) -> [BestiaryIndexEntry] {
        let query = text.lowercased().trimmingCharacters(in: .whitespaces)
        return entries.filter { entry in
            (games == .both || entry.game == defaultGame)
                && (minimumLevel...maximumLevel).contains(entry.level)
                && matchesKind(entry) && (rarity == "any" || entry.traits.rarity == rarity)
                && (source == "any" || entry.source.title == source)
                && (query.isEmpty || entry.name.lowercased().contains(query) || entry.traits.traits.contains(query))
        }
        .sorted { ($0.level, $0.name) < ($1.level, $1.name) }
    }

    private func matchesKind(_ entry: BestiaryIndexEntry) -> Bool {
        switch kind {
        case .all: return true
        case .creatures: return entry.kind == .creature
        case .hazards: return entry.kind == .hazard
        }
    }
}

private struct FilterControls: View {
    @Binding var filter: BestiaryFilter
    let partyLevel: Int?
    /// The books in the games being browsed, alphabetically.
    let sources: [String]

    var body: some View {
        Picker("Games", selection: $filter.games) {
            ForEach(BestiaryFilter.GameChoice.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        Picker("Kind", selection: $filter.kind) {
            ForEach(BestiaryFilter.KindChoice.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        Stepper("Lowest level \(filter.minimumLevel)\(offset(filter.minimumLevel))", value: $filter.minimumLevel,
                in: EncounterBudget.lowestLevel...filter.maximumLevel)
        Stepper("Highest level \(filter.maximumLevel)\(offset(filter.maximumLevel))", value: $filter.maximumLevel,
                in: filter.minimumLevel...EncounterBudget.highestLevel)
        if partyLevel != nil {
            Button("Party Range", systemImage: "arrow.uturn.backward") { filter.useLevels(around: partyLevel) }
        }
        Picker("Rarity", selection: $filter.rarity) {
            ForEach(["any", "common", "uncommon", "rare", "unique"], id: \.self) { Text($0.capitalized).tag($0) }
        }
        Picker("Source", selection: $filter.source) {
            Text("Any").tag("any")
            ForEach(sources, id: \.self) { Text($0).tag($0) }
        }
    }

    /// " (PL −4)" next to a level, when there's a party.
    private func offset(_ level: Int) -> String {
        guard let partyLevel else { return "" }
        let difference = level - partyLevel
        return difference == 0 ? " (PL)" : " (PL \(difference > 0 ? "+" : "−")\(abs(difference)))"
    }
}

private struct BestiaryRow: View {
    let entry: BestiaryIndexEntry
    let partyLevel: Int?
    let addedCount: Int
    let add: () -> Void
    let preview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ArtImage(path: entry.art.thumbnail, size: 48, shape: .circle, alignment: .top)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if addedCount > 0 { Text("+\(addedCount)").font(.caption.bold()).foregroundStyle(.green) }
            Button("Card", systemImage: "rectangle.portrait", action: preview).labelStyle(.iconOnly)
            Button("Add", systemImage: "plus.circle.fill", action: add).labelStyle(.iconOnly).font(.title2)
        }
        .buttonStyle(.borderless)
    }

    private var subtitle: String {
        var parts = ["\(entry.kind == .hazard ? "Hazard" : "Creature") \(entry.level)"]
        if let partyLevel {
            let budget = EncounterBudget(partyLevel: partyLevel, partySize: 4)
            parts.append("\(budget.experience(forLevel: entry.level)) XP")
        }
        parts.append(entry.traits.traits.prefix(3).joined(separator: ", "))
        parts.append(entry.source.title)
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
