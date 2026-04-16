package com.memorezar.app.data.services

import android.util.Log
import com.memorezar.app.data.models.Recording
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.serialization.json.Json
import java.security.MessageDigest
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "RecordingService"

@Singleton
class RecordingService @Inject constructor(
    private val httpClient: HttpClient,
    private val authService: AuthService
) {
    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Normalize quote text and produce a SHA-256 hash for matching recordings.
     * Must match iOS implementation exactly for cross-platform sync.
     */
    fun hashQuoteText(text: String): String {
        val normalized = text.lowercase()
            .replace(Regex("[\\p{Punct}]"), "")
            .trim()
            .split("\\s+".toRegex())
            .filter { it.isNotEmpty() }
            .joinToString(" ")
        val bytes = MessageDigest.getInstance("SHA-256").digest(normalized.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }

    /**
     * Fetch community recordings for a quote by its SHA256 text hash.
     */
    suspend fun fetchRecordings(quoteTextHash: String): List<Recording> {
        return try {
            val url = "${SupabaseConfig.RECORDINGS_URL}?quote_text_hash=eq.$quoteTextHash&select=*&order=created_at.desc"
            val response = httpClient.get(url) {
                for ((k, v) in authService.headers()) header(k, v)
            }
            if (!response.status.isSuccess()) return emptyList()
            val body: String = response.body()
            json.decodeFromString<List<Recording>>(body)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch recordings: ${e.message}")
            emptyList()
        }
    }

    /**
     * Upload a community recording to Supabase Storage, then insert a row in the recordings table.
     */
    suspend fun uploadRecording(
        audioData: ByteArray,
        quoteTextHash: String,
        quoteTitle: String,
        durationSeconds: Double,
        language: String = "en"
    ) {
        val user = authService.currentUser.value ?: throw Exception("Must be signed in to upload")

        // 1. Upload audio file to Storage
        val fileName = "${quoteTextHash}_${user.id}_${System.currentTimeMillis()}.m4a"
        val storagePath = "$quoteTextHash/$fileName"

        val uploadResponse: HttpResponse = httpClient.post(
            "${SupabaseConfig.STORAGE_URL}/$storagePath"
        ) {
            // Skip Content-Type from authService.headers() — Ktor's `header()`
            // appends rather than replaces, so looping in our default JSON
            // Content-Type and then adding "audio/mp4" produces a duplicate
            // Content-Type header. Supabase Storage 400s on that, and the
            // upload silently fails (which is why "share with community" didn't
            // surface recordings in the community tab).
            for ((k, v) in authService.headers()) {
                if (!k.equals("Content-Type", ignoreCase = true)) header(k, v)
            }
            header("Content-Type", "audio/mp4")
            setBody(audioData)
        }
        if (!uploadResponse.status.isSuccess()) {
            throw Exception("Failed to upload recording (${uploadResponse.status.value})")
        }

        // 2. Insert recording metadata row
        val uploaderName = user.displayName ?: user.email ?: "Anonymous"
        val metaBody = buildString {
            append("{")
            append(""""quote_text_hash":"$quoteTextHash",""")
            append(""""quote_title":"${quoteTitle.replace("\"", "\\\"")}",""")
            append(""""uploader_name":"${uploaderName.replace("\"", "\\\"")}",""")
            append(""""file_path":"$storagePath",""")
            append(""""duration_seconds":$durationSeconds,""")
            append(""""language":"$language",""")
            append(""""user_id":"${user.id}"""")
            append("}")
        }

        val metaResponse: HttpResponse = httpClient.post(SupabaseConfig.RECORDINGS_URL) {
            for ((k, v) in authService.headers()) header(k, v)
            header("Prefer", "return=minimal")
            contentType(ContentType.Application.Json)
            setBody(metaBody)
        }
        if (!metaResponse.status.isSuccess()) {
            throw Exception("Failed to save recording metadata (${metaResponse.status.value})")
        }
    }

    /**
     * Look up the signed-in user's own community recording for the given quote
     * hash + language, if any. Used by the edit sheet to determine whether the
     * recording is currently public.
     */
    suspend fun fetchMyRecording(quoteTextHash: String, language: String): Recording? {
        val userId = authService.currentUser.value?.id ?: return null
        return try {
            val url = "${SupabaseConfig.RECORDINGS_URL}" +
                "?quote_text_hash=eq.$quoteTextHash" +
                "&language=eq.$language" +
                "&user_id=eq.$userId" +
                "&select=*&limit=1"
            val response = httpClient.get(url) {
                for ((k, v) in authService.headers()) header(k, v)
            }
            if (!response.status.isSuccess()) return null
            val body: String = response.body()
            json.decodeFromString<List<Recording>>(body).firstOrNull()
        } catch (e: Exception) {
            Log.w(TAG, "fetchMyRecording failed: ${e.message}")
            null
        }
    }

    /**
     * Remove the caller's own community recording: delete the audio file from
     * Storage, then delete the recordings row. Used when the user toggles a
     * previously-public recording back to private.
     */
    suspend fun deleteMyRecording(recording: Recording) {
        // 1. Delete audio file from Storage.
        try {
            val storageDelete: HttpResponse = httpClient.delete(
                "${SupabaseConfig.STORAGE_URL}/${recording.filePath}"
            ) {
                for ((k, v) in authService.headers()) header(k, v)
            }
            if (!storageDelete.status.isSuccess()) {
                Log.w(TAG, "Storage delete returned ${storageDelete.status.value}")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Storage delete failed: ${e.message}")
        }
        // 2. Delete recordings row. RLS ensures we can only delete our own.
        val rowDelete: HttpResponse = httpClient.delete(
            "${SupabaseConfig.RECORDINGS_URL}?id=eq.${recording.id}"
        ) {
            for ((k, v) in authService.headers()) header(k, v)
        }
        if (!rowDelete.status.isSuccess()) {
            throw Exception("Failed to delete recording row (${rowDelete.status.value})")
        }
    }

    /** Get the public URL for a recording file path. */
    fun publicURL(filePath: String): String {
        return SupabaseConfig.publicFileURL(filePath)
    }

    /** Download audio data from a community recording file path. */
    suspend fun downloadAudio(filePath: String): ByteArray? {
        return try {
            val url = publicURL(filePath)
            val response = httpClient.get(url)
            if (!response.status.isSuccess()) return null
            response.body<ByteArray>()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to download audio: ${e.message}")
            null
        }
    }
}
