import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    AppCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            Text("profile.header.title")
                                .font(.system(.title3, design: .rounded, weight: .bold))

                            Text(viewModel.totalEntriesText)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            if let profileStatsStatusMessage = viewModel.profileStatsStatusMessage {
                                Text(profileStatsStatusMessage)
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 96), spacing: AppTheme.Spacing.medium)],
                        spacing: AppTheme.Spacing.medium
                    ) {
                        summaryCard(title: L10n.string("profile.streak.current"), value: viewModel.currentStreakText)
                        summaryCard(title: L10n.string("profile.streak.best"), value: viewModel.longestStreakText)
                        summaryCard(title: L10n.string("profile.streak.freeze"), value: viewModel.freezeCountText)
                    }

                    if let freezeNoticeText = viewModel.freezeNoticeText {
                        AppCard {
                            Text(freezeNoticeText)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.accent)
                        }
                    }

                    notificationSettingsSection
                    exportSection
                }
                .padding(AppTheme.Spacing.medium)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(L10n.string("tab.profile"))
            .task {
                await viewModel.load()
            }
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
        }
    }

    private var notificationSettingsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack(spacing: AppTheme.Spacing.medium) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(AppTheme.Colors.accent)
                        .frame(width: 28)

                    Text("profile.notification.title")
                        .font(.system(.body, design: .rounded, weight: .medium))

                    Spacer()

                    Toggle(
                        L10n.string("profile.notification.title"),
                        isOn: Binding(
                            get: { viewModel.reminderEnabled },
                            set: { isEnabled in
                                Task {
                                    await viewModel.setReminderEnabled(isEnabled)
                                }
                            }
                        )
                    )
                    .labelsHidden()
                    .disabled(viewModel.isUpdatingReminder)
                }

                Divider()

                DatePicker(
                    L10n.string("profile.notification.time"),
                    selection: Binding(
                        get: { viewModel.reminderTime },
                        set: { newValue in
                            Task {
                                await viewModel.setReminderTime(newValue)
                            }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .font(.system(.body, design: .rounded, weight: .medium))
                .disabled(viewModel.reminderEnabled == false || viewModel.isUpdatingReminder)

                Text(viewModel.notificationStatusMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.accent)
                }
            }
        }
    }

    private var exportSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack(spacing: AppTheme.Spacing.medium) {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(AppTheme.Colors.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("profile.export.title")
                            .font(.system(.body, design: .rounded, weight: .medium))

                        Text("profile.export.subtitle")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                Button {
                    Task {
                        await viewModel.exportArchive()
                    }
                } label: {
                    Label(
                        viewModel.isExportingArchive ? L10n.string("profile.export.exporting") : L10n.string("profile.export.action"),
                        systemImage: "square.and.arrow.up.on.square.fill"
                    )
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.textPrimary)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .disabled(viewModel.isExportingArchive)

                if let exportStatusMessage = viewModel.exportStatusMessage {
                    Text(exportStatusMessage)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                if let exportedArchiveURL = viewModel.exportedArchiveURL {
                    ShareLink(item: exportedArchiveURL) {
                        Label("profile.export.share", systemImage: "square.and.arrow.up")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                }
            }
        }
    }
}
