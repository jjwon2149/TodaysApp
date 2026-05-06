import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    AppCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            Text("나의 기록")
                                .font(.system(.title3, design: .rounded, weight: .bold))

                            Text("지금까지 42일을 남겼습니다")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }

                    HStack(spacing: AppTheme.Spacing.medium) {
                        summaryCard(title: "현재", value: "12일")
                        summaryCard(title: "최고", value: "18일")
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                            settingsRow(title: "배지 보기", symbol: "medal.fill")
                            settingsRow(title: "프리미엄 살펴보기", symbol: "sparkles")
                        }
                    }

                    notificationSettingsSection
                }
                .padding(AppTheme.Spacing.medium)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("보관함")
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

    private func settingsRow(title: String, symbol: String) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 28)

            Text(title)
                .font(.system(.body, design: .rounded, weight: .medium))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private var notificationSettingsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack(spacing: AppTheme.Spacing.medium) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(AppTheme.Colors.accent)
                        .frame(width: 28)

                    Text("매일 기록 알림")
                        .font(.system(.body, design: .rounded, weight: .medium))

                    Spacer()

                    Toggle(
                        "매일 기록 알림",
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
                    "알림 시간",
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
}
