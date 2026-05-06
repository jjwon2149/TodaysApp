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
            Text("오늘도 한 장 남겨볼까요?")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(viewModel.currentStreak > 0 ? "현재 \(viewModel.currentStreak)일 연속 기록 중입니다" : "오늘 한 장으로 기록을 시작해보세요")
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
                    Text("\(viewModel.currentStreak)일 스트릭")
                        .font(.system(.title3, design: .rounded, weight: .bold))

                    Text("최고 \(viewModel.longestStreak)일 · Freeze \(viewModel.freezeCount)개 보유")
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

                Text("지금 하루를 가장 잘 보여주는 장면을 골라보세요")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("핵심 루프를 먼저 붙이는 단계라 미션은 임시 고정 문구를 사용합니다.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        if let entry = viewModel.todayEntry {
            AppCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    Text("오늘 기록 완료")
                        .font(.system(.headline, design: .rounded, weight: .semibold))

                    EntryImageView(imagePath: entry.imageLocalPath)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    if let memo = entry.memo, memo.isEmpty == false {
                        Text(memo)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    } else {
                        Text("메모 없이 사진만 기록했습니다.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Button(action: { isPresentingEditor = true }) {
                        Text("오늘 기록 수정하기")
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

                                Text("아직 오늘의 한 장이 없습니다")
                                    .font(.system(.headline, design: .rounded, weight: .semibold))

                                Text("앨범에서 사진을 고르고 메모를 남겨보세요.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }

                    Button(action: { isPresentingEditor = true }) {
                        Label("오늘 사진 남기기", systemImage: "photo.fill.on.rectangle.fill")
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
    }

    private var progressSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("이번 달 진행률")
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
            Text("최근 기록")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            if viewModel.recentEntries.isEmpty {
                AppCard {
                    Text("아직 최근 기록이 없습니다. 오늘 첫 장을 남겨보세요.")
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

    var body: some View {
        if let image = UIImage(contentsOfFile: imagePath) {
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
