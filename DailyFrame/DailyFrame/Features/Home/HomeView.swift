import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    headerSection
                    streakSection
                    missionSection
                    emptyStateSection
                    progressSection
                    recentSection
                }
                .padding(AppTheme.Spacing.medium)
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("오늘도 한 장 남겨볼까요?")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("현재 12일 연속 기록 중입니다")
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
                    Text("12일 스트릭")
                        .font(.system(.title3, design: .rounded, weight: .bold))

                    Text("최고 18일 · Freeze 1개 보유")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()
            }
        }
    }

    private var missionSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Label("오늘의 미션", systemImage: "sparkles")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accent)

                Text("파란색이 들어간 장면을 찍어보세요")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("무엇을 남길지 고민될 때, 오늘의 힌트가 시작점을 만들어줍니다.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private var emptyStateSection: some View {
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

                            Text("아직 오늘의 한 장이 없습니다")
                                .font(.system(.headline, design: .rounded, weight: .semibold))

                            Text("카메라를 열고 지금의 하루를 남겨보세요.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }

                Button(action: {}) {
                    Label("오늘 사진 남기기", systemImage: "camera.fill")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppTheme.Colors.accent)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
        }
    }

    private var progressSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("이번 달 진행률")
                    .font(.system(.headline, design: .rounded, weight: .semibold))

                Text("18일 중 14일 기록")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                ProgressView(value: 14, total: 18)
                    .tint(AppTheme.Colors.success)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("최근 기록")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            HStack(spacing: AppTheme.Spacing.small) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.Colors.secondaryAccent,
                                    AppTheme.Colors.muted
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 108)
                        .overlay(alignment: .bottomLeading) {
                            Text("기록")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .padding(10)
                        }
                }
            }
        }
    }
}
