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
    @Published private(set) var savedEntry: DailyPhotoEntry?

    let moodOptions = MoodLocalization.options

    var hasPhoto: Bool {
        previewImage != nil || existingEntry?.imageLocalPath != nil
    }

    var saveButtonTitle: String {
        existingEntry == nil ? L10n.string("editor.save.new") : L10n.string("editor.save.edit")
    }

    var canSave: Bool {
        hasPhoto && isSaving == false
    }

    private let existingEntry: DailyPhotoEntry?
    private let entryRepository: EntryRepository
    private let imageStorageService: ImageStorageService
    private let missionService: MissionService
    private let missionRepository: MissionRepository
    private let recordStreakCompletion: (String) async throws -> Void
    private let fetchStreakState: () async throws -> StreakState
    private let dateProvider: DateProvider
    private let performPostSaveEffects: () async -> Void
    private var imageData: Data?
    private var imageSourceType: String

    init(
        existingEntry: DailyPhotoEntry? = nil,
        entryRepository: EntryRepository = EntryRepository(),
        imageStorageService: ImageStorageService = ImageStorageService(),
        streakService: StreakService = StreakService(),
        streakStateRepository: StreakStateRepository = StreakStateRepository(),
        missionService: MissionService = MissionService(),
        missionRepository: MissionRepository = MissionRepository(),
        streakCompletionRecorder: ((String) async throws -> Void)? = nil,
        streakStateFetcher: (() async throws -> StreakState)? = nil,
        dateProvider: DateProvider = DateProvider(),
        postSaveEffects: (() async -> Void)? = nil
    ) {
        self.existingEntry = existingEntry
        self.entryRepository = entryRepository
        self.imageStorageService = imageStorageService
        self.missionService = missionService
        self.missionRepository = missionRepository
        self.recordStreakCompletion = streakCompletionRecorder ?? { localDateString in
            try await streakService.recordCompletion(for: localDateString)
        }
        self.fetchStreakState = streakStateFetcher ?? {
            try await streakStateRepository.fetchPrimaryState()
        }
        self.dateProvider = dateProvider
        self.performPostSaveEffects = postSaveEffects ?? {
            try? await WidgetSnapshotService().refreshSnapshot()
            Task.detached(priority: .background) {
                await CloudKitSyncService.shared.synchronize(trigger: .localChange)
            }
        }
        self.memo = existingEntry?.memo ?? ""
        self.selectedMood = existingEntry?.moodCode
        self.imageSourceType = existingEntry?.sourceType ?? "library"

        if let path = existingEntry?.imageLocalPath,
           let imageURL = imageStorageService.resolvedFileURL(for: path) {
            self.previewImage = UIImage(contentsOfFile: imageURL.path)
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
        savedEntry = nil
        defer { isSaving = false }

        do {
            let dayKey = existingEntry?.localDateString ?? dateProvider.localDateStringForNow()
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
                storedPath = try imageStorageService.mediaReference(for: storedImage.imageURL)
                thumbnailPath = try imageStorageService.mediaReference(for: storedImage.thumbnailURL)
                createdPaths = [storedPath, thumbnailPath].compactMap { $0 }
            } else if let existingPath = existingEntry?.imageLocalPath {
                storedPath = imageStorageService.normalizedMediaReference(for: existingPath)

                if let existingThumbnailPath = existingEntry?.thumbnailLocalPath {
                    thumbnailPath = imageStorageService.normalizedMediaReference(for: existingThumbnailPath)
                } else {
                    let fileName = imageStorageService.makeThumbnailFileName(localDateString: dayKey)
                    // Legacy thumbnail backfill is opportunistic; memo/mood edits should still save.
                    if let generatedThumbnailURL = try? imageStorageService.saveThumbnail(
                        forImageAt: existingPath,
                        fileName: fileName
                    ),
                       let generatedThumbnailPath = try? imageStorageService.mediaReference(for: generatedThumbnailURL) {
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
            var missionRollbackState: MissionRollbackState?
            var didUpsertEntry = false
            var writtenEntry: DailyPhotoEntry?
            var writtenMission: DailyMission?

            do {
                entryRollbackState = try await makeEntryRollbackState(for: dayKey)
                let isEditingExistingEntry = existingEntry != nil
                if isEditingExistingEntry == false {
                    missionRollbackState = try await makeMissionRollbackState(for: dayKey)
                }
                let mission = isEditingExistingEntry ? nil : try await missionService.mission(for: dayKey)
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
                entry.missionId = isEditingExistingEntry ? existingEntry?.missionId : mission?.id
                entry.missionCompleted = isEditingExistingEntry ? existingEntry?.missionCompleted ?? false : true
                entry.sourceType = imageSourceType

                try await entryRepository.upsert(entry)
                didUpsertEntry = true
                writtenEntry = entry
                savedEntry = entry

                let shouldRecordCompletion = isEditingExistingEntry == false
                var completedMission: DailyMission?

                if shouldRecordCompletion {
                    completedMission = try await missionService.completeMission(for: dayKey)
                    writtenMission = completedMission
                    try await recordStreakCompletion(dayKey)
                }

                deleteReplacedImageFiles(newImagePath: storedPath, newThumbnailPath: thumbnailPath)

                if shouldRecordCompletion, let completedMission {
                    let confirmedStreak = (try? await fetchStreakState())?.currentStreak
                    completionSummary = EntryCompletionSummary(
                        outcome: .created,
                        confirmedCurrentStreak: confirmedStreak,
                        missionTitle: completedMission.localizedTitle,
                        missionCompleted: completedMission.isCompleted,
                        returnMessage: confirmedStreak.map(Self.returnMessage(for:))
                            ?? L10n.string("editor.completion.saved_message")
                    )
                } else {
                    completionSummary = EntryCompletionSummary(
                        outcome: .updated,
                        confirmedCurrentStreak: nil,
                        missionTitle: nil,
                        missionCompleted: nil,
                        returnMessage: L10n.string("editor.completion.updated_message")
                    )
                }

                await performPostSaveEffects()
            } catch {
                let shouldCleanupCreatedFiles: Bool

                if didUpsertEntry == false {
                    shouldCleanupCreatedFiles = true
                } else if let entryRollbackState, let writtenEntry {
                    let didRestoreEntry = await restoreEntryRollbackState(
                        entryRollbackState,
                        replacing: writtenEntry
                    )
                    if didRestoreEntry,
                       let missionRollbackState,
                       let writtenMission {
                        _ = await restoreMissionRollbackState(
                            missionRollbackState,
                            replacing: writtenMission
                        )
                    }
                    shouldCleanupCreatedFiles = didRestoreEntry
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
        let preservedFileNames = Set([newImagePath, newThumbnailPath].compactMap { path in
            path.map { imageStorageService.normalizedMediaReference(for: $0) }
        })
        var deletedPaths = Set<String>()

        for path in [existingEntry?.imageLocalPath, existingEntry?.thumbnailLocalPath].compactMap({ $0 }) {
            let fileName = imageStorageService.normalizedMediaReference(for: path)
            guard preservedFileNames.contains(fileName) == false,
                  deletedPaths.insert(path).inserted else {
                continue
            }

            try? imageStorageService.deleteFileIfExists(at: path)
        }
    }

    private func makeEntryRollbackState(for localDateString: String) async throws -> EntryRollbackState {
        EntryRollbackState(
            localDateString: localDateString,
            previousEntry: try await entryRepository.store.load().entries.first {
                $0.localDateString == localDateString
            }
        )
    }

    private func restoreEntryRollbackState(
        _ state: EntryRollbackState,
        replacing writtenEntry: DailyPhotoEntry
    ) async -> Bool {
        do {
            var didRestore = false
            try await entryRepository.store.update { snapshot in
                guard let index = snapshot.entries.firstIndex(where: {
                    $0.localDateString == state.localDateString
                }), Self.matchesForRollback(snapshot.entries[index], writtenEntry) else {
                    return
                }

                if let previousEntry = state.previousEntry {
                    snapshot.entries[index] = previousEntry
                } else {
                    snapshot.entries.remove(at: index)
                }
                didRestore = true
            }
            return didRestore
        } catch {
            return false
        }
    }

    private func makeMissionRollbackState(for localDateString: String) async throws -> MissionRollbackState {
        MissionRollbackState(
            localDateString: localDateString,
            previousMission: try await missionRepository.store.load().missionHistory.first {
                $0.localDateString == localDateString
            }
        )
    }

    private func restoreMissionRollbackState(
        _ state: MissionRollbackState,
        replacing writtenMission: DailyMission
    ) async -> Bool {
        do {
            var didRestore = false
            try await missionRepository.store.update { snapshot in
                guard let index = snapshot.missionHistory.firstIndex(where: {
                    $0.localDateString == state.localDateString
                }), Self.matchesForRollback(snapshot.missionHistory[index], writtenMission) else {
                    return
                }

                if let previousMission = state.previousMission {
                    snapshot.missionHistory[index] = previousMission
                } else {
                    snapshot.missionHistory.remove(at: index)
                }
                didRestore = true
            }
            return didRestore
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
        let localDateString: String
        let previousEntry: DailyPhotoEntry?
    }

    private struct MissionRollbackState {
        let localDateString: String
        let previousMission: DailyMission?
    }

    private static func matchesForRollback(_ lhs: DailyPhotoEntry, _ rhs: DailyPhotoEntry) -> Bool {
        lhs.id == rhs.id
            && lhs.localDateString == rhs.localDateString
            && lhs.createdAtUTC == rhs.createdAtUTC
            && lhs.updatedAtUTC == rhs.updatedAtUTC
            && lhs.timezoneIdentifier == rhs.timezoneIdentifier
            && lhs.timezoneOffsetMinutes == rhs.timezoneOffsetMinutes
            && lhs.imageLocalPath == rhs.imageLocalPath
            && lhs.thumbnailLocalPath == rhs.thumbnailLocalPath
            && lhs.memo == rhs.memo
            && lhs.moodCode == rhs.moodCode
            && lhs.missionId == rhs.missionId
            && lhs.missionCompleted == rhs.missionCompleted
            && lhs.sourceType == rhs.sourceType
            && lhs.isDeleted == rhs.isDeleted
    }

    private static func matchesForRollback(_ lhs: DailyMission, _ rhs: DailyMission) -> Bool {
        lhs.id == rhs.id
            && lhs.localDateString == rhs.localDateString
            && lhs.templateID == rhs.templateID
            && lhs.title == rhs.title
            && lhs.prompt == rhs.prompt
            && lhs.category == rhs.category
            && lhs.symbolName == rhs.symbolName
            && lhs.createdAtUTC == rhs.createdAtUTC
            && lhs.completedAtUTC == rhs.completedAtUTC
    }

    private static func returnMessage(for currentStreak: Int) -> String {
        if currentStreak <= 0 {
            return L10n.string("editor.completion.saved_message")
        }

        if currentStreak == 1 {
            return L10n.string("editor.completion.return_first")
        }

        return L10n.format("editor.completion.return_next", currentStreak + 1)
    }
}

struct EntryCompletionSummary: Equatable {
    let outcome: EntrySaveOutcome
    let confirmedCurrentStreak: Int?
    let missionTitle: String?
    let missionCompleted: Bool?
    let returnMessage: String
}

enum EntrySaveOutcome: Equatable {
    case created
    case updated
}
