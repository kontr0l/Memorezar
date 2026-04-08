package com.memorezar.app.data.services

import android.util.Log
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.patch
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

@Serializable
private data class EquivalenceRow(
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
     * Report a user-accepted word equivalence (fire-and-forget upsert).
     * On 409 conflict, increments the report_count.
     */
    suspend fun reportEquivalence(expected: String, spoken: String) {
        val normalizedExpected = normalize(expected)
        val normalizedSpoken = normalize(spoken)
        if (normalizedExpected == normalizedSpoken) return

        try {
            val response = httpClient.post(SupabaseConfig.EQUIVALENCES_URL) {
                for ((k, v) in authService.headers()) header(k, v)
                contentType(ContentType.Application.Json)
                setBody("""{"expected_word":"$normalizedExpected","spoken_word":"$normalizedSpoken","report_count":1}""")
            }
            if (response.status.value == 409) {
                // Conflict — increment report count
                incrementReportCount(normalizedExpected, normalizedSpoken)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to report equivalence: ${e.message}")
        }
    }

    /**
     * Fetch community equivalences for the given words.
     * Returns map of expected_word -> set of spoken_word equivalences.
     */
    suspend fun fetchEquivalences(forWords: List<String>): Map<String, Set<String>> {
        if (forWords.isEmpty()) return emptyMap()
        return try {
            val wordList = forWords.joinToString(",") { normalize(it) }
            val url = "${SupabaseConfig.EQUIVALENCES_URL}?expected_word=in.($wordList)&select=expected_word,spoken_word"
            val response = httpClient.get(url) {
                for ((k, v) in authService.headers()) header(k, v)
            }
            if (!response.status.isSuccess()) return emptyMap()

            val body: String = response.body()
            val rows = json.decodeFromString<List<EquivalenceRow>>(body)
            val result = mutableMapOf<String, MutableSet<String>>()
            for (row in rows) {
                result.getOrPut(row.expected_word) { mutableSetOf() }.add(row.spoken_word)
            }
            result
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch equivalences: ${e.message}")
            emptyMap()
        }
    }

    private suspend fun incrementReportCount(expected: String, spoken: String) {
        try {
            // Fetch current count
            val fetchUrl = "${SupabaseConfig.EQUIVALENCES_URL}?expected_word=eq.$expected&spoken_word=eq.$spoken&select=report_count"
            val fetchResponse = httpClient.get(fetchUrl) {
                for ((k, v) in authService.headers()) header(k, v)
            }
            if (!fetchResponse.status.isSuccess()) return

            val body: String = fetchResponse.body()
            val rows = json.decodeFromString<List<EquivalenceRow>>(body)
            val currentCount = rows.firstOrNull()?.report_count ?: 1

            // Patch with incremented count
            val patchUrl = "${SupabaseConfig.EQUIVALENCES_URL}?expected_word=eq.$expected&spoken_word=eq.$spoken"
            httpClient.patch(patchUrl) {
                for ((k, v) in authService.headers()) header(k, v)
                contentType(ContentType.Application.Json)
                setBody("""{"report_count":${currentCount + 1}}""")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to increment report count: ${e.message}")
        }
    }

    private fun normalize(word: String): String {
        return word.lowercase().replace(Regex("[^\\p{L}\\p{N}']"), "")
    }
}
