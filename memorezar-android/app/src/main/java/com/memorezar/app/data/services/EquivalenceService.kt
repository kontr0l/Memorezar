package com.memorezar.app.data.services

import android.util.Log
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "EquivalenceService"

/**
 * Community equivalence fetched from Supabase. Carries the row ID so the
 * ViewModel can batch-report usage at session end.
 */
data class CommunityEquivalence(
    val id: String,
    val expectedWord: String,
    val spokenWord: String
)

@Serializable
private data class EquivalenceRow(
    val id: String? = null,
    val expected_word: String,
    val spoken_word: String,
    val report_count: Int = 1
)

@Singleton
class EquivalenceService @Inject constructor(
    private val httpClient: HttpClient,
    private val authService: AuthService
) {
    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Insert a new equivalence pair (fire-and-forget). A 409 just means the
     * row already exists — usage tracking via [reportUsage] will bump its
     * count separately, so we ignore it.
     */
    suspend fun reportEquivalence(expected: String, spoken: String) {
        val normalizedExpected = normalize(expected)
        val normalizedSpoken = normalize(spoken)
        if (normalizedExpected.isEmpty() || normalizedSpoken.isEmpty()) return
        if (normalizedExpected == normalizedSpoken) return

        try {
            httpClient.post(SupabaseConfig.EQUIVALENCES_URL) {
                for ((k, v) in authService.headers()) header(k, v)
                contentType(ContentType.Application.Json)
                setBody("""{"expected_word":"$normalizedExpected","spoken_word":"$normalizedSpoken","report_count":1}""")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to report equivalence: ${e.message}")
        }
    }

    /**
     * Atomically bump report_count by 1 for every equivalence that matched
     * during a recitation session. Called once at session end with the
     * deduplicated set of matched IDs. Fire-and-forget.
     */
    suspend fun reportUsage(ids: List<String>) {
        if (ids.isEmpty()) return
        try {
            val url = "${SupabaseConfig.PROJECT_URL}/rest/v1/rpc/increment_equivalence_reports"
            val idsJson = ids.joinToString(",") { "\"$it\"" }
            httpClient.post(url) {
                for ((k, v) in authService.headers()) header(k, v)
                contentType(ContentType.Application.Json)
                setBody("""{"ids":[$idsJson]}""")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to report usage: ${e.message}")
        }
    }

    /**
     * Fetch community equivalences for the given words. Returns a list of
     * rows including IDs so callers can batch-report usage later.
     */
    suspend fun fetchEquivalences(forWords: List<String>): List<CommunityEquivalence> {
        if (forWords.isEmpty()) return emptyList()
        // Filter empty normalized tokens (e.g. pure-punctuation words) and dedupe,
        // otherwise `in.(a,,b)` would yield a malformed Supabase filter.
        val normalizedWords = forWords.map { normalize(it) }.filter { it.isNotEmpty() }.distinct()
        if (normalizedWords.isEmpty()) return emptyList()
        return try {
            val wordList = normalizedWords.joinToString(",")
            val url = "${SupabaseConfig.EQUIVALENCES_URL}?expected_word=in.($wordList)&select=id,expected_word,spoken_word"
            val response = httpClient.get(url) {
                for ((k, v) in authService.headers()) header(k, v)
            }
            if (!response.status.isSuccess()) return emptyList()

            val body: String = response.body()
            val rows = json.decodeFromString<List<EquivalenceRow>>(body)
            rows.mapNotNull { row ->
                val id = row.id ?: return@mapNotNull null
                CommunityEquivalence(id, row.expected_word, row.spoken_word)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch equivalences: ${e.message}")
            emptyList()
        }
    }

    private fun normalize(word: String): String {
        return word.lowercase().replace(Regex("[^\\p{L}\\p{N}']"), "")
    }
}
