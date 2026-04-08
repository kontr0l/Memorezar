package com.memorezar.app.data.storage

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.memorezar.app.data.models.TipDefinition
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

private val Context.dataStore by preferencesDataStore(name = "memorezar_tutorial_store")

@Singleton
class TutorialStore @Inject constructor(
    @ApplicationContext private val context: Context
) {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val json = Json { ignoreUnknownKeys = true }
    private val tipsKey = stringPreferencesKey("completed_tips_json")
    private val onboardingKey = booleanPreferencesKey("has_completed_onboarding")

    private val _completedTips = MutableStateFlow<Set<String>>(emptySet())
    val completedTips: StateFlow<Set<String>> = _completedTips.asStateFlow()

    private val _hasCompletedOnboarding = MutableStateFlow(false)
    val hasCompletedOnboarding: StateFlow<Boolean> = _hasCompletedOnboarding.asStateFlow()

    init {
        scope.launch { load() }
    }

    // -- Public API ---------------------------------------------------------------

    fun shouldShowTip(tip: TipDefinition): Boolean {
        val completed = _completedTips.value
        if (tip.id in completed) return false
        val required = tip.requiredTipId
        if (required != null && required !in completed) return false
        return true
    }

    fun completeTip(tipId: String) {
        val updated = _completedTips.value + tipId
        _completedTips.value = updated
        persistTips(updated)
    }

    fun completeOnboarding() {
        _hasCompletedOnboarding.value = true
        scope.launch {
            try {
                context.dataStore.edit { prefs ->
                    prefs[onboardingKey] = true
                }
            } catch (e: Exception) {
                android.util.Log.w("TutorialStore", "Failed to persist onboarding: ${e.message}")
            }
        }
    }

    fun resetAll() {
        _completedTips.value = emptySet()
        _hasCompletedOnboarding.value = false
        scope.launch {
            try {
                context.dataStore.edit { prefs ->
                    prefs[tipsKey] = json.encodeToString(emptyList<String>())
                    prefs[onboardingKey] = false
                }
            } catch (e: Exception) {
                android.util.Log.w("TutorialStore", "Failed to reset: ${e.message}")
            }
        }
    }

    // -- Persistence --------------------------------------------------------------

    private suspend fun load() {
        context.dataStore.data.collect { prefs ->
            val tipsRaw = prefs[tipsKey]
            if (tipsRaw != null) {
                try {
                    _completedTips.value = json.decodeFromString<List<String>>(tipsRaw).toSet()
                } catch (e: Exception) {
                    android.util.Log.w("TutorialStore", "Failed to decode tips: ${e.message}")
                }
            }
            _hasCompletedOnboarding.value = prefs[onboardingKey] ?: false
        }
    }

    private fun persistTips(tips: Set<String>) {
        scope.launch {
            try {
                context.dataStore.edit { prefs ->
                    prefs[tipsKey] = json.encodeToString(tips.toList())
                }
            } catch (e: Exception) {
                android.util.Log.w("TutorialStore", "Failed to persist tips: ${e.message}")
            }
        }
    }
}
