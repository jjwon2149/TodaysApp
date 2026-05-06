import SwiftUI

struct OnboardingView: View {
    let onStart: () -> Void

    @State private var selectedPage = 0

    private let pages: [OnboardingPage] = [
        .init(
            title: "하루 한 장이면 충분합니다",
            message: "길게 쓰지 않아도 됩니다. 오늘을 대표하는 사진 한 장으로 기록을 시작합니다.",
            symbol: "camera.aperture",
            accent: AppTheme.Colors.accent
        ),
        .init(
            title: "스트릭으로 기록이 이어집니다",
            message: "부담 없는 미션과 연속 기록으로 매일 다시 돌아오게 만드는 구조를 만듭니다.",
            symbol: "flame.fill",
            accent: AppTheme.Colors.success
        ),
        .init(
            title: "나만의 조용한 아카이브를 쌓습니다",
            message: "공개 피드보다 개인 기록이 먼저입니다. 사진은 달력과 타임라인에 차곡차곡 쌓입니다.",
            symbol: "square.stack.3d.up.fill",
            accent: AppTheme.Colors.textPrimary
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xLarge) {
                        Spacer(minLength: 24)

                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .fill(page.accent.opacity(0.15))
                            .overlay {
                                Image(systemName: page.symbol)
                                    .font(.system(size: 54, weight: .semibold))
                                    .foregroundStyle(page.accent)
                            }
                            .frame(height: 280)

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                            Text(page.title)
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text(page.message)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .lineSpacing(4)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    .padding(.vertical, AppTheme.Spacing.xLarge)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: AppTheme.Spacing.small) {
                Button(action: primaryAction) {
                    Text(selectedPage == pages.count - 1 ? "시작하기" : "다음")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppTheme.Colors.accent)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                Button("나중에 둘러볼게요", action: onStart)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }

    private func primaryAction() {
        if selectedPage == pages.count - 1 {
            onStart()
        } else {
            withAnimation(.easeInOut) {
                selectedPage += 1
            }
        }
    }
}

private struct OnboardingPage {
    let title: String
    let message: String
    let symbol: String
    let accent: Color
}
