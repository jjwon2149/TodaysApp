import SwiftUI

struct ProfileView: View {
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
                            settingsRow(title: "알림과 설정", symbol: "gearshape.fill")
                        }
                    }
                }
                .padding(AppTheme.Spacing.medium)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("보관함")
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
}
