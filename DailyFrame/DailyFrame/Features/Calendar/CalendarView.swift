import SwiftUI

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
                            Text("기록한 날은 강조 표시됩니다.")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text(viewModel.errorMessage ?? "날짜별 썸네일과 기록 상세 연결은 다음 단계에서 붙입니다.")
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
            VStack(spacing: 5) {
                Text("\(dayNumber)")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Circle()
                    .fill(cell.hasEntry ? AppTheme.Colors.accent : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(cell.hasEntry ? AppTheme.Colors.secondaryAccent : AppTheme.Colors.muted)
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
                .frame(height: 48)
                .accessibilityHidden(true)
        }
    }

    private func accessibilityLabel(dayNumber: Int) -> String {
        let status = cell.hasEntry ? "기록 있음" : "기록 없음"
        return "\(dayNumber)일, \(status)"
    }
}
