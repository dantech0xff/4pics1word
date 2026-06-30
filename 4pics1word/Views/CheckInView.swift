import SwiftUI

struct CheckInView: View {
    let model: AppModel

    /// Coordinate space used to resolve the coin-fly start/end frames.
    fileprivate static let checkinSpace = "checkin"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var displayedCoins: Int = 0
    @State private var celebrate = false
    @State private var pulse = false
    @State private var celebTask: Task<Void, Never>?
    @State private var coinCleanupTask: Task<Void, Never>?

    // Coin fly-to-header animation (Phase 04). Frames captured in the "checkin" space.
    @State private var todayCellFrame: CGRect = .zero
    @State private var headerCounterFrame: CGRect = .zero
    @State private var flyingCoin: FlyingCoin?
    @State private var coinAtTarget = false

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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(backgroundView)
        .overlay(confettiOverlay.allowsHitTesting(false))
        .overlay(flyingCoinOverlay.allowsHitTesting(false))
        .coordinateSpace(name: Self.checkinSpace)
        .accessibilityIdentifier("CheckInView")
        .onPreferenceChange(CoinFramePreferenceKey.self) { frames in
            if let t = frames.todayCell { todayCellFrame = t }
            if let h = frames.headerCounter { headerCounterFrame = h }
        }
        .task { displayedCoins = model.progress.coins }
        .onDisappear {
            celebTask?.cancel()
            coinCleanupTask?.cancel()
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Daily Reward")
                .font(.title2.weight(.bold))
            HStack(spacing: 4) {
                Image(systemName: "circle.fill").foregroundStyle(.yellow).font(.caption)
                Text("\(displayedCoins)")
                    .font(.title3.weight(.semibold)).monospacedDigit()
                    .contentTransition(.numericText(value: Double(displayedCoins)))
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: CoinFramePreferenceKey.self,
                        value: CoinFrames(headerCounter: proxy.frame(in: .named(Self.checkinSpace)))
                    )
                }
            )
            .accessibilityIdentifier("CheckInHeaderCounter")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var dayStrip: some View {
        VStack(spacing: 12) {
            progressDots
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in dayTile(for: i) }
                }
                HStack(spacing: 8) {
                    ForEach(3..<6, id: \.self) { i in dayTile(for: i) }
                }
                dayTile(for: 6)
            }
        }
    }

    /// 7-dot progress row above the grid: filled = claimed, ring = today, hollow = locked.
    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in progressDot(for: i) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress, \(claimedCount) of 7 claimed")
        .accessibilityIdentifier("CheckInProgressDots")
    }

    @ViewBuilder
    private func progressDot(for i: Int) -> some View {
        switch tileState(for: i) {
        case .claimed:
            Circle().fill(Color.accentColor).frame(width: 8, height: 8)
        case .today:
            Circle().strokeBorder(Color.accentColor, lineWidth: 2).frame(width: 8, height: 8)
        case .locked:
            Circle().fill(Color.secondary.opacity(0.3)).frame(width: 8, height: 8)
        }
    }

    private func dayTile(for i: Int) -> some View {
        let isToday = tileState(for: i) == .today
        return DayTile(
            day: i + 1,
            reward: CheckIn.rewards[i],
            state: tileState(for: i),
            isJackpot: i == 6,
            pulse: pulse,
            todayDay: todayIndex.map { $0 + 1 },
            reduceMotion: reduceMotion,
            onClaim: isToday ? { claimTapped() } : nil
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
                claimTapped()
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
            CountdownLine(nextReward: nextReward, reduceMotion: reduceMotion)
                .accessibilityIdentifier("CheckInCountdown")
        }
    }

    private func claimTapped() {
        // Capture jackpot state before `checkIn()` flips `canCheckInToday` (and thus `todayIndex`).
        let claimingJackpot = (todayIndex == CheckIn.rewards.count - 1)
        guard model.checkIn() != nil else { return }
        Feedback.tap()
        if reduceMotion {
            displayedCoins = model.progress.coins
            pulse = true
        } else {
            withAnimation(.spring(duration: 0.3)) { pulse = true }
            spawnFlyingCoin()
            celebTask?.cancel()
            celebTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                if Task.isCancelled { return }
                Feedback.reward()
                // Counter ticks as the coin arrives — feels connected to the fly.
                withAnimation(.easeOut(duration: 0.5)) { displayedCoins = model.progress.coins }
                // Confetti is a Day-7 jackpot flourish only (validated); everyday claims get fly + haptic.
                if claimingJackpot { celebrate = true }
                try? await Task.sleep(for: .milliseconds(1300))
                if Task.isCancelled { return }
                withAnimation { celebrate = false }
            }
        }
    }

    /// Spawns a transient coin that springs from the today cell to the header counter.
    /// Reduce-motion never reaches here (gated in `claimTapped`).
    private func spawnFlyingCoin() {
        guard todayCellFrame != .zero, headerCounterFrame != .zero else { return }
        let from = CGPoint(x: todayCellFrame.midX, y: todayCellFrame.midY)
        let to = CGPoint(x: headerCounterFrame.midX, y: headerCounterFrame.midY)
        flyingCoin = FlyingCoin(from: from, to: to)
        coinAtTarget = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { coinAtTarget = true }
        coinCleanupTask?.cancel()
        coinCleanupTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.2)) { flyingCoin = nil }
        }
    }

    @ViewBuilder
    private var flyingCoinOverlay: some View {
        if let coin = flyingCoin {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .opacity(coinAtTarget ? 0 : 1)
                .position(x: coinAtTarget ? coin.to.x : coin.from.x,
                          y: coinAtTarget ? coin.to.y : coin.from.y)
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

/// Single-line live countdown to local midnight: `Next reward [coin] {N} in HH:MM:SS`.
/// Uses `TimelineView(.periodic)` (auto-cancels on dismiss — no Timer.publish wiring);
/// per-digit `.numericText()` slide gated by reduce-motion; DST-safe via Calendar.
private struct CountdownLine: View {
    let nextReward: Int
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { ctx in
            let remaining = max(0, Self.secondsUntilMidnight(from: ctx.date))
            let h = Int(remaining) / 3600
            let m = Int(remaining) / 60 % 60
            let s = Int(remaining) % 60
            HStack(spacing: 4) {
                Text("Next reward")
                    .foregroundStyle(.primary)
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(nextReward)")
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text("in")
                    .foregroundStyle(.secondary)
                timeUnit(h)
                Text(":")
                    .foregroundStyle(.secondary)
                timeUnit(m)
                Text(":")
                    .foregroundStyle(.secondary)
                timeUnit(s)
            }
            .font(.subheadline)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Next reward, \(nextReward) coins, available in \(h) hours \(m) minutes")
        }
    }

    @ViewBuilder
    private func timeUnit(_ value: Int) -> some View {
        let txt = Text(String(format: "%02d", value))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        if reduceMotion {
            txt
        } else {
            txt
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.15), value: value)
        }
    }

    private static func secondsUntilMidnight(from date: Date) -> TimeInterval {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: date)
        guard let nextMidnight = cal.date(byAdding: .day, value: 1, to: startToday) else {
            return 0
        }
        return nextMidnight.timeIntervalSince(date)
    }
}

private struct DayTile: View {
    let day: Int
    let reward: Int
    let state: DayTileState
    let isJackpot: Bool
    let pulse: Bool
    let todayDay: Int?
    let reduceMotion: Bool
    let onClaim: (() -> Void)?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric private var cellHeight: CGFloat = 96
    @ScaledMetric private var corner: CGFloat = 18

    var body: some View {
        ZStack {
            tileContent
                .frame(height: cellHeight)
                .frame(maxWidth: .infinity)
                .saturation(state == .locked ? 0.4 : 1)
                .brightness(state == .locked ? 0.05 : 0)
                .background(tileBackground)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(stateOverlay)
                .overlay(todayPill)
                .overlay(shimmerOverlay)
                .opacity(stateOpacity)
                .scaleEffect(scale)
                .shadow(color: state == .today ? Color.accentColor.opacity(0.55) : .clear,
                        radius: state == .today ? 10 : 0)
                .background(todayCellFrameReader)
        }
        .contentShape(Rectangle())
        .onTapGesture { if state == .today { onClaim?() } }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
        .accessibilityAddTraits(state == .today ? .isButton : .isStaticText)
        .accessibilityIdentifier(isJackpot ? "Day7Jackpot" : "Day\(day)Tile")
    }

    // MARK: - Content

    @ViewBuilder
    private var contentColumn: some View {
        VStack(spacing: 4) {
            Text("DAY \(day)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            if state == .claimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else {
                Image(systemName: isJackpot ? "gift.fill" : "bitcoinsign.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isJackpot ? .white : .yellow)
            }
            Text("\(reward)")
                .font(valueFont.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(isJackpot ? Color.orange : Color.primary)
        }
        .padding(.horizontal, 4)
    }

    /// Unclaimed, non-AX Day-7 jackpot gets a full-width horizontal layout with the
    /// JACKPOT pill inline (right-anchored). Locked/claimed/AX fall back to `contentColumn`.
    private var shouldUseJackpotRow: Bool {
        isJackpot && state != .claimed && !dynamicTypeSize.isAccessibilitySize
    }

    @ViewBuilder
    private var tileContent: some View {
        if shouldUseJackpotRow {
            jackpotRow
        } else {
            contentColumn
        }
    }

    @ViewBuilder
    private var jackpotRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.title)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("DAY \(day)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(reward)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            Spacer()
            Text("JACKPOT")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.orange))
        }
        .padding(.horizontal, 12)
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
                // No black scrim: the content column is desaturated instead (see `body`)
                // so the reward stays legible while reading "coming soon".
                EmptyView()
            case .claimed:
                // Green check now lives in `contentColumn` (single source of truth) — no overlay.
                EmptyView()
            }

            // Locked-only glassy padlock chip, top-trailing (no conflict w/ TODAY pill).
            if state == .locked {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(lockChipBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
            }
        }
    }

    @ViewBuilder
    private var lockChipBackground: some View {
        if reduceTransparency {
            Circle().fill(Color.secondary.opacity(0.55))
        } else {
            Circle().fill(.ultraThinMaterial)
        }
    }

    // MARK: - Badges

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
        if state == .today && pulse { return 1.08 }
        return 1
    }

    private var stateOpacity: Double {
        switch state {
        case .locked: return 1.0    // desaturation in `body` does the de-emphasis (no scrim)
        case .claimed: return 0.7
        default: return 1
        }
    }

    /// Diagonal highlight sweep on the today cell only (2.5s loop), reduce-motion-gated.
    @ViewBuilder
    private var shimmerOverlay: some View {
        if state == .today && !reduceMotion {
            GeometryReader { geo in
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 2.5) / 2.5
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.45), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .rotationEffect(.degrees(20))
                    .offset(x: t * (geo.size.width * 1.5) - geo.size.width * 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    /// Reports the today cell's frame in the checkin coordinate space so the coin-fly
    /// overlay knows where to spawn the coin. Only the today cell emits a frame.
    @ViewBuilder
    private var todayCellFrameReader: some View {
        if state == .today {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CoinFramePreferenceKey.self,
                    value: CoinFrames(todayCell: proxy.frame(in: .named(CheckInView.checkinSpace)))
                )
            }
        }
    }

    // MARK: - Accessibility strings

    private var a11yLabel: String {
        let jackpotSuffix = isJackpot ? ", jackpot" : ""
        switch state {
        case .claimed:
            return "Day \(day), \(reward) coins, claimed\(jackpotSuffix)"
        case .today:
            return "Day \(day), \(reward) coins, available to claim\(jackpotSuffix)"
        case .locked:
            if let todayDay, day > todayDay {
                return "Day \(day), \(reward) coins, locked, claim in \(day - todayDay) days\(jackpotSuffix)"
            }
            return "Day \(day), \(reward) coins, locked\(jackpotSuffix)"
        }
    }
}

private struct FlyingCoin: Identifiable {
    let id = UUID()
    let from: CGPoint
    let to: CGPoint
}

/// Carries the coin-fly anchor frames through a single preference key (one emitter each).
private struct CoinFrames: Equatable {
    var todayCell: CGRect?
    var headerCounter: CGRect?
    init(todayCell: CGRect? = nil, headerCounter: CGRect? = nil) {
        self.todayCell = todayCell
        self.headerCounter = headerCounter
    }
}

private struct CoinFramePreferenceKey: PreferenceKey {
    static var defaultValue = CoinFrames()
    static func reduce(value: inout CoinFrames, nextValue: () -> CoinFrames) {
        let n = nextValue()
        if n.todayCell != nil { value.todayCell = n.todayCell }
        if n.headerCounter != nil { value.headerCounter = n.headerCounter }
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
