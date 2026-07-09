import SwiftUI

struct OnboardingView: View {
    let onStart: (_ shouldPromptFirstRecord: Bool) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let valuePoints: [OnboardingValuePoint] = [
        .init(
            title: L10n.string("onboarding.value.photo.title"),
            message: L10n.string("onboarding.value.photo.message"),
            symbol: "camera.aperture",
            accent: AppTheme.Colors.accent
        ),
        .init(
            title: L10n.string("onboarding.value.archive.title"),
            message: L10n.string("onboarding.value.archive.message"),
            symbol: "calendar",
            accent: AppTheme.Colors.textPrimary
        ),
        .init(
            title: L10n.string("onboarding.value.streak.title"),
            message: L10n.string("onboarding.value.streak.message"),
            symbol: "flame.fill",
            accent: AppTheme.Colors.success
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xLarge) {
                    heroSection
                    if dynamicTypeSize.isAccessibilitySize == false {
                        valueSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? AppTheme.Spacing.small : AppTheme.Spacing.xLarge)
                .padding(.bottom, AppTheme.Spacing.large)
            }

            VStack(spacing: AppTheme.Spacing.small) {
                Button {
                    onStart(true)
                } label: {
                    Text(L10n.string("onboarding.start"))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppTheme.Colors.accentFill)
                        .foregroundStyle(AppTheme.Colors.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .accessibilityHint(Text(L10n.string("onboarding.start.accessibility_hint")))

                Button(L10n.string("onboarding.skip")) {
                    onStart(false)
                }
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .accessibilityHint(Text(L10n.string("onboarding.skip.accessibility_hint")))
            }
            .padding(AppTheme.Spacing.large)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            if dynamicTypeSize.isAccessibilitySize == false {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(AppTheme.Colors.accent.opacity(0.14))
                    .overlay {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .accessibilityHidden(true)
                    }
                    .frame(height: 210)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(L10n.string("onboarding.hero.accessibility_label")))
            }

            Text(L10n.string("onboarding.value.sentence"))
                .font(.system(dynamicTypeSize.isAccessibilitySize ? .title3 : .largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var valueSection: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            ForEach(valuePoints) { point in
                HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                    Image(systemName: point.symbol)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(point.accent)
                        .frame(width: 24, height: 24)
                        .padding(10)
                        .background(point.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(point.title)
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(point.message)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.Spacing.medium)
                .background(AppTheme.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct OnboardingValuePoint: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let symbol: String
    let accent: Color
}
