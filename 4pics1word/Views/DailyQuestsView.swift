import SwiftUI

/// Daily quests sheet: three quests per day (easy → hard), seeded per user, rewards
/// scale with difficulty. Swipe down to dismiss — same dismissal model as CheckInView.
struct DailyQuestsView: View {
    let model: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                ForEach(model.todayQuests) { quest in
                    QuestCard(quest: quest, reduceTransparency: reduceTransparency) {
                        model.claimQuest(id: quest.id)
                    }
                }
                Text("New quests at midnight")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier("DailyQuestsView")
        .onAppear { model.ensureTodayQuests() }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Quests")
                    .font(.title2.weight(.bold))
                Text("Harder quests pay more")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            CoinCounter(coins: model.progress.coins)
        }
    }
}

private struct QuestCard: View {
    let quest: DailyQuest
    let reduceTransparency: Bool
    let onClaim: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: quest.icon)
                .font(.title3)
                .foregroundStyle(difficultyColor)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    difficultyChip
                    Spacer()
                    rewardPill
                }
                Text(quest.title)
                    .font(.subheadline.weight(.medium))
                ProgressView(value: Double(min(quest.progress, quest.target)), total: Double(quest.target))
                    .tint(difficultyColor)
                Text("\(min(quest.progress, quest.target))/\(quest.target)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            claimArea
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(reduceTransparency ? Color(.secondarySystemGroupedBackground) : Color(.systemGroupedBackground).opacity(0.7))
        )
    }

    private var difficultyChip: some View {
        Text(quest.difficulty.rawValue.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(difficultyColor.opacity(0.18)))
            .foregroundStyle(difficultyColor)
    }

    private var rewardPill: some View {
        Label("\(quest.reward)", systemImage: "dollarsign.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
    }

    @ViewBuilder
    private var claimArea: some View {
        if quest.claimed {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .accessibilityLabel("Claimed")
        } else if quest.isComplete {
            Button(action: onClaim) {
                Text("Claim")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityIdentifier("QuestClaim-\(quest.id)")
        }
    }

    private var difficultyColor: Color {
        switch quest.difficulty {
        case .easy: return .green
        case .medium: return .blue
        case .hard: return .orange
        }
    }
}
