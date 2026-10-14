import TurnkeeperKit
import SwiftUI

/// Setup's voice entry: one large button below the ladder. Hold it and say the total; on release the number
/// goes to the highlighted strip, and the highlight moves to the next strip still without one. Tap a strip
/// to choose it instead.
struct HoldToTalkButton: View {
    let controller: BoardController
    @State private var voice = VoiceInitiative.shared
    @State private var isPressing = false
    @State private var message = ""

    var body: some View {
        VStack(spacing: 6) {
            label
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(background, in: Capsule())
                .contentShape(Capsule())
                .gesture(holdGesture)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Hold to Say Initiative")
                .accessibilityValue(targetName ?? "")
                .accessibilityAddTraits(.isButton)
                .opacity(isEnabled ? 1 : 0.5)
            Text(statusText)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .accessibilityIdentifier("voiceStatus")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        // A miss's message is about the strip it was for; choosing another clears it.
        .onChange(of: controller.initiativeTargetID) { message = "" }
    }

    private var label: some View {
        Label(isPressing ? "Listening…" : "Hold to Say Initiative",
              systemImage: isPressing ? "waveform" : "mic.fill")
            .font(.title2.bold())
            .foregroundStyle(isPressing ? .black : .white)
    }

    private var background: Color { isPressing ? .yellow : .black.opacity(0.45) }

    private var isEnabled: Bool { voice.isAvailable && controller.initiativeTargetID != nil }

    private var targetName: String? {
        controller.initiativeTargetID.flatMap { controller.state[$0]?.name }
    }

    private var statusText: String {
        if !voice.isAvailable { return voice.unavailableReason }
        if !message.isEmpty { return message }
        guard let targetName else { return "Everyone has an initiative." }
        return "Next: \(targetName)"
    }

    /// A zero-distance drag reports the press and the release reliably, unlike a zero-length long press,
    /// which ends the moment it begins.
    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressing, isEnabled, let target = controller.initiativeTargetID else { return }
                isPressing = true
                message = ""
                voice.listen(for: target)
            }
            .onEnded { _ in
                guard isPressing else { return }
                isPressing = false
                Task { await finish() }
            }
    }

    private func finish() async {
        let heard = await voice.finish()
        if !controller.recordSpokenInitiative(heard) {
            message = heard.isEmpty ? "Didn't hear anything. Hold and try again."
                : "Didn't catch a number in “\(heard)”. Hold and try again."
        }
    }
}
