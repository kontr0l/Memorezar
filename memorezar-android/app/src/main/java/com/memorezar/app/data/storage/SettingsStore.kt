package com.memorezar.app.data.storage

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.memorezar.app.core.alert.AlertManager
import com.memorezar.app.core.alert.SoundTheme
import com.memorezar.app.data.models.AppSettings
import com.memorezar.app.data.models.AppTheme
import com.memorezar.app.data.models.FontSize
import com.memorezar.app.data.models.MemorizationMode
import com.memorezar.app.data.models.WordVisibility
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

private val Context.dataStore by preferencesDataStore(name = "memorezar_settings_store")

@Singleton
class SettingsStore @Inject constructor(
    @ApplicationContext private val context: Context,
    private val alertManager: AlertManager
) {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val json = Json { ignoreUnknownKeys = true }
    private val key = stringPreferencesKey("settings_json")

    private val _settings = MutableStateFlow(AppSettings.Default)
    val settings: StateFlow<AppSettings> = _settings.asStateFlow()

    init {
        scope.launch { load() }
    }

    // -- Mutators -----------------------------------------------------------------

    fun updateSettings(transform: (AppSettings) -> AppSettings) {
        val updated = transform(_settings.value)
        _settings.value = updated
        syncToAlertManager(updated)
        persist(updated)
    }

    fun updateSettings(newSettings: AppSettings) {
        _settings.value = newSettings
        syncToAlertManager(newSettings)
        persist(newSettings)
    }

    fun setAudioAlert(enabled: Boolean) = updateSettings { it.copy(audioAlertEnabled = enabled) }
    fun setVisualAlert(enabled: Boolean) = updateSettings { it.copy(visualAlertEnabled = enabled) }
    fun setHapticAlert(enabled: Boolean) = updateSettings { it.copy(hapticAlertEnabled = enabled) }
    fun setSoundTheme(theme: SoundTheme) = updateSettings { it.copy(soundTheme = theme) }
    fun setFontSize(size: FontSize) = updateSettings { it.copy(fontSize = size) }
    fun setTheme(theme: AppTheme) = updateSettings { it.copy(theme = theme) }
    fun setWordVisibility(visibility: WordVisibility) = updateSettings { it.copy(wordVisibility = visibility) }
    fun setWordRevealPercentage(pct: Double) = updateSettings { it.copy(wordRevealPercentage = pct) }
    fun setDefaultMode(mode: MemorizationMode) = updateSettings { it.copy(defaultMemorizationMode = mode) }
    fun setFirstLetterMode(enabled: Boolean) = updateSettings { it.copy(firstLetterModeEnabled = enabled) }

    fun resetToDefaults() {
        _settings.value = AppSettings.Default
        syncToAlertManager(AppSettings.Default)
        persist(AppSettings.Default)
    }

    // -- AlertManager sync --------------------------------------------------------

    private fun syncToAlertManager(s: AppSettings) {
        alertManager.audioAlertEnabled = s.audioAlertEnabled
        alertManager.visualAlertEnabled = s.visualAlertEnabled
        alertManager.hapticAlertEnabled = s.hapticAlertEnabled
        alertManager.soundTheme = s.soundTheme
    }

    // -- Persistence --------------------------------------------------------------

    private suspend fun load() {
        context.dataStore.data.collect { prefs ->
            val raw = prefs[key]
            if (raw != null) {
                try {
                    val loaded = json.decodeFromString<AppSettings>(raw)
                    _settings.value = loaded
                    syncToAlertManager(loaded)
                } catch (e: Exception) {
                    android.util.Log.w("SettingsStore", "Failed to decode settings: ${e.message}")
                    _settings.value = AppSettings.Default
                    syncToAlertManager(AppSettings.Default)
                }
            } else {
                syncToAlertManager(AppSettings.Default)
            }
        }
    }

    private fun persist(settings: AppSettings) {
        scope.launch {
            try {
                context.dataStore.edit { prefs ->
                    prefs[key] = json.encodeToString(settings)
                }
            } catch (e: Exception) {
                android.util.Log.w("SettingsStore", "Failed to persist settings: ${e.message}")
            }
        }
    }
}
