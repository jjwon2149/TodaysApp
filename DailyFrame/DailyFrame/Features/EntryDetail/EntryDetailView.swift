import SwiftUI
import UIKit

struct EntryDetailView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        .navigationTitle(L10n.string("entry.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.string("common.edit")) {
                    isPresentingEditor = true
                }
                .font(.system(.body, design: .rounded, weight: .semibold))
                .accessibilityHint(Text("entry.detail.edit.accessibility_hint"))
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            EntryEditorView(existingEntry: entry, completionActionTitle: L10n.string("entry.detail.return_action")) {
                await reloadEntry()
                await onChanged()
            }
        }
        .confirmationDialog(L10n.string("entry.delete.confirm_title"), isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(L10n.string("entry.delete.action"), role: .destructive) {
                Task {
                    await deleteEntry()
                }
            }

            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text("entry.delete.confirm_message")
        }
        .alert(L10n.string("entry.delete.error_title"), isPresented: Binding(get: {
            errorMessage != nil
        }, set: { newValue in
            if newValue == false {
                errorMessage = nil
            }
        })) {
            Button(L10n.string("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var imageSection: some View {
        AppCard {
            EntryDetailImageView(imagePath: entry.imageLocalPath)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("entry.detail.photo.accessibility_label"))
                .accessibilityValue(Text(DailyFrameDateFormatter.localDateDisplayString(from: entry.localDateString)))
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
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("entry.memo.empty")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var metadataSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                detailRow(title: L10n.string("entry.detail.mood"), value: MoodLocalization.displayName(for: entry.moodCode), symbol: "face.smiling")
                detailRow(title: L10n.string("entry.detail.mission"), value: entry.missionCompleted ? L10n.string("common.complete") : L10n.string("common.incomplete"), symbol: "sparkles")
                detailRow(title: L10n.string("entry.detail.source"), value: sourceLabel, symbol: "photo.on.rectangle")
            }
        }
    }

    private var policySection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("entry.manage.title")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("entry.manage.subtitle")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Text(isDeleting ? L10n.string("entry.delete.deleting") : L10n.string("entry.delete.action"))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.muted)
                        .foregroundStyle(Color(uiColor: .systemRed))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .disabled(isDeleting)
                .accessibilityHint(Text("entry.delete.accessibility_hint"))
            }
        }
    }

    private var sourceLabel: String {
        switch entry.sourceType {
        case "library":
            return L10n.string("entry.source.library")
        case "camera":
            return L10n.string("entry.source.camera")
        default:
            return entry.sourceType
        }
    }

    private func detailRow(title: String, value: String, symbol: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    detailRowIcon(symbol: symbol)
                    detailRowText(title: title, value: value)
                }
            } else {
                HStack(spacing: AppTheme.Spacing.medium) {
                    detailRowIcon(symbol: symbol)

                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Text(value)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
    }

    private func detailRowIcon(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(width: 28)
            .accessibilityHidden(true)
    }

    private func detailRowText(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
            try? await WidgetSnapshotService().refreshSnapshot()
            try? imageStorageService.deleteFileIfExists(at: entry.imageLocalPath)

            if let thumbnailLocalPath = entry.thumbnailLocalPath {
                try? imageStorageService.deleteFileIfExists(at: thumbnailLocalPath)
            }

            await onChanged()
            dismiss()
        } catch {
            errorMessage = L10n.string("error.entry.delete")
        }
    }
}

private struct EntryDetailImageView: View {
    let imagePath: String

    var body: some View {
        LocalImageView(imagePath: imagePath) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.Colors.muted)
                .overlay {
                    VStack(spacing: AppTheme.Spacing.small) {
                        Image(systemName: "photo")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        Text("entry.image.load_failed")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }
        }
    }
}
