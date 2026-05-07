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

private val Context.seenCommunityDataStore by preferencesDataStore(name = "memorezar_seen_community_recordings")

@Singleton
class SeenCommunityRecordingsStore @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val json = Json { ignoreUnknownKeys = true }
    private val seenKey = stringPreferencesKey("seen_ids_json")

    private val _seenIds = MutableStateFlow<Set<String>>(emptySet())
    val seenIds: StateFlow<Set<String>> = _seenIds.asStateFlow()

    init {
        scope.launch { load() }
    }

    fun markSeen(ids: Collection<String>) {
        if (ids.isEmpty()) return
        val updated = _seenIds.value + ids
        if (updated.size == _seenIds.value.size) return
        _seenIds.value = updated
        persist(updated)
    }

    private suspend fun load() {
        context.seenCommunityDataStore.data.collect { prefs ->
            val raw = prefs[seenKey] ?: return@collect
            try {
                _seenIds.value = json.decodeFromString<List<String>>(raw).toSet()
            } catch (e: Exception) {
                android.util.Log.w("SeenCommunityStore", "Failed to decode: ${e.message}")
            }
        }
    }

    private fun persist(ids: Set<String>) {
        scope.launch {
            try {
                context.seenCommunityDataStore.edit { prefs ->
                    prefs[seenKey] = json.encodeToString(ids.toList())
                }
            } catch (e: Exception) {
                android.util.Log.w("SeenCommunityStore", "Failed to persist: ${e.message}")
            }
        }
    }
}
