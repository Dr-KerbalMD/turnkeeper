import Bestiary
import TurnkeeperKit
import Foundation

/// Planning changes: campaigns, parties, scenarios and encounters.
extension AppModel {
    @discardableResult
    func addCampaign(name: String, game: Game) -> Campaign {
        let campaign = Campaign(name: name, game: game)
        library.save(campaign)
        selectedCampaignID = campaign.id
        selection = nil
        return campaign
    }

    func deleteCampaign(_ id: UUID) {
        library.deleteCampaign(id)
        if selectedCampaignID == id { selectedCampaignID = library.activeCampaigns.first?.id }
        selection = nil
    }

    func addParty(to campaignID: UUID) {
        let party = Party(campaignID: campaignID, name: "New party", level: 1,
                          members: (1...4).map { PartyMember(name: "Player \($0)") })
        library.save(party)
        selection = .party(party.id)
    }

    func addScenario(to campaignID: UUID, name: String, labels: [String]) {
        var scenario = Scenario(campaignID: campaignID, name: name, variantLabels: labels)
        scenario.sortIndex = (library.scenarios(in: campaignID).map(\.sortIndex).max() ?? 0) + 1
        library.save(scenario)
        selection = .scenario(scenario.id)
    }

    func addEncounter(to scenarioID: UUID) {
        let existing = library.encounters(in: scenarioID)
        let letter = existing.count < 26 ? String(UnicodeScalar(UInt8(65 + existing.count))) : "\(existing.count + 1)"
        var encounter = Encounter(scenarioID: scenarioID, name: "Encounter \(letter)")
        encounter.sortIndex = (existing.map(\.sortIndex).max() ?? 0) + 1
        library.save(encounter)
        selection = .encounter(encounter.id)
    }

    func party(_ id: UUID?) -> Party? {
        library.parties.first { $0.id == id && !$0.isDeleted }
    }

    /// A party member by ID, from any party; members are unique across parties.
    func partyMember(_ id: UUID) -> PartyMember? {
        library.parties.lazy.filter { !$0.isDeleted }.flatMap(\.members).first { $0.id == id }
    }

    func scenario(_ id: UUID?) -> Scenario? {
        library.scenarios.first { $0.id == id && !$0.isDeleted }
    }

    func encounter(_ id: UUID?) -> Encounter? {
        library.encounters.first { $0.id == id && !$0.isDeleted }
    }

    /// The party used for budgets: the campaign's first party, if any.
    func defaultParty(for campaignID: UUID?) -> Party? {
        campaignID.flatMap { library.parties(in: $0).first }
    }
}
