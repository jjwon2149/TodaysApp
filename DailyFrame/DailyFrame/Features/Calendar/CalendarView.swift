import SwiftUI

struct CalendarView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @StateObject private var viewModel = CalendarViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
    private let weekdaySymbols = [
        L10n.string("calendar.weekday.sun"),
        L10n.string("calendar.weekday.mon"),
        L10n.string("calendar.weekday.tue"),
        L10n.string("calendar.weekday.wed"),
        L10n.string("calendar.weekday.thu"),
        L10n.string("calendar.weekday.fri"),
        L10n.string("calendar.weekday.sat")
    ]

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
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 10) {
                                ForEach(weekdaySymbols, id: \.self) { symbol in
                                    Text(symbol)
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .accessibilityHidden(true)
                                }
                            }

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(viewModel.dayCells) { cell in
                                    if let entry = cell.entry {
                                        NavigationLink {
                                            EntryDetailView(entry: entry) {
                                                await viewModel.loadMonth()
                                            }
                                        } label: {
                                            CalendarDayCell(cell: cell)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        CalendarDayCell(cell: cell)
                                    }
                                }
                            }
                            .accessibilityElement(children: .contain)
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            Text("calendar.legend.title")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text(viewModel.errorMessage ?? L10n.string("calendar.legend.subtitle"))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(AppTheme.Spacing.medium)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(L10n.string("tab.calendar"))
            .task {
                await viewModel.loadMonth()
            }
            .refreshable {
                await viewModel.loadMonth()
            }
        }
    }

    private var headerSection: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    monthTitle
                    monthControls
                }
            } else {
                HStack(spacing: AppTheme.Spacing.small) {
                    monthTitle
                    Spacer()
                    monthControls
                }
            }
        }
    }

    private var monthTitle: some View {
        Text(viewModel.monthTitle)
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var monthControls: some View {
        HStack(spacing: AppTheme.Spacing.small) {
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
            .accessibilityLabel(Text("calendar.previous_month.accessibility_label"))
            .accessibilityHint(Text("calendar.month_button.accessibility_hint"))

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
            .accessibilityLabel(Text("calendar.next_month.accessibility_label"))
            .accessibilityHint(Text("calendar.month_button.accessibility_hint"))
        }
    }
}

private struct CalendarDayCell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let cell: CalendarViewModel.DayCell

    var body: some View {
        if let dayNumber = cell.dayNumber {
            content(dayNumber: dayNumber)
                .frame(maxWidth: .infinity)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 72 : 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    if cell.isToday {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.Colors.accent, lineWidth: 2)
                    }
                }
                .accessibilityLabel(accessibilityLabel(dayNumber: dayNumber))
                .accessibilityHint(cell.hasEntry ? Text("calendar.accessibility.open_entry_hint") : Text(""))
        } else {
            Color.clear
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 72 : 54)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func content(dayNumber: Int) -> some View {
        if let entry = cell.entry {
            ZStack(alignment: .topLeading) {
                CalendarEntryThumbnailView(
                    thumbnailPath: entry.thumbnailLocalPath,
                    imagePath: entry.imageLocalPath
                )

                LinearGradient(
                    colors: [.black.opacity(0.45), .clear],
                    startPoint: .top,
                    endPoint: .center
                )

                Text("\(dayNumber)")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
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
                    .lineLimit(1)

                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.muted)
        }
    }

    private func accessibilityLabel(dayNumber: Int) -> String {
        let status = cell.hasEntry ? L10n.string("calendar.accessibility.has_entry") : L10n.string("calendar.accessibility.no_entry")
        if cell.isToday {
            return L10n.format("calendar.accessibility.today_day_status", dayNumber, status)
        }

        return L10n.format("calendar.accessibility.day_status", dayNumber, status)
    }
}

private struct CalendarEntryThumbnailView: View {
    let thumbnailPath: String?
    let imagePath: String

    var body: some View {
        LocalImageView(imagePath: thumbnailPath ?? imagePath, fallbackImagePath: imagePath) {
            AppTheme.Colors.secondaryAccent
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                }
        }
    }

}
