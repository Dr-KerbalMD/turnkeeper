import Foundation

/// The campaign that was open when the app last ran, so the next launch opens it again. It is kept per
/// device, like the other view settings, and isn't synced.
enum LastCampaign {
    private static let key = "lastCampaignID"

    static var id: UUID? {
        get { UserDefaults.standard.string(forKey: key).flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: key) }
    }
}
