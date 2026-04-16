import Foundation

/// Complete snapshot of all user data for cloud backup/restore.
/// Encoded as a single JSONB blob in the `user_backups` Supabase table.
struct BackupPayload: Codable {
    /// Schema version — increment when adding fields so older clients
    /// can gracefully decode newer backups (all fields should be optional
    /// or have defaults in the decoder).
    let backupVersion: Int

    /// When this snapshot was created.
    let createdAt: Date

    // MARK: - Quotes & Library

    let quotes: [Quote]
    let sessions: [PracticeSession]
    let categories: [QuoteCategory]
    let packVersions: [String: Int]

    // MARK: - Settings & Preferences

    let settings: AppSettings

    // MARK: - User State

    /// Word equivalences the user has taught the app.
    /// Stored as `[String: [String]]` (arrays, not sets) for stable JSON encoding.
    let userEquivalences: [String: [String]]

    /// Tip IDs the user has dismissed.
    let completedTips: [String]

    /// Whether the user has completed the initial onboarding flow.
    let hasCompletedOnboarding: Bool

    // MARK: - Category Images

    /// Maps local category image filenames to their remote storage paths.
    /// Used during restore to download images back to the device.
    let categoryImageManifest: [CategoryImageEntry]

    // MARK: - Local Recordings (v2+)

    /// The full LocalRecording metadata array. Older backups (v1) don't
    /// include this; decoder defaults to empty.
    let localRecordings: [LocalRecording]

    /// Maps each local recording to its uploaded audio file in the
    /// private `recording-backups` Supabase Storage bucket.
    let recordingAudioManifest: [RecordingAudioEntry]

    // MARK: - Current Version

    static let currentVersion = 2

    // MARK: - Codable

    /// Backward-compatible decoding for v1 backups (no localRecordings /
    /// recordingAudioManifest).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        backupVersion = try c.decode(Int.self, forKey: .backupVersion)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        quotes = try c.decode([Quote].self, forKey: .quotes)
        sessions = try c.decode([PracticeSession].self, forKey: .sessions)
        categories = try c.decode([QuoteCategory].self, forKey: .categories)
        packVersions = try c.decode([String: Int].self, forKey: .packVersions)
        settings = try c.decode(AppSettings.self, forKey: .settings)
        userEquivalences = try c.decode([String: [String]].self, forKey: .userEquivalences)
        completedTips = try c.decode([String].self, forKey: .completedTips)
        hasCompletedOnboarding = try c.decode(Bool.self, forKey: .hasCompletedOnboarding)
        categoryImageManifest = try c.decode([CategoryImageEntry].self, forKey: .categoryImageManifest)
        localRecordings = try c.decodeIfPresent([LocalRecording].self, forKey: .localRecordings) ?? []
        recordingAudioManifest = try c.decodeIfPresent([RecordingAudioEntry].self, forKey: .recordingAudioManifest) ?? []
    }

    init(
        backupVersion: Int,
        createdAt: Date,
        quotes: [Quote],
        sessions: [PracticeSession],
        categories: [QuoteCategory],
        packVersions: [String: Int],
        settings: AppSettings,
        userEquivalences: [String: [String]],
        completedTips: [String],
        hasCompletedOnboarding: Bool,
        categoryImageManifest: [CategoryImageEntry],
        localRecordings: [LocalRecording] = [],
        recordingAudioManifest: [RecordingAudioEntry] = []
    ) {
        self.backupVersion = backupVersion
        self.createdAt = createdAt
        self.quotes = quotes
        self.sessions = sessions
        self.categories = categories
        self.packVersions = packVersions
        self.settings = settings
        self.userEquivalences = userEquivalences
        self.completedTips = completedTips
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.categoryImageManifest = categoryImageManifest
        self.localRecordings = localRecordings
        self.recordingAudioManifest = recordingAudioManifest
    }
}

/// Maps a category's local image file to its remote Supabase Storage path.
struct CategoryImageEntry: Codable {
    let categoryId: String  // UUID as string
    let localFilename: String
    let remoteStoragePath: String
}

/// Maps a local recording to its backed-up audio file in Supabase Storage.
/// The remote path is relative to the `recording-backups` bucket.
struct RecordingAudioEntry: Codable {
    let recordingId: String      // LocalRecording.id as UUID string
    let localFileName: String    // matches LocalRecording.localFileName
    let remoteStoragePath: String
}
