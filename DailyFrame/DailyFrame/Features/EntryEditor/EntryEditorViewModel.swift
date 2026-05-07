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
        } catch {
            errorMessage = "사진을 가져오는 중 오류가 발생했습니다."
        }
    }

    func saveEntry() async -> Bool {
        guard isSaving == false else { return false }

        isSaving = true
        completionSummary = nil
        defer { isSaving = false }

        do {
            let dayKey = existingEntry?.localDateString ?? DailyFrameDateFormatter.localDateString(from: .now)
            let storedPath: String

            if let imageData {
                let fileName = "\(dayKey)-\(UUID().uuidString).jpg"
                let fileURL = try imageStorageService.saveImageData(imageData, fileName: fileName)
                storedPath = fileURL.path

                if let oldPath = existingEntry?.imageLocalPath, oldPath != storedPath {
                    try? imageStorageService.deleteFileIfExists(at: oldPath)
                }
            } else if let existingPath = existingEntry?.imageLocalPath {
                storedPath = existingPath
            } else {
                errorMessage = "저장하려면 먼저 사진을 선택해주세요."
                return false
            }

            let mission = try await missionService.mission(for: dayKey)
            var entry = existingEntry ?? DailyPhotoEntry(
                localDateString: dayKey,
                imageLocalPath: storedPath,
                sourceType: "library"
            )

            entry.localDateString = dayKey
            entry.updatedAtUTC = .now
            entry.imageLocalPath = storedPath
            entry.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : memo.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.moodCode = selectedMood
            entry.missionId = mission.id
            entry.missionCompleted = true
            entry.sourceType = "library"

            try await entryRepository.upsert(entry)
            let completedMission = try await missionService.completeMission(for: dayKey)
            try await streakService.recordCompletion(for: dayKey)

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
            return true
        } catch {
            errorMessage = "기록을 저장하는 중 오류가 발생했습니다."
            return false
        }
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
