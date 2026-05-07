import SwiftUI
import UIKit

struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var entry: DailyPhotoEntry
    @State private var isPresentingEditor = false
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private let entryRepository = EntryRepository()
    private let imageStorageService = ImageStorageService()
    private let streakService = StreakService()
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
                policySection
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
            EntryEditorView(existingEntry: entry, completionActionTitle: "기록으로 돌아가기") {
                await reloadEntry()
                await onChanged()
            }
        }
        .confirmationDialog("기록을 삭제할까요?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("기록 삭제", role: .destructive) {
                Task {
                    await deleteEntry()
                }
            }

            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제한 기록은 캘린더에서 숨겨지고, 스트릭은 남은 기록 기준으로 다시 계산됩니다.")
        }
        .alert("삭제할 수 없습니다", isPresented: Binding(get: {
            errorMessage != nil
        }, set: { newValue in
            if newValue == false {
                errorMessage = nil
            }
        })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
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

    private var policySection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("기록 관리")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("수정 시 날짜는 유지됩니다. 삭제하면 기록은 숨김 처리되고 스트릭은 활성 기록 기준으로 다시 계산됩니다.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Text(isDeleting ? "삭제 중..." : "기록 삭제")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.muted)
                        .foregroundStyle(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .disabled(isDeleting)
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

    @MainActor
    private func deleteEntry() async {
        guard isDeleting == false else { return }

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await entryRepository.softDelete(localDateString: entry.localDateString)
            try await streakService.rebuildFromActiveEntries()
            try? imageStorageService.deleteFileIfExists(at: entry.imageLocalPath)

            if let thumbnailLocalPath = entry.thumbnailLocalPath {
                try? imageStorageService.deleteFileIfExists(at: thumbnailLocalPath)
            }

            await onChanged()
            dismiss()
        } catch {
            errorMessage = "기록을 삭제하는 중 오류가 발생했습니다."
        }
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
