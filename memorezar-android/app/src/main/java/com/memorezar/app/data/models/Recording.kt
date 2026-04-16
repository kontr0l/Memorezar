package com.memorezar.app.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class Recording(
    val id: String,
    @SerialName("quote_text_hash")
    val quoteTextHash: String,
    @SerialName("quote_title")
    val quoteTitle: String,
    @SerialName("uploader_name")
    val uploaderName: String,
    @SerialName("file_path")
    val filePath: String,
    @SerialName("duration_seconds")
    val durationSeconds: Double? = null,
    @SerialName("created_at")
    val createdAt: String,
    val language: String = "en",
    @SerialName("user_id")
    val userId: String? = null
)

@Serializable
data class LocalRecording(
    val id: String = UUID.randomUUID().toString(),
    val quoteTextHash: String,
    val quoteTitle: String,
    val localFileName: String,
    val durationSeconds: Double,
    val createdAt: Long = System.currentTimeMillis(),
    val isFavorite: Boolean = false,
    val sourceRecordingId: String? = null,
    val uploaderName: String? = null,
    val name: String? = null,
    val quoteId: String? = null,
    val language: String = "en",
    /** Authoritative 1:1 link to the Supabase `recordings` row when this local
     *  has been published to the community. null = private/local-only. Set on
     *  successful upload, cleared on unshare/replace/delete. Replaces the old
     *  fuzzy "does the user have any community row in this language" check. */
    val communityRecordingId: String? = null
)
