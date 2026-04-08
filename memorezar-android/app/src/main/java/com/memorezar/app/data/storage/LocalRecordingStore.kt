package com.memorezar.app.data.storage

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.memorezar.app.data.models.LocalRecording
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
import java.io.File
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore by preferencesDataStore(name = "memorezar_recordings_store")

@Singleton
class LocalRecordingStore @Inject constructor(
    @ApplicationContext private val context: Context
) {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val json = Json { ignoreUnknownKeys = true }
    private val key = stringPreferencesKey("recordings_json")

    private val _recordings = MutableStateFlow<List<LocalRecording>>(emptyList())
    val recordings: StateFlow<List<LocalRecording>> = _recordings.asStateFlow()

    private val recordingsDir: File
        get() {
            val dir = File(context.filesDir, "recordings")
            if (!dir.exists()) dir.mkdirs()
            return dir
        }

    init {
        scope.launch { load() }
    }

    // -- Public API ---------------------------------------------------------------

    fun saveRecording(
        audioData: ByteArray,
        quoteTextHash: String,
        quoteTitle: String,
        duration: Double,
        isFavorite: Boolean = false,
        sourceRecordingId: String? = null,
        uploaderName: String? = null,
        name: String? = null,
        quoteId: String? = null,
        language: String = "en"
    ): LocalRecording? {
        val fileName = "${UUID.randomUUID()}.m4a"
        val file = File(recordingsDir, fileName)

        return try {
            file.writeBytes(audioData)

            val recording = LocalRecording(
                quoteTextHash = quoteTextHash,
                quoteTitle = quoteTitle,
                localFileName = fileName,
                durationSeconds = duration,
                isFavorite = isFavorite,
                sourceRecordingId = sourceRecordingId,
                uploaderName = uploaderName,
                name = name,
                quoteId = quoteId,
                language = language
            )

            val updated = _recordings.value + recording
            _recordings.value = updated
            persist(updated)
            recording
        } catch (e: Exception) {
            android.util.Log.w("LocalRecordingStore", "Failed to write audio file: ${e.message}")
            null
        }
    }

    fun updateRecordingName(recordingId: String, name: String) {
        val updated = _recordings.value.map { rec ->
            if (rec.id == recordingId) rec.copy(name = name) else rec
        }
        _recordings.value = updated
        persist(updated)
    }

    fun deleteRecording(recording: LocalRecording) {
        val file = File(recordingsDir, recording.localFileName)
        try {
            file.delete()
        } catch (_: Exception) { }

        val updated = _recordings.value.filter { it.id != recording.id }
        _recordings.value = updated
        persist(updated)
    }

    fun recordingsForHash(hash: String): List<LocalRecording> {
        return _recordings.value.filter { it.quoteTextHash == hash }
    }

    fun recordingsForQuote(quoteId: String, allHashes: Set<String>): List<LocalRecording> {
        return _recordings.value.filter { rec ->
            rec.quoteId == quoteId || rec.quoteTextHash in allHashes
        }
    }

    fun loadAudioData(recording: LocalRecording): ByteArray? {
        val file = File(recordingsDir, recording.localFileName)
        return try {
            if (file.exists()) file.readBytes() else null
        } catch (e: Exception) {
            android.util.Log.w("LocalRecordingStore", "Failed to read audio: ${e.message}")
            null
        }
    }

    // -- Persistence --------------------------------------------------------------

    private suspend fun load() {
        context.dataStore.data.collect { prefs ->
            val raw = prefs[key]
            if (raw != null) {
                try {
                    _recordings.value = json.decodeFromString<List<LocalRecording>>(raw)
                } catch (e: Exception) {
                    android.util.Log.w("LocalRecordingStore", "Failed to decode recordings: ${e.message}")
                }
            }
        }
    }

    private fun persist(recordings: List<LocalRecording>) {
        scope.launch {
            try {
                context.dataStore.edit { prefs ->
                    prefs[key] = json.encodeToString(recordings)
                }
            } catch (e: Exception) {
                android.util.Log.w("LocalRecordingStore", "Failed to persist recordings: ${e.message}")
            }
        }
    }
}
