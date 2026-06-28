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

    var body: some View {
        VStack(spacing: 20) {
            header
            dayStrip
            Spacer(minLength: 8)
            actionSection
        }
        .padding(.horizontal, 20)
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
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            .accessibilityLabel("Close")
        }
        .padding(.top, 4)
    }

    private var dayStrip: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { i in
                DayTile(
                    day: i + 1,
                    reward: CheckIn.rewards[i],
                    state: tileState(for: i),
                    isJackpot: i == 6,
                    pulse: pulse
                )
            }
        }
        .accessibilityElement(children: .contain)
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

private struct DayTile: View {
    let day: Int
    let reward: Int
    let state: DayTileState
    let isJackpot: Bool
    let pulse: Bool

    @ScaledMetric private var height: CGFloat = 44

    var body: some View {
        VStack(spacing: 4) {
            Text("Day \(day)")
                .font(.caption2.weight(.medium))
            Image(systemName: icon)
                .font(.body)
            Text("\(reward)")
                .font(.caption.weight(.semibold)).monospacedDigit()
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(background)
        .overlay(border)
        .opacity(opacity)
        .scaleEffect(state == .today && pulse ? 1.05 : 1)
        .accessibilityLabel("Day \(day) of 7")
        .accessibilityValue(valueLabel)
        .accessibilityHint("Reward: \(reward) coins")
    }

    private var icon: String {
        switch state {
        case .claimed: return "checkmark.circle.fill"
        case .today: return "gift.fill"
        case .locked: return "lock.fill"
        }
    }

    private var valueLabel: String {
        switch state {
        case .claimed: return "claimed"
        case .today: return "available today"
        case .locked: return "locked"
        }
    }

    @ViewBuilder
    private var background: some View {
        switch state {
        case .claimed:
            Capsule().fill(isJackpot ? AnyShapeStyle(Color.accentColor.opacity(0.25)) : AnyShapeStyle(Color.accentColor.opacity(0.15)))
        case .today:
            Capsule().fill(Color.accentColor.opacity(0.2))
        case .locked:
            Capsule().fill(Color.secondary.opacity(0.1))
        }
    }

    @ViewBuilder
    private var border: some View {
        switch state {
        case .today:
            Capsule().strokeBorder(Color.accentColor, lineWidth: 2)
        case .claimed where isJackpot:
            Capsule().strokeBorder(Color.accentColor, lineWidth: 1.5)
        default:
            EmptyView()
        }
    }

    private var opacity: Double {
        switch state {
        case .locked: return 0.4
        default: return 1
        }
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
