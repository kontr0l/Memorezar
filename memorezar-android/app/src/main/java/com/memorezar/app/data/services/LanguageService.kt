package com.memorezar.app.data.services

import android.util.Log
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL

/**
 * Mirrors iOS's LanguageService. Fetches per-language colors from the Supabase
 * `languages` table at app start, falling back to hardcoded defaults if offline
 * or before the first fetch returns.
 *
 * Kept as a kotlin `object` (no DI) so the existing `languageColor()` helper in
 * RecitationScreen can read the cached map without plumbing a dependency
 * through every composable.
 */
object LanguageService {

    data class Config(
        val displayName: String,
        val color: Color,
        val textColor: Color,
    )

    private val defaults: Map<String, Config> = mapOf(
        "en" to Config("English", Color(0xFF2196F3), Color.White),
        "es" to Config("Spanish", Color(0xFFFFC107), Color.Black),
        "fr" to Config("French", Color(0xFFF44336), Color.White),
        "it" to Config("Italian", Color(0xFF34C759), Color.Black),
        "de" to Config("German", Color(0xFFFF9800), Color.Black),
        "pt" to Config("Portuguese", Color(0xFF34C759), Color.Black),
        "ar" to Config("Arabic", Color(0xFF34C759), Color.White),
    )

    private val _languages = MutableStateFlow(defaults)
    val languages: StateFlow<Map<String, Config>> = _languages.asStateFlow()

    fun color(code: String): Color =
        _languages.value[code.lowercase()]?.color ?: Color(0xFF7A71F0)

    fun textColor(code: String): Color =
        _languages.value[code.lowercase()]?.textColor ?: Color.White

    /** One-shot fetch; called from HomeScreen on app launch. Safe to call repeatedly. */
    suspend fun fetchLanguages() = withContext(Dispatchers.IO) {
        try {
            val url = URL("${SupabaseConfig.PROJECT_URL}/rest/v1/languages?select=*")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                setRequestProperty("apikey", SupabaseConfig.ANON_KEY)
                setRequestProperty("Authorization", "Bearer ${SupabaseConfig.ANON_KEY}")
                setRequestProperty("Accept", "application/json")
                connectTimeout = 10_000
                readTimeout = 10_000
            }
            if (conn.responseCode != 200) {
                Log.w("LanguageService", "fetch returned ${conn.responseCode}")
                return@withContext
            }
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            val rows = JSONArray(body)
            val built = mutableMapOf<String, Config>()
            for (i in 0 until rows.length()) {
                val row = rows.getJSONObject(i)
                val code = row.optString("code").lowercase()
                if (code.isEmpty()) continue
                built[code] = Config(
                    displayName = row.optString("display_name", code),
                    color = parseHex(row.optString("color")) ?: defaults[code]?.color ?: Color(0xFF7A71F0),
                    textColor = parseHex(row.optString("text_color")) ?: defaults[code]?.textColor ?: Color.White,
                )
            }
            if (built.isNotEmpty()) {
                _languages.value = built
            }
        } catch (e: Exception) {
            Log.w("LanguageService", "fetch failed: ${e.message}")
        }
    }

    private fun parseHex(hex: String?): Color? {
        if (hex.isNullOrBlank()) return null
        val cleaned = hex.trim().removePrefix("#")
        return try {
            val v = cleaned.toLong(16)
            // Color(Int) takes packed 0xAARRGGBB. Add full alpha for 6-digit hex.
            val argb = if (cleaned.length == 6) (v or 0xFF000000L) else v
            Color(argb.toInt())
        } catch (_: NumberFormatException) {
            null
        }
    }
}

/** Composition-local hook so the Compose `languageColor`/`languageTextColor`
 *  helpers can subscribe to the StateFlow and recompose when the fetch arrives. */
val LocalLanguages = compositionLocalOf { LanguageService.languages.value }
