import SwiftUI
import WidgetKit

struct DailyFrameWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DailyFrameWidgetSnapshot
}

struct DailyFrameWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyFrameWidgetEntry {
        DailyFrameWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyFrameWidgetEntry) -> Void) {
        completion(DailyFrameWidgetEntry(date: .now, snapshot: loadSnapshot() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyFrameWidgetEntry>) -> Void) {
        let now = Date()
        let entry = DailyFrameWidgetEntry(date: now, snapshot: loadSnapshot() ?? .placeholder)
        let refreshDate = DailyFrameWidgetSnapshot.nextMidnightRefreshDate(after: now)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadSnapshot() -> DailyFrameWidgetSnapshot? {
        guard let fileURL = DailyFrameWidgetSnapshot.snapshotFileURL(),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return try? JSONDecoder().decode(DailyFrameWidgetSnapshot.self, from: data)
    }
}

struct DailyFrameTodayWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: DailyFrameWidgetEntry

    private var hasEntryToday: Bool {
        entry.snapshot.hasEntry(on: entry.date)
    }

    private var streakCount: Int {
        entry.snapshot.displayCurrentStreak(on: entry.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Image(systemName: hasEntryToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(hasEntryToday ? Color(red: 0.28, green: 0.66, blue: 0.46) : Color(red: 0.96, green: 0.46, blue: 0.30))

                Spacer(minLength: 8)

                Text(entry.date, style: .time)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(hasEntryToday ? "Recorded today" : "Today is open")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text("\(streakCount)-day streak")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(red: 0.73, green: 0.24, blue: 0.18))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            if family == .systemMedium {
                Text(hasEntryToday ? "Come back tomorrow to keep the run alive." : "Tap to add today's frame.")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .widgetURL(DailyFrameWidgetDeepLink.todayURL)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(uiColor: .secondarySystemGroupedBackground),
                    Color(red: 1.0, green: 0.94, blue: 0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct DailyFrameTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: DailyFrameWidgetSnapshot.widgetKind,
            provider: DailyFrameWidgetProvider()
        ) { entry in
            DailyFrameTodayWidgetView(entry: entry)
        }
        .configurationDisplayName("DailyFrame")
        .description("Check today's record and current streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct DailyFrameWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyFrameTodayWidget()
    }
}
