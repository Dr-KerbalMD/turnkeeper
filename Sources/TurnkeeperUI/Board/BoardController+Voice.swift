import TurnkeeperKit
import Foundation

/// Voice entry in setup: the hold-to-talk button sets one strip's initiative at a time.
extension BoardController {

    /// Whose initiative the hold-to-talk button sets next.
    var initiativeTargetID: UUID? { state.initiativeTarget(chosen: chosenForInitiative) }

    /// Sets the spoken total on the target and moves on to the next strip without one. False when no number
    /// was heard.
    func recordSpokenInitiative(_ transcript: String) -> Bool {
        guard let target = initiativeTargetID,
              let value = SpokenNumberParser.initiative(from: transcript) else { return false }
        change { $0.setInitiative(value, for: target) }
        chosenForInitiative = nil
        return true
    }

}
