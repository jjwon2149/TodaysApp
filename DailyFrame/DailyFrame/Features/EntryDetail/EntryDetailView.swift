import SwiftUI
import UIKit

struct EntryDetailView: View {
    @State private var entry: DailyPhotoEntry
    @State private var isPresentingEditor = false

    private let entryRepository = EntryRepository()
    private let onChanged: () async -> Void

    init(entry: DailyPhotoEntry, onChanged: @escaping () async -> Void = {}) {
        _entry = State(initialValue: entry)
        self.onChanged = onChanged
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                imageSection
                storySection
                metadataSection
                nextStepSection
            }
            .padding(AppTheme.Spacing.medium)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("기록 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("수정") {
                    isPresentingEditor = true
                }
                .font(.system(.body, design: .rounded, weight: .semibold))
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            EntryEditorView(existingEntry: entry) {
                await reloadEntry()
                await onChanged()
            }
        }
    }

    private var imageSection: some View {
        AppCard {
            EntryDetailImageView(imagePath: entry.imageLocalPath)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var storySection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text(DailyFrameDateFormatter.localDateDisplayString(from: entry.localDateString))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                if let memo = entry.memo, memo.isEmpty == false {
                    Text(memo)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                } else {
                    Text("메모 없이 사진만 기록했습니다.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    private var metadataSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                detailRow(title: "기분", value: entry.moodCode ?? "기록 없음", symbol: "face.smiling")
                detailRow(title: "미션", value: entry.missionCompleted ? "완료" : "미완료", symbol: "sparkles")
                detailRow(title: "기록 방식", value: sourceLabel, symbol: "photo.on.rectangle")
            }
        }
    }

    private var nextStepSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("수정과 삭제는 다음 단계에서 연결합니다.")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("수정 시 기존 날짜는 유지됩니다. 삭제는 스트릭 재계산 정책과 함께 다음 단계에서 연결합니다.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private var sourceLabel: String {
        switch entry.sourceType {
        case "library":
            return "앨범"
        default:
            return entry.sourceType
        }
    }

    private func detailRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: symbol)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 28)

            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    @MainActor
    private func reloadEntry() async {
        guard let updatedEntry = try? await entryRepository.fetchEntry(for: entry.localDateString) else {
            return
        }

        entry = updatedEntry
    }
}

private struct EntryDetailImageView: View {
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
                    VStack(spacing: AppTheme.Spacing.small) {
                        Image(systemName: "photo")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        Text("사진을 불러오지 못했습니다")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }
        }
    }
}
