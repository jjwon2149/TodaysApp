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
    @Published private(set) var completionSummary: EntryCompletionSummary?

    let moodOptions = ["좋음", "평온", "피곤", "설렘", "복잡", "그저 그럼"]

    var saveButtonTitle: String {
        existingEntry == nil ? "오늘의 한 장으로 저장" : "변경사항 저장"
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

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "선택한 사진을 불러오지 못했습니다."
                return
            }

            previewImage = image
            imageData = image.jpegData(compressionQuality: 0.86) ?? data
            imageSourceType = "library"
        } catch {
            errorMessage = "사진을 가져오는 중 오류가 발생했습니다."
        }
    }

    func loadCapturedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.86) else {
            errorMessage = "촬영한 사진을 처리하지 못했습니다. 다시 촬영하거나 앨범에서 선택해주세요."
            return
        }

        previewImage = image
        imageData = data
        imageSourceType = "camera"
    }

    func handleCameraCaptureFailure(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func saveEntry() async -> Bool {
        guard isSaving == false else { return false }

        isSaving = true
        completionSummary = nil
        defer { isSaving = false }

        do {
            let dayKey = existingEntry?.localDateString ?? DailyFrameDateFormatter.localDateString(from: .now)
            let storedPath: String
            let thumbnailPath: String?
            var createdPaths: [String] = []

            if let imageData {
                let fileID = UUID().uuidString
                let storedImage = try imageStorageService.saveEntryImageData(
                    imageData,
                    imageFileName: "\(dayKey)-\(fileID).jpg",
                    thumbnailFileName: "\(dayKey)-\(fileID)-thumbnail.jpg"
                )
                storedPath = storedImage.imageURL.path
                thumbnailPath = storedImage.thumbnailURL.path
                createdPaths = [storedImage.imageURL.path, storedImage.thumbnailURL.path]
            } else if let existingPath = existingEntry?.imageLocalPath {
                storedPath = existingPath

                if let existingThumbnailPath = existingEntry?.thumbnailLocalPath {
                    thumbnailPath = existingThumbnailPath
                } else {
                    let fileName = "\(dayKey)-\(UUID().uuidString)-thumbnail.jpg"
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
                errorMessage = "저장하려면 먼저 사진을 선택해주세요."
                return false
            }

            var entryRollbackState: EntryRollbackState?
            var didUpsertEntry = false

            do {
                entryRollbackState = try await makeEntryRollbackState()
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
                entry.missionId = mission.id
                entry.missionCompleted = true
                entry.sourceType = imageSourceType

                try await entryRepository.upsert(entry)
                didUpsertEntry = true
                let completedMission = try await missionService.completeMission(for: dayKey)
                try await streakService.recordCompletion(for: dayKey)

                deleteReplacedImageFiles(newImagePath: storedPath, newThumbnailPath: thumbnailPath)

                let streakState = (try? await streakStateRepository.fetchPrimaryState()) ?? StreakState(
                    currentStreak: 1,
                    longestStreak: 1,
                    lastCompletedLocalDateString: dayKey
                )
                completionSummary = EntryCompletionSummary(
                    currentStreak: max(streakState.currentStreak, 1),
                    missionTitle: completedMission.title,
                    missionCompleted: completedMission.isCompleted,
                    rewardText: "+20 XP",
                    returnMessage: Self.returnMessage(for: max(streakState.currentStreak, 1))
                )
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
            errorMessage = "기록을 저장하는 중 오류가 발생했습니다."
            return false
        }
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
            return "내일 다시 한 장을 남기면 2일 스트릭이 시작됩니다."
        }

        return "내일 한 장을 더 남기면 \(currentStreak + 1)일 스트릭으로 이어집니다."
    }
}

struct EntryCompletionSummary: Equatable {
    let currentStreak: Int
    let missionTitle: String
    let missionCompleted: Bool
    let rewardText: String
    let returnMessage: String
}
