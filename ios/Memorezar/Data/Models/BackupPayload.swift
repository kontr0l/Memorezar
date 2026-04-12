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

    // MARK: - Current Version

    static let currentVersion = 1
}

/// Maps a category's local image file to its remote Supabase Storage path.
struct CategoryImageEntry: Codable {
    let categoryId: String  // UUID as string
    let localFilename: String
    let remoteStoragePath: String
}
