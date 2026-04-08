package com.memorezar.app.data.storage

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore by preferencesDataStore(name = "memorezar_equivalences_store")

@Singleton
class UserEquivalencesStore @Inject constructor(
    @ApplicationContext private val context: Context
) {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val json = Json { ignoreUnknownKeys = true }
    private val key = stringPreferencesKey("equivalences_json")

    private val _equivalences = MutableStateFlow<Map<String, Set<String>>>(emptyMap())
    val equivalences: StateFlow<Map<String, Set<String>>> = _equivalences.asStateFlow()

    init {
        scope.launch { load() }
    }

    // -- Public API ---------------------------------------------------------------

    fun addEquivalence(expected: String, spoken: String) {
        val normExpected = normalize(expected)
        val normSpoken = normalize(spoken)
        if (normExpected.isEmpty() || normSpoken.isEmpty() || normExpected == normSpoken) return

        val current = _equivalences.value.toMutableMap()
        val set = (current[normExpected] ?: emptySet()) + normSpoken
        current[normExpected] = set
        _equivalences.value = current
        persist(current)
    }

    fun removeEquivalence(expected: String, spoken: String) {
        val normExpected = normalize(expected)
        val normSpoken = normalize(spoken)

        val current = _equivalences.value.toMutableMap()
        val set = current[normExpected] ?: return
        val updated = set - normSpoken
        if (updated.isEmpty()) {
            current.remove(normExpected)
        } else {
            current[normExpected] = updated
        }
        _equivalences.value = current
        persist(current)
    }

    fun equivalencesFor(expected: String): Set<String>? {
        return _equivalences.value[normalize(expected)]
    }

    fun clearAll() {
        _equivalences.value = emptyMap()
        persist(emptyMap())
    }

    // -- Private ------------------------------------------------------------------

    private fun normalize(word: String): String {
        return word.lowercase()
            .filter { it.isLetterOrDigit() }
            .trim()
    }

    // -- Persistence --------------------------------------------------------------

    private suspend fun load() {
        context.dataStore.data.collect { prefs ->
            val raw = prefs[key]
            if (raw != null) {
                try {
                    val decoded = json.decodeFromString<Map<String, List<String>>>(raw)
                    _equivalences.value = decoded.mapValues { it.value.toSet() }
                } catch (e: Exception) {
                    android.util.Log.w("UserEquivalencesStore", "Failed to decode equivalences: ${e.message}")
                }
            }
        }
    }

    private fun persist(equivalences: Map<String, Set<String>>) {
        scope.launch {
            try {
                val encodable = equivalences.mapValues { it.value.toList() }
                context.dataStore.edit { prefs ->
                    prefs[key] = json.encodeToString(encodable)
                }
            } catch (e: Exception) {
                android.util.Log.w("UserEquivalencesStore", "Failed to persist equivalences: ${e.message}")
            }
        }
    }
}
