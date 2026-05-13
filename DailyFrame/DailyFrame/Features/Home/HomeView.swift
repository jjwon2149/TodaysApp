import SwiftUI
import UIKit

struct HomeView: View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streakSection: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .padding(14)
                    .background(AppTheme.Colors.secondaryAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.currentStreakTitle)
                        .font(.system(.title3, design: .rounded, weight: .bold))

                    Text(viewModel.streakSummaryText)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    if let freezeNoticeText = viewModel.freezeNoticeText {
                        Text(freezeNoticeText)
                            .font(.system(.footnote, design: .rounded, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                }

                Spacer()
            }
        }
    }

    private var missionSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack(alignment: .center, spacing: AppTheme.Spacing.small) {
                    Label(viewModel.missionCategoryText, systemImage: viewModel.missionSymbolName)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.accent)

                    Spacer()

                    if viewModel.isTodayMissionCompleted {
                        Label("common.complete", systemImage: "checkmark.circle.fill")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.success)
                    }
                }

                Text(viewModel.missionTitle)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(viewModel.missionPrompt)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                if viewModel.isTodayMissionCompleted {
                    Text("home.mission.completed")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.success)
                } else {
                    Button(action: { isPresentingEditor = true }) {
                        Label("home.mission.record_button", systemImage: "camera.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.Colors.brandGradient)
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
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

                    if let memo = entry.memo, memo.isEmpty == false {
                        Text(memo)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    } else {
                        Text("entry.memo.empty")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Button(action: { isPresentingEditor = true }) {
                        Text("home.entry.edit_button")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.Colors.textPrimary)
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
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
                            }
                        }

                    Button(action: { isPresentingEditor = true }) {
                        Label("home.empty.button", systemImage: "photo.fill.on.rectangle.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.Colors.brandGradient)
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
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
                    }
                }
            }
        }
    }
}

private struct EntryImageView: View {
    let imagePath: String
    private let imageStorageService = ImageStorageService()

    var body: some View {
        if let imageURL = imageStorageService.resolvedFileURL(for: imagePath),
           let image = UIImage(contentsOfFile: imageURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
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
