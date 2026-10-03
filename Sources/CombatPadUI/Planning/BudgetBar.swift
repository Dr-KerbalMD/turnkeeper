import CombatPadKit
import SwiftUI

/// The XP total against the threat tiers, with the threat label: the encounter budget at a glance.
struct BudgetBar: View {
    let experience: Int
    let budget: EncounterBudget

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(experience) XP").font(.headline.monospacedDigit())
                Spacer()
                Text(label).font(.headline).foregroundStyle(color)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(color.gradient)
                        .frame(width: geometry.size.width * fraction(experience))
                    ForEach(ThreatLevel.allCases.dropFirst(), id: \.self) { threat in
                        Rectangle().fill(.secondary).frame(width: 1)
                            .offset(x: geometry.size.width * fraction(budget.budget(for: threat)))
                    }
                }
            }
            .frame(height: 10)
            HStack(spacing: 0) {
                ForEach(ThreatLevel.allCases, id: \.self) { threat in
                    Text("\(threat.rawValue.capitalized) \(budget.budget(for: threat))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var maximum: Double { Double(budget.budget(for: .extreme)) * 1.25 }

    private func fraction(_ value: Int) -> CGFloat {
        CGFloat(min(Double(value) / maximum, 1))
    }

    private var label: String {
        budget.isBeyondExtreme(experience: experience)
            ? "Beyond extreme" : budget.threat(forExperience: experience).rawValue.capitalized
    }

    private var color: Color {
        if budget.isBeyondExtreme(experience: experience) { return .purple }
        switch budget.threat(forExperience: experience) {
        case .trivial: return .gray
        case .low: return .green
        case .moderate: return .yellow
        case .severe: return .orange
        case .extreme: return .red
        }
    }
}
