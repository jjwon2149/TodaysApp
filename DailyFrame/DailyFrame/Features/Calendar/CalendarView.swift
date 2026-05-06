import SwiftUI
import UIKit

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    headerSection

                    AppCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                            Text(viewModel.monthSummary)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            HStack(spacing: 10) {
                                ForEach(weekdaySymbols, id: \.self) { symbol in
                                    Text(symbol)
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                        .frame(maxWidth: .infinity)
                                }
                            }

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(viewModel.dayCells) { cell in
                                    CalendarDayCell(cell: cell)
                                }
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            Text("기록한 날은 사진 썸네일로 표시됩니다.")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text(viewModel.errorMessage ?? "이미지를 불러오지 못하는 기록은 완료 표시로 대신 보여줍니다. 기록 상세 연결은 다음 단계에서 붙입니다.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(AppTheme.Spacing.medium)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("캘린더")
            .task {
                await viewModel.loadMonth()
            }
            .refreshable {
                await viewModel.loadMonth()
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Text(viewModel.monthTitle)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Spacer()

            Button {
                Task {
                    await viewModel.moveMonth(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(AppTheme.Colors.card)
                    .clipShape(Circle())
            }
            .foregroundStyle(AppTheme.Colors.textPrimary)

            Button {
                Task {
                    await viewModel.moveMonth(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(AppTheme.Colors.card)
                    .clipShape(Circle())
            }
            .foregroundStyle(AppTheme.Colors.textPrimary)
        }
    }
}

private struct CalendarDayCell: View {
    let cell: CalendarViewModel.DayCell

    var body: some View {
        if let dayNumber = cell.dayNumber {
            content(dayNumber: dayNumber)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    if cell.isToday {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.Colors.accent, lineWidth: 2)
                    }
                }
                .accessibilityLabel(accessibilityLabel(dayNumber: dayNumber))
        } else {
            Color.clear
                .frame(height: 54)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func content(dayNumber: Int) -> some View {
        if let entry = cell.entry {
            ZStack(alignment: .topLeading) {
                CalendarEntryThumbnailView(imagePath: entry.thumbnailLocalPath ?? entry.imageLocalPath)

                LinearGradient(
                    colors: [.black.opacity(0.45), .clear],
                    startPoint: .top,
                    endPoint: .center
                )

                Text("\(dayNumber)")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.34))
                    .clipShape(Capsule())
                    .padding(5)
            }
            .overlay {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white, AppTheme.Colors.accent)
                            .padding(5)
                    }
                }
            }
        } else {
            VStack(spacing: 5) {
                Text("\(dayNumber)")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.muted)
        }
    }

    private func accessibilityLabel(dayNumber: Int) -> String {
        let status = cell.hasEntry ? "기록 있음" : "기록 없음"
        return "\(dayNumber)일, \(status)"
    }
}

private struct CalendarEntryThumbnailView: View {
    let imagePath: String

    var body: some View {
        if let image = UIImage(contentsOfFile: imagePath) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            AppTheme.Colors.secondaryAccent
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                }
        }
    }
}
