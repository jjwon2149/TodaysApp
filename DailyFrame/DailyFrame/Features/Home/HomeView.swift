import SwiftUI

struct HomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @StateObject private var viewModel = HomeViewModel()
    @State private var isPresentingEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    headerSection
                    streakSection
                    missionSection
                    todaySection
                    progressSection
                    recentSection
                }
                .padding(AppTheme.Spacing.medium)
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
            .sheet(isPresented: $isPresentingEditor) {
                EntryEditorView(existingEntry: viewModel.todayEntry) {
                    await viewModel.load()
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("home.header.title")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(viewModel.headerSubtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streakSection: some View {
        AppCard {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        streakIcon
                        streakCopy
                    }
                } else {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                        streakIcon
                        streakCopy
                        Spacer()
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("home.streak.accessibility_label"))
            .accessibilityValue(Text(L10n.format("home.streak.accessibility_value", viewModel.currentStreak, viewModel.longestStreak, viewModel.freezeCount)))
        }
    }

    private var streakIcon: some View {
        Image(systemName: "flame.fill")
            .font(.title2)
            .foregroundStyle(AppTheme.Colors.accent)
            .padding(14)
            .background(AppTheme.Colors.secondaryAccent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHidden(true)
    }

    private var streakCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.currentStreakTitle)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(viewModel.streakSummaryText)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let freezeNoticeText = viewModel.freezeNoticeText {
                Text(freezeNoticeText)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var missionSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                missionHeader

                Text(viewModel.missionTitle)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(viewModel.missionPrompt)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if viewModel.isTodayMissionCompleted {
                    Text("home.mission.completed")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.success)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Button(action: { isPresentingEditor = true }) {
                        Label("home.mission.record_button", systemImage: "camera.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.Colors.brandGradient)
                            .foregroundStyle(AppTheme.Colors.onAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .accessibilityHint(Text("home.mission.record_button.accessibility_hint"))
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var missionHeader: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    missionCategoryLabel
                    missionCompletionLabel
                }
            } else {
                HStack(alignment: .center, spacing: AppTheme.Spacing.small) {
                    missionCategoryLabel
                    Spacer()
                    missionCompletionLabel
                }
            }
        }
    }

    private var missionCategoryLabel: some View {
        Label(viewModel.missionCategoryText, systemImage: viewModel.missionSymbolName)
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.accent)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var missionCompletionLabel: some View {
        if viewModel.isTodayMissionCompleted {
            Label("common.complete", systemImage: "checkmark.circle.fill")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Colors.success)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        if let entry = viewModel.todayEntry {
            AppCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    Text("home.entry.complete")
                        .font(.system(.headline, design: .rounded, weight: .semibold))

                    EntryImageView(imagePath: entry.imageLocalPath)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("home.entry.photo.accessibility_label"))
                        .accessibilityValue(Text(DailyFrameDateFormatter.localDateDisplayString(from: entry.localDateString)))

                    if let memo = entry.memo, memo.isEmpty == false {
                        Text(memo)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("entry.memo.empty")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: { isPresentingEditor = true }) {
                        Text("home.entry.edit_button")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.Colors.textPrimary)
                            .foregroundStyle(AppTheme.Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .accessibilityHint(Text("home.entry.edit_button.accessibility_hint"))
                }
            }
        } else {
            AppCard {
                VStack(spacing: AppTheme.Spacing.medium) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(AppTheme.Colors.muted)
                        .frame(height: 240)
                        .overlay {
                            VStack(spacing: AppTheme.Spacing.small) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)

                                Text("home.empty.title")
                                    .font(.system(.headline, design: .rounded, weight: .semibold))

                                Text("home.empty.subtitle")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(AppTheme.Spacing.medium)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("home.empty.accessibility_label"))

                    Button(action: { isPresentingEditor = true }) {
                        Label("home.empty.button", systemImage: "photo.fill.on.rectangle.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.Colors.brandGradient)
                            .foregroundStyle(AppTheme.Colors.onAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .accessibilityHint(Text("home.empty.button.accessibility_hint"))
                }
            }
        }
    }

    private var progressSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("home.progress.title")
                    .font(.system(.headline, design: .rounded, weight: .semibold))

                Text(viewModel.monthProgressText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                ProgressView(value: Double(viewModel.monthEntryCount), total: Double(max(viewModel.currentMonthDayCount, 1)))
                    .tint(AppTheme.Colors.success)
                    .accessibilityLabel(Text("home.progress.title"))
                    .accessibilityValue(Text(L10n.format("home.progress.accessibility_value", viewModel.monthEntryCount, viewModel.currentMonthDayCount)))
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("home.recent.title")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            if viewModel.recentEntries.isEmpty {
                AppCard {
                    Text("home.recent.empty")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            } else {
                HStack(spacing: AppTheme.Spacing.small) {
                    ForEach(viewModel.recentEntries.prefix(3)) { entry in
                        EntryImageView(imagePath: entry.imageLocalPath)
                            .frame(height: 108)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("home.recent.photo.accessibility_label"))
                            .accessibilityValue(Text(DailyFrameDateFormatter.localDateDisplayString(from: entry.localDateString)))
                    }
                }
            }
        }
    }
}

private struct EntryImageView: View {
    let imagePath: String

    var body: some View {
        LocalImageView(imagePath: imagePath) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.Colors.muted)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
        }
    }
}
