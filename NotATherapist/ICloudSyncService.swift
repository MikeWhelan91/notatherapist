import CloudKit
import Foundation

final class ICloudSyncService {
    static let shared = ICloudSyncService()

    private let container = CKContainer.default()
    private let recordID = CKRecord.ID(recordName: "app-snapshot")
    private let recordType = "AppSnapshot"

    private init() {}

    func accountStatus() async -> ICloudSyncState {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available: return .available
            case .noAccount: return .unavailable("No iCloud account")
            case .restricted: return .unavailable("iCloud restricted")
            case .couldNotDetermine: return .unavailable("Could not check iCloud")
            case .temporarilyUnavailable: return .unavailable("iCloud temporarily unavailable")
            @unknown default: return .unavailable("iCloud unavailable")
            }
        } catch {
            return .unavailable("iCloud unavailable")
        }
    }

    func push(_ snapshot: AppSnapshot) async throws -> Date {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let database = container.privateCloudDatabase
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        let now = Date()
        record["payload"] = data as NSData
        record["updatedAt"] = now as NSDate
        _ = try await database.save(record)
        return now
    }

    func pull() async throws -> AppSnapshot? {
        let record = try await container.privateCloudDatabase.record(for: recordID)
        let payload = record["payload"]
        let data: Data
        if let storedData = payload as? Data {
            data = storedData
        } else if let storedData = payload as? NSData {
            data = storedData as Data
        } else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppSnapshot.self, from: data)
    }
}
