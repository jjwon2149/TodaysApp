import XCTest
@testable import DailyFrame

@MainActor
final class SyncStatusPresentationTests: XCTestCase {
    func testIncompleteTransferNeverReportsSuccessfulSync() {
        let status = makeStatus(state: .incomplete, skippedMediaCount: 1)
        XCTAssertEqual(
            ProfileViewModel.syncStatusMessage(for: status, policy: .enabled),
            L10n.string("profile.sync.status.incomplete")
        )
    }

    func testLegacySuccessWithMissingMediaAlsoReportsIncomplete() {
        let status = makeStatus(state: .synced, skippedMediaCount: 1)
        XCTAssertEqual(
            ProfileViewModel.syncStatusMessage(for: status, policy: .enabled),
            L10n.string("profile.sync.status.incomplete")
        )
    }

    func testDisabledPolicyTakesPrecedenceOverPriorIncompleteRun() {
        let status = makeStatus(state: .incomplete, skippedMediaCount: 1)
        XCTAssertEqual(
            ProfileViewModel.syncStatusMessage(for: status, policy: .disabled),
            L10n.string("profile.sync.status.disabled")
        )
    }

    private func makeStatus(state: CloudSyncStatus.State, skippedMediaCount: Int) -> CloudSyncStatus {
        CloudSyncStatus(
            state: state,
            lastSyncedAtUTC: nil,
            uploadedEntryCount: 1,
            downloadedEntryCount: 0,
            uploadedMediaCount: 0,
            downloadedMediaCount: 0,
            skippedMediaCount: skippedMediaCount
        )
    }
}
