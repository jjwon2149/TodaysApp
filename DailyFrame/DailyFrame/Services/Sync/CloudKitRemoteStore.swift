import CloudKit
import Foundation

final class CloudKitRemoteStore: CloudSyncRemoteStore {
    private enum RecordType {
        static let entry = "DFEntry"
        static let media = "DFEntryMedia"
    }

    private enum Field {
        static let localDateString = "localDateString"
        static let updatedAtUTC = "updatedAtUTC"
        static let createdAtUTC = "createdAtUTC"
        static let timezoneIdentifier = "timezoneIdentifier"
        static let timezoneOffsetMinutes = "timezoneOffsetMinutes"
        static let memo = "memo"
        static let moodCode = "moodCode"
        static let missionId = "missionId"
        static let missionCompleted = "missionCompleted"
        static let sourceType = "sourceType"
        static let isDeleted = "isDeleted"
        static let entry = "entry"
        static let role = "role"
        static let asset = "asset"
        static let fileName = "fileName"
    }

    private let container: CKContainer
    private let database: CKDatabase

    init(container: CKContainer = .default()) {
        self.container = container
        self.database = container.privateCloudDatabase
    }

    func accountState() async throws -> CloudSyncAccountState {
        let status = try await cloudAccountStatus()

        switch status {
        case .available:
            return .available
        case .noAccount:
            return .unavailable(.noAccount)
        case .restricted:
            return .unavailable(.restricted)
        case .couldNotDetermine:
            return .unavailable(.couldNotDetermine)
        case .temporarilyUnavailable:
            return .unavailable(.temporarilyUnavailable)
        @unknown default:
            return .unavailable(.unknown)
        }
    }

    func fetchEntries() async throws -> [CloudSyncEntryRecord] {
        let records = try await fetchRecords(recordType: RecordType.entry)
        return records.compactMap(makeEntryRecord)
    }

    func fetchMedia() async throws -> [CloudSyncMediaAsset] {
        let records = try await fetchRecords(recordType: RecordType.media)
        return records.compactMap(makeMediaAsset)
    }

    func save(entry: CloudSyncEntryRecord) async throws {
        let recordID = CKRecord.ID(recordName: Self.entryRecordName(for: entry.localDateString))
        let record = try await fetchRecord(with: recordID) ?? CKRecord(recordType: RecordType.entry, recordID: recordID)

        record[Field.localDateString] = entry.localDateString as CKRecordValue
        record[Field.updatedAtUTC] = entry.updatedAtUTC as CKRecordValue
        record[Field.createdAtUTC] = entry.createdAtUTC as CKRecordValue
        record[Field.timezoneIdentifier] = entry.timezoneIdentifier as CKRecordValue
        record[Field.timezoneOffsetMinutes] = NSNumber(value: entry.timezoneOffsetMinutes)
        record[Field.memo] = entry.memo as CKRecordValue?
        record[Field.moodCode] = entry.moodCode as CKRecordValue?
        record[Field.missionId] = entry.missionId as CKRecordValue?
        record[Field.missionCompleted] = NSNumber(value: entry.missionCompleted)
        record[Field.sourceType] = entry.sourceType as CKRecordValue
        record[Field.isDeleted] = NSNumber(value: entry.isDeleted)

        try await saveRecords([record])
    }

    func save(media: CloudSyncMediaAsset) async throws {
        guard let assetFileURL = media.assetFileURL else {
            return
        }

        let recordID = CKRecord.ID(recordName: Self.mediaRecordName(
            localDateString: media.localDateString,
            role: media.role
        ))
        let record = try await fetchRecord(with: recordID) ?? CKRecord(recordType: RecordType.media, recordID: recordID)
        let entryRecordID = CKRecord.ID(recordName: Self.entryRecordName(for: media.localDateString))

        record[Field.entry] = CKRecord.Reference(recordID: entryRecordID, action: .none)
        record[Field.role] = media.role.rawValue as CKRecordValue
        record[Field.asset] = CKAsset(fileURL: assetFileURL)
        record[Field.fileName] = media.fileName as CKRecordValue
        record[Field.updatedAtUTC] = media.updatedAtUTC as CKRecordValue

        try await saveRecords([record])
    }

    private func cloudAccountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private func fetchRecord(with recordID: CKRecord.ID) async throws -> CKRecord? {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    continuation.resume(returning: nil)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: record)
                }
            }
        }
    }

    private func fetchRecords(recordType: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        var operation: CKQueryOperation? = CKQueryOperation(query: query)
        var records: [CKRecord] = []

        while let currentOperation = operation {
            currentOperation.resultsLimit = CKQueryOperation.maximumResults
            let page = try await runQueryOperation(currentOperation)
            records.append(contentsOf: page.records)

            if let cursor = page.cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = nil
            }
        }

        return records
    }

    private func runQueryOperation(_ operation: CKQueryOperation) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            var records: [CKRecord] = []
            var recordError: Error?
            let lock = NSLock()

            operation.recordMatchedBlock = { _, result in
                lock.lock()
                defer { lock.unlock() }

                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    if recordError == nil {
                        recordError = error
                    }
                }
            }

            operation.queryResultBlock = { result in
                lock.lock()
                let fetchedRecords = records
                let fetchedRecordError = recordError
                lock.unlock()

                if let fetchedRecordError {
                    continuation.resume(throwing: fetchedRecordError)
                    return
                }

                switch result {
                case .success(let cursor):
                    continuation.resume(returning: (fetchedRecords, cursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func saveRecords(_ records: [CKRecord]) async throws {
        guard records.isEmpty == false else {
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.isAtomic = false
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func makeEntryRecord(from record: CKRecord) -> CloudSyncEntryRecord? {
        guard let localDateString = record[Field.localDateString] as? String,
              let updatedAtUTC = record[Field.updatedAtUTC] as? Date,
              let createdAtUTC = record[Field.createdAtUTC] as? Date,
              let timezoneIdentifier = record[Field.timezoneIdentifier] as? String,
              let timezoneOffsetMinutes = record[Field.timezoneOffsetMinutes] as? NSNumber,
              let missionCompleted = record[Field.missionCompleted] as? NSNumber,
              let sourceType = record[Field.sourceType] as? String,
              let isDeleted = record[Field.isDeleted] as? NSNumber
        else {
            return nil
        }

        return CloudSyncEntryRecord(
            localDateString: localDateString,
            createdAtUTC: createdAtUTC,
            updatedAtUTC: updatedAtUTC,
            timezoneIdentifier: timezoneIdentifier,
            timezoneOffsetMinutes: timezoneOffsetMinutes.intValue,
            memo: record[Field.memo] as? String,
            moodCode: record[Field.moodCode] as? String,
            missionId: record[Field.missionId] as? String,
            missionCompleted: missionCompleted.boolValue,
            sourceType: sourceType,
            isDeleted: isDeleted.boolValue
        )
    }

    private func makeMediaAsset(from record: CKRecord) -> CloudSyncMediaAsset? {
        let parsedIdentity = Self.parseMediaRecordName(record.recordID.recordName)

        guard let localDateString = parsedIdentity?.localDateString,
              let role = parsedIdentity?.role ?? CloudSyncMediaRole(rawValue: record[Field.role] as? String ?? ""),
              let fileName = record[Field.fileName] as? String,
              let updatedAtUTC = record[Field.updatedAtUTC] as? Date
        else {
            return nil
        }

        let asset = record[Field.asset] as? CKAsset
        return CloudSyncMediaAsset(
            localDateString: localDateString,
            role: role,
            fileName: fileName,
            updatedAtUTC: updatedAtUTC,
            assetFileURL: asset?.fileURL
        )
    }

    private static func entryRecordName(for localDateString: String) -> String {
        "entry:\(localDateString)"
    }

    private static func mediaRecordName(localDateString: String, role: CloudSyncMediaRole) -> String {
        "entry-media:\(localDateString):\(role.rawValue)"
    }

    private static func parseMediaRecordName(_ recordName: String) -> (localDateString: String, role: CloudSyncMediaRole)? {
        let components = recordName.split(separator: ":").map(String.init)

        guard components.count == 3,
              components[0] == "entry-media",
              let role = CloudSyncMediaRole(rawValue: components[2])
        else {
            return nil
        }

        return (components[1], role)
    }
}
