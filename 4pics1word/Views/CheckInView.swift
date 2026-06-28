import SwiftUI

struct CheckInView: View {
    let model: AppModel
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var displayedCoins: Int = 0
    @State private var celebrate = false
    @State private var pulse = false
    @State private var celebTask: Task<Void, Never>?

    /// Current 0-based tier position (0..6) of the most recent claim; nil before any claim.
    private var lastClaimTierIndex: Int? {
        guard model.progress.streakDays > 0 else { return nil }
        return ((model.progress.streakDays - 1) % 7 + 7) % 7
    }

    private var claimedCount: Int {
        if model.canCheckInToday {
            return nextTierIndex
        }
        return (lastClaimTierIndex ?? -1) + 1
    }

    private var todayIndex: Int? {
        guard model.canCheckInToday else { return nil }
        return nextTierIndex
    }

    /// 0-based tier index of the upcoming claim (wraps past day 7 back to 0).
    private var nextTierIndex: Int {
        let next = CheckIn.nextStreakDay(model.progress)
        return ((next - 1) % 7 + 7) % 7
    }

    /// Dismissal gate: the sheet may only close once today's reward has been claimed
    /// (or if there is nothing to claim). Derived from existing observable state (DRY).
    private var canDismiss: Bool { !model.canCheckInToday }

    /// Close-button handler. Fires a warning haptic and aborts when the gate is closed;
    /// otherwise forwards to the host via `onDismiss`.
    private func attemptClose() {
        guard canDismiss else {
            Feedback.warning()
            return
        }
        onDismiss()
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            dayStrip
            Spacer(minLength: 8)
            actionSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(backgroundView)
        .overlay(confettiOverlay.allowsHitTesting(false))
        .accessibilityIdentifier("CheckInView")
        .task { displayedCoins = model.progress.coins }
        .onDisappear { celebTask?.cancel() }
    }

    private var header: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Text("Daily Reward")
                    .font(.title2.weight(.bold))
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill").foregroundStyle(.yellow).font(.caption)
                    Text("\(displayedCoins)")
                        .font(.title3.weight(.semibold)).monospacedDigit()
                        .contentTransition(.numericText(value: Double(displayedCoins)))
                }
            }
            Spacer()
            Button(action: attemptClose) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            .disabled(!canDismiss)
            .opacity(canDismiss ? 1 : 0.4)
            .accessibilityLabel("Close")
            .accessibilityHint(canDismiss
                ? "Closes the reward sheet."
                : "Disabled until you claim today's reward. Double-tap the Claim button to continue.")
        }
        .padding(.top, 4)
    }

    private var dayStrip: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in dayTile(for: i, rowSize: .three) }
            }
            HStack(spacing: 8) {
                ForEach(3..<7, id: \.self) { i in dayTile(for: i, rowSize: .four) }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func dayTile(for i: Int, rowSize: DayTileRowSize) -> some View {
        DayTile(
            day: i + 1,
            reward: CheckIn.rewards[i],
            state: tileState(for: i),
            isJackpot: i == 6,
            pulse: pulse,
            rowSize: rowSize
        )
    }

    private func tileState(for index: Int) -> DayTileState {
        if index < claimedCount { return .claimed }
        if let todayIndex, index == todayIndex { return .today }
        return .locked
    }

    @ViewBuilder
    private var actionSection: some View {
        if model.canCheckInToday {
            let reward = todayIndex.map { CheckIn.rewards[$0] } ?? CheckIn.rewards[0]
            Button {
                claimTapped(previewedReward: reward)
            } label: {
                Text("Claim \(reward) coins")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Claims today's daily reward of \(reward) coins")
        } else {
            let nextReward = CheckIn.reward(forStreakDay: model.progress.streakDays + 1)
            VStack(spacing: 6) {
                Text("Come back tomorrow")
                    .font(.headline)
                Text("Next reward: \(nextReward) coins")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func claimTapped(previewedReward: Int) {
        guard model.checkIn() != nil else { return }
        Feedback.tap()
        if reduceMotion {
            displayedCoins = model.progress.coins
            pulse = true
        } else {
            withAnimation(.spring(duration: 0.4)) { pulse = true }
            withAnimation(.easeOut(duration: 0.8)) { displayedCoins = model.progress.coins }
            celebrate = true
            celebTask?.cancel()
            celebTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                if Task.isCancelled { return }
                Feedback.reward()
                try? await Task.sleep(for: .milliseconds(1300))
                if Task.isCancelled { return }
                celebrate = false
            }
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if reduceTransparency {
            Color(.systemBackground)
        } else {
            Color(.systemBackground)
                .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var confettiOverlay: some View {
        if celebrate && !reduceMotion {
            ConfettiOverlay(trigger: celebrate)
        }
    }
}

private enum DayTileState { case claimed, today, locked }

/// Drives per-row sizing: row 1 holds 3 tiles (larger), row 2 holds 4 (smaller).
private enum DayTileRowSize { case three, four }

private struct DayTile: View {
    let day: Int
    let reward: Int
    let state: DayTileState
    let isJackpot: Bool
    let pulse: Bool
    let rowSize: DayTileRowSize

    @ScaledMetric private var threeHeight: CGFloat = 112
    @ScaledMetric private var fourHeight: CGFloat = 88
    @ScaledMetric private var corner: CGFloat = 18

    private var height: CGFloat { rowSize == .three ? threeHeight : fourHeight }

    var body: some View {
        ZStack {
            contentColumn
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .background(tileBackground)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(stateOverlay)
                .overlay(jackpotBadge)
                .overlay(todayPill)
                .opacity(stateOpacity)
                .scaleEffect(scale)
                .shadow(color: state == .today ? Color.accentColor.opacity(0.55) : .clear,
                        radius: state == .today ? 10 : 0)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day \(day) of 7")
        .accessibilityValue(valueLabel)
        .accessibilityHint(a11yHint)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentColumn: some View {
        VStack(spacing: 4) {
            Text("DAY \(day)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
            Text("\(reward)")
                .font(valueFont.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(isJackpot ? Color.orange : Color.primary)
        }
        .padding(.horizontal, 4)
    }

    private var valueFont: Font {
        switch state {
        case .today where isJackpot: return .title2
        case .today: return .title3
        case .claimed: return .callout
        default: return .body
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var tileBackground: some View {
        if isJackpot && state != .claimed {
            LinearGradient(
                colors: [Color.yellow.opacity(0.85), Color.orange.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            switch state {
            case .claimed:
                Color.accentColor.opacity(isJackpot ? 0.25 : 0.15)
            case .today:
                Color.accentColor.opacity(0.2)
            case .locked:
                Color.secondary.opacity(0.1)
            }
        }
    }

    // MARK: - State overlays

    @ViewBuilder
    private var stateOverlay: some View {
        ZStack {
            switch state {
            case .today:
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            case .locked:
                // 30% dark scrim keeps the reward readable but visually de-emphasised.
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.black.opacity(0.3))
            case .claimed:
                // Green check overlay sits above the content column (coin icon still visible).
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.green)
            }

            // Locked-only padlock chip, top-trailing (no conflict w/ TODAY pill — locked != today).
            if state == .locked {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Circle().fill(Color.black.opacity(0.5)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
            }
        }
    }

    // MARK: - Badges

    @ViewBuilder
    private var jackpotBadge: some View {
        // Pill promises more than a claimed tile shows, so hide once claimed (mirrors
        // `tileBackground` dropping the golden gradient on the same transition).
        if isJackpot && state != .claimed {
            Text("JACKPOT")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.orange))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(6)
        }
    }

    @ViewBuilder
    private var todayPill: some View {
        if state == .today {
            Text("TODAY")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(6)
        }
    }

    // MARK: - State-driven presentation

    private var scale: CGFloat {
        if state == .claimed { return 0.95 }
        if state == .today && pulse { return 1.05 }
        return 1
    }

    private var stateOpacity: Double {
        switch state {
        case .locked: return 1.0    // 30% black scrim in `stateOverlay` does the dimming
        case .claimed: return 0.7
        default: return 1
        }
    }

    // MARK: - Accessibility strings

    private var valueLabel: String {
        switch state {
        case .claimed: return "claimed"
        case .today: return "available today"
        case .locked: return "locked"
        }
    }

    private var a11yHint: String {
        var parts = "Reward: \(reward) coins"
        if isJackpot { parts += ". Jackpot day" }
        return parts
    }
}

private struct ConfettiOverlay: View {
    let trigger: Bool
    @State private var particles: [Particle] = []
    @State private var progress: CGFloat = 0

    struct Particle: Identifiable {
        let id = UUID()
        let startX: CGFloat
        let drift: CGFloat
        let velocity: CGFloat
        let color: Color
        let size: CGFloat
        let spin: CGFloat
    }

    private let colors: [Color] = [.yellow, .orange, .pink, .blue, .green, .purple]

    var body: some View {
        GeometryReader { geo in
            Canvas { context, _ in
                let fall = geo.size.height + 40
                for p in particles {
                    let t = progress
                    let x = p.startX + p.drift * sin(t * 3 + p.spin)
                    let y = t * fall * p.velocity - 20
                    var copy = context
                    copy.opacity = Double(max(0, 1 - t))
                    let rect = CGRect(x: x, y: y, width: p.size, height: p.size)
                    copy.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(p.color))
                }
            }
            .onAppear { spawn(width: geo.size.width) }
            .onChange(of: trigger) { _, _ in spawn(width: geo.size.width) }
        }
    }

    private func spawn(width: CGFloat) {
        particles = (0..<36).map { _ in
            Particle(
                startX: CGFloat.random(in: 0...max(width, 1)),
                drift: CGFloat.random(in: -20...20),
                velocity: CGFloat.random(in: 0.7...1.0),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...10),
                spin: CGFloat.random(in: 0...(.pi * 2))
            )
        }
        progress = 0
        withAnimation(.easeIn(duration: 1.2)) { progress = 1 }
    }
}
