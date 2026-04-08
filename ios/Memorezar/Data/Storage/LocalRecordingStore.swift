import Foundation
import SwiftUI

/// Persists locally-stored audio recordings (private recordings + saved community favorites).
/// Audio files are stored in Documents/recordings/; metadata is persisted via UserDefaults.
final class LocalRecordingStore: ObservableObject {

    @Published private(set) var recordings: [LocalRecording] = []

    private let storageKey = "memorezar_local_recordings"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadRecordings()
    }

    // MARK: - Directory

    private var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Public Methods

    /// Save a recording locally. Returns the created LocalRecording, or nil on failure.
    @discardableResult
    func saveRecording(
        audioData: Data,
        quoteTextHash: String,
        quoteTitle: String,
        duration: Double,
        isFavorite: Bool = false,
        sourceRecordingId: UUID? = nil,
        uploaderName: String? = nil,
        originalDate: Date? = nil,
        name: String? = nil,
        quoteId: UUID? = nil,
        language: String = "en"
    ) -> LocalRecording? {
        let fileName = "\(UUID().uuidString).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)

        do {
            try audioData.write(to: fileURL)
        } catch {
            print("[LocalRecordingStore] Failed to write audio file: \(error)")
            return nil
        }

        let recording = LocalRecording(
            quoteTextHash: quoteTextHash,
            quoteTitle: quoteTitle,
            localFileName: fileName,
            durationSeconds: duration,
            createdAt: originalDate ?? Date(),
            isFavorite: isFavorite,
            sourceRecordingId: sourceRecordingId,
            uploaderName: uploaderName,
            name: name,
            quoteId: quoteId,
            language: language
        )

        recordings.append(recording)
        save()
        return recording
    }

    /// Update a recording's name
    func updateRecordingName(_ recording: LocalRecording, name: String) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        recordings[index].name = name
        save()
    }

    /// Delete a local recording (removes both the file and metadata)
    func deleteRecording(_ recording: LocalRecording) {
        let fileURL = recordingsDirectory.appendingPathComponent(recording.localFileName)
        try? FileManager.default.removeItem(at: fileURL)

        recordings.removeAll { $0.id == recording.id }
        save()
    }

    /// Get recordings for a specific quote hash
    func recordings(forHash hash: String) -> [LocalRecording] {
        recordings.filter { $0.quoteTextHash == hash }
    }

    /// Get all recordings for a quote across all languages.
    /// Falls back to hash-based lookup for older recordings without a quoteId.
    func recordings(forQuoteId quoteId: UUID, allHashes: Set<String>) -> [LocalRecording] {
        recordings.filter { rec in
            rec.quoteId == quoteId || allHashes.contains(rec.quoteTextHash)
        }
    }

    /// Move recordings within a specific quote hash group
    func moveRecording(forHash hash: String, from source: IndexSet, to destination: Int) {
        var subset = recordings(forHash: hash)
        subset.move(fromOffsets: source, toOffset: destination)
        // Rebuild: remove old entries for this hash, insert reordered ones at the same position
        let firstIndex = recordings.firstIndex { $0.quoteTextHash == hash } ?? recordings.endIndex
        recordings.removeAll { $0.quoteTextHash == hash }
        recordings.insert(contentsOf: subset, at: min(firstIndex, recordings.endIndex))
        save()
    }

    /// Load audio data for a recording
    func loadAudioData(for recording: LocalRecording) -> Data? {
        let fileURL = recordingsDirectory.appendingPathComponent(recording.localFileName)
        return try? Data(contentsOf: fileURL)
    }

    // MARK: - Persistence

    private func loadRecordings() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        do {
            recordings = try JSONDecoder().decode([LocalRecording].self, from: data)
        } catch {
            print("[LocalRecordingStore] Failed to load recordings: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(recordings)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("[LocalRecordingStore] Failed to save recordings: \(error)")
        }
    }
}
