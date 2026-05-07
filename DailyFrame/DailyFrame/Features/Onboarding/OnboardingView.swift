import SwiftUI

struct OnboardingView: View {
    let onStart: () -> Void

    @State private var selectedPage = 0

    private let pages: [OnboardingPage] = [
        .init(
            title: L10n.string("onboarding.page1.title"),
            message: L10n.string("onboarding.page1.message"),
            symbol: "camera.aperture",
            accent: AppTheme.Colors.accent
        ),
        .init(
            title: L10n.string("onboarding.page2.title"),
            message: L10n.string("onboarding.page2.message"),
            symbol: "flame.fill",
            accent: AppTheme.Colors.success
        ),
        .init(
            title: L10n.string("onboarding.page3.title"),
            message: L10n.string("onboarding.page3.message"),
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
                    Text(selectedPage == pages.count - 1 ? L10n.string("onboarding.start") : L10n.string("onboarding.next"))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppTheme.Colors.accent)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                Button(L10n.string("onboarding.skip"), action: onStart)
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
