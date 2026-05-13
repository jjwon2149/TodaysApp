import Foundation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class EntryEditorViewModel: ObservableObject {
    @Published var memo: String
    @Published var selectedMood: String?
    @Published var previewImage: UIImage?
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published private(set) var isShowingErrorAlert = false
    @Published private(set) var completionSummary: EntryCompletionSummary?

    let moodOptions = MoodLocalization.options

    var hasPhoto: Bool {
        previewImage != nil || existingEntry?.imageLocalPath != nil
    }

    var saveButtonTitle: String {
        existingEntry == nil ? L10n.string("editor.save.new") : L10n.string("editor.save.edit")
    }

    private let existingEntry: DailyPhotoEntry?
    private let entryRepository: EntryRepository
    private let imageStorageService: ImageStorageService
    private let streakService: StreakService
    private let streakStateRepository: StreakStateRepository
    private let missionService: MissionService
    private var imageData: Data?
    private var imageSourceType: String

    init(
        existingEntry: DailyPhotoEntry? = nil,
        entryRepository: EntryRepository = EntryRepository(),
        imageStorageService: ImageStorageService = ImageStorageService(),
        streakService: StreakService = StreakService(),
        streakStateRepository: StreakStateRepository = StreakStateRepository(),
        missionService: MissionService = MissionService()
    ) {
        self.existingEntry = existingEntry
        self.entryRepository = entryRepository
        self.imageStorageService = imageStorageService
        self.streakService = streakService
        self.streakStateRepository = streakStateRepository
        self.missionService = missionService
        self.memo = existingEntry?.memo ?? ""
        self.selectedMood = existingEntry?.moodCode
        self.imageSourceType = existingEntry?.sourceType ?? "library"

        if let path = existingEntry?.imageLocalPath {
            self.previewImage = UIImage(contentsOfFile: path)
        }
    }

    func loadPhotoItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        clearError()

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                presentError(L10n.string("error.photo.load"))
                return
            }

            previewImage = image
            imageData = data
            imageSourceType = "library"
        } catch {
            presentError(L10n.string("error.photo.import"))
        }
    }

    func loadCapturedImage(_ image: UIImage) {
        clearError()

        guard let data = image.jpegData(compressionQuality: 1.0) else {
            presentError(L10n.string("error.camera.process"))
            return
        }

        previewImage = image
        imageData = data
        imageSourceType = "camera"
    }

    func handleCameraCaptureFailure(_ error: Error) {
        presentError(error.localizedDescription)
    }

    func dismissErrorAlert() {
        isShowingErrorAlert = false
    }

    func saveEntry() async -> Bool {
        guard isSaving == false else { return false }

        clearError()

        guard hasPhoto else {
            presentError(L10n.string("error.save.no_photo"))
            return false
        }

        isSaving = true
        completionSummary = nil
        defer { isSaving = false }

        do {
            let dayKey = existingEntry?.localDateString ?? DailyFrameDateFormatter.localDateString(from: .now)
            let storedPath: String
            let thumbnailPath: String?
            var createdPaths: [String] = []

            if let imageData {
                let fileNames = imageStorageService.makeEntryImageFileNames(localDateString: dayKey)
                let storedImage = try imageStorageService.saveEntryImageData(
                    imageData,
                    imageFileName: fileNames.imageFileName,
                    thumbnailFileName: fileNames.thumbnailFileName
                )
                storedPath = storedImage.imageURL.path
                thumbnailPath = storedImage.thumbnailURL.path
                createdPaths = [storedImage.imageURL.path, storedImage.thumbnailURL.path]
            } else if let existingPath = existingEntry?.imageLocalPath {
                storedPath = existingPath

                if let existingThumbnailPath = existingEntry?.thumbnailLocalPath {
                    thumbnailPath = existingThumbnailPath
                } else {
                    let fileName = imageStorageService.makeThumbnailFileName(localDateString: dayKey)
                    // Legacy thumbnail backfill is opportunistic; memo/mood edits should still save.
                    if let generatedThumbnailPath = try? imageStorageService.saveThumbnail(
                        forImageAt: existingPath,
                        fileName: fileName
                    ).path {
                        thumbnailPath = generatedThumbnailPath
                        createdPaths.append(generatedThumbnailPath)
                    } else {
                        thumbnailPath = nil
                    }
                }
            } else {
                presentError(L10n.string("error.save.no_photo"))
                return false
            }

            var entryRollbackState: EntryRollbackState?
            var didUpsertEntry = false

            do {
                entryRollbackState = try await makeEntryRollbackState()
                let isEditingExistingEntry = existingEntry != nil
                let mission = try await missionService.mission(for: dayKey)
                var entry = existingEntry ?? DailyPhotoEntry(
                    localDateString: dayKey,
                    imageLocalPath: storedPath,
                    sourceType: imageSourceType
                )

                entry.localDateString = dayKey
                entry.updatedAtUTC = .now
                entry.imageLocalPath = storedPath
                entry.thumbnailLocalPath = thumbnailPath
                entry.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : memo.trimmingCharacters(in: .whitespacesAndNewlines)
                entry.moodCode = selectedMood
                entry.missionId = isEditingExistingEntry ? existingEntry?.missionId : mission.id
                entry.missionCompleted = isEditingExistingEntry ? existingEntry?.missionCompleted ?? false : true
                entry.sourceType = imageSourceType

                try await entryRepository.upsert(entry)
                didUpsertEntry = true

                let shouldRecordCompletion = isEditingExistingEntry == false
                let summaryMission: DailyMission

                if shouldRecordCompletion {
                    summaryMission = try await missionService.completeMission(for: dayKey)
                    try await streakService.recordCompletion(for: dayKey)
                } else {
                    summaryMission = mission
                }

                deleteReplacedImageFiles(newImagePath: storedPath, newThumbnailPath: thumbnailPath)

                let streakState = (try? await streakStateRepository.fetchPrimaryState()) ?? StreakState(
                    currentStreak: 1,
                    longestStreak: 1,
                    lastCompletedLocalDateString: dayKey
                )
                completionSummary = EntryCompletionSummary(
                    currentStreak: max(streakState.currentStreak, 1),
                    missionTitle: summaryMission.localizedTitle,
                    missionCompleted: shouldRecordCompletion ? summaryMission.isCompleted : entry.missionCompleted,
                    rewardText: L10n.string("editor.completion.reward_xp"),
                    returnMessage: Self.returnMessage(for: max(streakState.currentStreak, 1))
                )

                try? await WidgetSnapshotService().refreshSnapshot()
            } catch {
                let shouldCleanupCreatedFiles: Bool

                if didUpsertEntry == false {
                    shouldCleanupCreatedFiles = true
                } else if let entryRollbackState {
                    shouldCleanupCreatedFiles = await restoreEntryRollbackState(entryRollbackState)
                } else {
                    shouldCleanupCreatedFiles = false
                }

                if shouldCleanupCreatedFiles {
                    deleteCreatedImageFiles(createdPaths)
                }
                throw error
            }

            return true
        } catch {
            presentError(L10n.string("error.save.entry"))
            return false
        }
    }

    private func clearError() {
        errorMessage = nil
        isShowingErrorAlert = false
    }

    private func presentError(_ message: String) {
        errorMessage = message
        isShowingErrorAlert = true
    }

    private func deleteReplacedImageFiles(newImagePath: String, newThumbnailPath: String?) {
        let preservedPaths = Set([newImagePath, newThumbnailPath].compactMap { $0 })
        var deletedPaths = Set<String>()

        for path in [existingEntry?.imageLocalPath, existingEntry?.thumbnailLocalPath].compactMap({ $0 }) {
            guard preservedPaths.contains(path) == false,
                  deletedPaths.insert(path).inserted else {
                continue
            }

            try? imageStorageService.deleteFileIfExists(at: path)
        }
    }

    private func makeEntryRollbackState() async throws -> EntryRollbackState {
        EntryRollbackState(entries: try await entryRepository.store.load().entries)
    }

    private func restoreEntryRollbackState(_ state: EntryRollbackState) async -> Bool {
        do {
            try await entryRepository.store.update { snapshot in
                snapshot.entries = state.entries
            }
            return true
        } catch {
            return false
        }
    }

    private func deleteCreatedImageFiles(_ paths: [String]) {
        var deletedPaths = Set<String>()

        for path in paths where deletedPaths.insert(path).inserted {
            try? imageStorageService.deleteFileIfExists(at: path)
        }
    }

    private struct EntryRollbackState {
        let entries: [DailyPhotoEntry]
    }

    private static func returnMessage(for currentStreak: Int) -> String {
        if currentStreak <= 1 {
            return L10n.string("editor.completion.return_first")
        }

        return L10n.format("editor.completion.return_next", currentStreak + 1)
    }
}

struct EntryCompletionSummary: Equatable {
    let currentStreak: Int
    let missionTitle: String
    let missionCompleted: Bool
    let rewardText: String
    let returnMessage: String
}
