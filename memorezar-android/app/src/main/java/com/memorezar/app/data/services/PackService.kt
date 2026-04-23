package com.memorezar.app.data.services

import android.util.Log
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.models.QuoteCategory
import com.memorezar.app.data.models.SuggestionPack
import com.memorezar.app.data.models.SuggestionQuote
import com.memorezar.app.data.models.TranslatedPack
import com.memorezar.app.data.models.TranslatedQuote
import com.memorezar.app.data.storage.QuoteStore
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.http.isSuccess
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "PackService"

@Serializable
private data class RemoteQuoteRow(
    val title: String,
    val text: String,
    val translations: Map<String, TranslatedQuote>? = null
)

@Serializable
private data class RemotePackRow(
    val id: String,
    val name: String,
    val description: String,
    @SerialName("cover_search_query") val coverSearchQuery: String? = null,
    @SerialName("cover_url") val coverURL: String? = null,
    val version: Int? = 1,
    val translations: Map<String, TranslatedPack>? = null,
    @SerialName("is_free") val isFree: Boolean? = true,
    val quotes: List<RemoteQuoteRow> = emptyList()
)

@Singleton
class PackService @Inject constructor(
    private val httpClient: HttpClient,
    private val authService: AuthService
) {
    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Fetch all browsable packs from Supabase.
     * Throws [PackFetchException] so callers can distinguish a network/decode
     * failure from a legitimately empty server response (and retry accordingly).
     */
    suspend fun fetchPacks(): List<SuggestionPack> {
        try {
            val response = httpClient.get(
                "${SupabaseConfig.PACKS_URL}?select=*&order=sort_order.asc"
            ) {
                for ((k, v) in authService.headers()) header(k, v)
            }
            if (!response.status.isSuccess()) {
                throw PackFetchException("HTTP ${response.status.value}")
            }

            val body: String = response.body()
            val rows = json.decodeFromString<List<RemotePackRow>>(body)
            return rows.map { row ->
                SuggestionPack(
                    id = row.id,
                    name = row.name,
                    description = row.description,
                    coverSearchQuery = row.coverSearchQuery ?: "",
                    coverURL = row.coverURL,
                    version = row.version ?: 1,
                    translations = row.translations,
                    isFree = row.isFree ?: true,
                    quotes = row.quotes.map { q ->
                        SuggestionQuote(
                            title = q.title,
                            text = q.text,
                            translations = q.translations
                        )
                    }
                )
            }
        } catch (e: PackFetchException) {
            Log.w(TAG, "Failed to fetch packs: ${e.message}")
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch packs: ${e.message}")
            throw PackFetchException(e.message ?: "unknown", e)
        }
    }

    /**
     * Sync installed packs: if server version > local version, update the category.
     * Also force-syncs all packs once if translations may be missing (migration).
     * @param installedVersions Map of sourcePackId -> local version
     */
    suspend fun syncInstalledPacks(
        installedVersions: Map<String, Int>,
        store: QuoteStore,
        forceAll: Boolean = false
    ) {
        if (installedVersions.isEmpty()) return
        val remotePacks = try {
            fetchPacks()
        } catch (_: PackFetchException) {
            return  // offline — sync will retry on next launch
        }
        for (pack in remotePacks) {
            val localVersion = installedVersions[pack.id] ?: continue
            val remoteVersion = pack.version
            if (forceAll || remoteVersion > localVersion) {
                Log.d(TAG, "Updating pack ${pack.id}: v$localVersion -> v$remoteVersion (force=$forceAll)")
                store.updateInstalledPack(pack)
            }
        }
    }
}

class PackFetchException(message: String, cause: Throwable? = null) : Exception(message, cause)
