import SwiftUI

struct ProfileView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                                .fixedSize(horizontal: false, vertical: true)

                            if let profileStatsStatusMessage = viewModel.profileStatsStatusMessage {
                                Text(profileStatsStatusMessage)
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    summarySection

                    if let freezeNoticeText = viewModel.freezeNoticeText {
                        AppCard {
                            Text(freezeNoticeText)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.accent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    notificationSettingsSection
                    exportSection
                    privacySection
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

    private var summarySection: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: AppTheme.Spacing.medium) {
                    summaryCards
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: AppTheme.Spacing.medium)],
                    spacing: AppTheme.Spacing.medium
                ) {
                    summaryCards
                }
            }
        }
    }

    @ViewBuilder
    private var summaryCards: some View {
        summaryCard(title: L10n.string("profile.streak.current"), value: viewModel.currentStreakText)
        summaryCard(title: L10n.string("profile.streak.best"), value: viewModel.longestStreakText)
        summaryCard(title: L10n.string("profile.streak.freeze"), value: viewModel.freezeCountText)
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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
    }

    private var notificationSettingsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                notificationToggleRow

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
                .accessibilityHint(Text("profile.notification.time.accessibility_hint"))

                Text(viewModel.notificationStatusMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var notificationToggleRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    notificationTitle
                    notificationToggle
                }
            } else {
                HStack(spacing: AppTheme.Spacing.medium) {
                    notificationTitle
                    Spacer()
                    notificationToggle
                }
            }
        }
    }

    private var notificationTitle: some View {
        Label {
            Text("profile.notification.title")
                .font(.system(.body, design: .rounded, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
        }
    }

    private var notificationToggle: some View {
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
        .accessibilityHint(Text("profile.notification.toggle.accessibility_hint"))
    }

    private var exportSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("profile.export.title")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("profile.export.subtitle")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(AppTheme.Colors.accent)
                        .frame(width: 28)
                        .accessibilityHidden(true)
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
                    .foregroundStyle(AppTheme.Colors.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .disabled(viewModel.isExportingArchive)
                .accessibilityHint(Text("profile.export.accessibility_hint"))

                if let exportStatusMessage = viewModel.exportStatusMessage {
                    Text(exportStatusMessage)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
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

    private var privacySection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Label {
                    Text("profile.privacy.title")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(AppTheme.Colors.accent)
                        .accessibilityHidden(true)
                }

                Text("profile.privacy.local_storage")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("profile.privacy.permissions")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("profile.privacy.delete")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
