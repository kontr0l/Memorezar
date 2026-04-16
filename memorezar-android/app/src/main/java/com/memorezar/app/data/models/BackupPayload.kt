package com.memorezar.app.data.models

import kotlinx.serialization.Serializable

/**
 * Complete snapshot of all user data for cloud backup/restore.
 * Encoded as a single JSONB blob in the `user_backups` Supabase table.
 */
@Serializable
data class BackupPayload(
    val backupVersion: Int = CURRENT_VERSION,
    val createdAt: Long = System.currentTimeMillis(),

    // Quotes & Library
    val quotes: List<Quote> = emptyList(),
    val sessions: List<PracticeSession> = emptyList(),
    val categories: List<QuoteCategory> = emptyList(),
    val packVersions: Map<String, Int> = emptyMap(),

    // Settings & Preferences
    val settings: AppSettings = AppSettings.Default,

    // User State
    val userEquivalences: Map<String, List<String>> = emptyMap(),
    val completedTips: List<String> = emptyList(),
    val hasCompletedOnboarding: Boolean = false,

    // Category images (Android uses coverImageUrl, no local file upload needed)
    val categoryImageManifest: List<CategoryImageEntry> = emptyList(),

    // Local Recordings (v2+). Older v1 backups decode with these defaults.
    val localRecordings: List<LocalRecording> = emptyList(),
    val recordingAudioManifest: List<RecordingAudioEntry> = emptyList()
) {
    companion object {
        const val CURRENT_VERSION = 2
    }
}

@Serializable
data class CategoryImageEntry(
    val categoryId: String,
    val localFilename: String = "",
    val remoteStoragePath: String = ""
)

/**
 * Maps a local recording to its backed-up audio file in the private
 * `recording-backups` Supabase Storage bucket. Mirrors the iOS
 * RecordingAudioEntry struct.
 */
@Serializable
data class RecordingAudioEntry(
    val recordingId: String,
    val localFileName: String,
    val remoteStoragePath: String
)
