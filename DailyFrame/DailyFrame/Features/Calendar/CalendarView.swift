import SwiftUI
import UIKit

struct CalendarView: View {
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
                CalendarEntryThumbnailView(
                    thumbnailPath: entry.thumbnailLocalPath,
                    fallbackImagePath: entry.imageLocalPath
                )

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
        let status = cell.hasEntry ? L10n.string("calendar.accessibility.has_entry") : L10n.string("calendar.accessibility.no_entry")
        return L10n.format("calendar.accessibility.day_status", dayNumber, status)
    }
}

private struct CalendarEntryThumbnailView: View {
    let thumbnailPath: String?
    let fallbackImagePath: String

    var body: some View {
        if let image = loadImage() {
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

    private func loadImage() -> UIImage? {
        for path in [thumbnailPath, fallbackImagePath].compactMap({ $0 }) {
            if let image = UIImage(contentsOfFile: path) {
                return image
            }
        }

        return nil
    }
}
