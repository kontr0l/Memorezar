package com.memorezar.app.ui.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.models.SuggestionPack
import com.memorezar.app.data.services.PackService
import com.memorezar.app.data.storage.QuoteStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    val quoteStore: QuoteStore,
    private val packService: PackService
) : ViewModel() {

    private val _remotePacks = MutableStateFlow<List<SuggestionPack>>(emptyList())
    val remotePacks: StateFlow<List<SuggestionPack>> = _remotePacks.asStateFlow()

    /** Packs filtered to exclude already-added ones — reactively updates when categories change */
    val availablePacks: StateFlow<List<SuggestionPack>> = combine(
        _remotePacks,
        quoteStore.categories
    ) { packs, categories ->
        val installedPackIds = categories.mapNotNull { it.sourcePackId }.toSet()
        packs.filter { it.id !in installedPackIds }
    }.stateIn(viewModelScope, SharingStarted.Lazily, emptyList())

    /** Recently practiced quotes, most recent first, up to 5 */
    val continuePracticingQuotes: StateFlow<List<Quote>> = quoteStore.quotes
        .map { quotes ->
            quotes.filter { it.lastPracticedAt != null }
                .sortedByDescending { it.lastPracticedAt ?: 0L }
                .take(5)
        }
        .stateIn(viewModelScope, SharingStarted.Lazily, emptyList())

    init {
        loadPacks()
        syncInstalledPacks()
    }

    fun loadPacks() {
        viewModelScope.launch {
            val packs = packService.fetchPacks()
            _remotePacks.value = packs
        }
    }

    /** Re-filter available packs (call after adding a pack) — now automatic via combine */
    fun refreshAvailablePacks(packs: List<SuggestionPack>? = null) {
        if (packs != null) {
            _remotePacks.value = packs
        }
    }

    private fun syncInstalledPacks() {
        viewModelScope.launch {
            val versions = quoteStore.installedPackVersions()
            if (versions.isNotEmpty()) {
                // Force a full re-sync once to pick up any missing translations
                val needsForceSync = !quoteStore.hasCompletedTranslationSync()
                packService.syncInstalledPacks(versions, quoteStore, forceAll = needsForceSync)
                if (needsForceSync) {
                    quoteStore.markTranslationSyncComplete()
                }
            }
        }
    }

    suspend fun isPackAdded(packId: String): Boolean = quoteStore.isPackAdded(packId)

    fun addPack(pack: SuggestionPack) {
        quoteStore.addSuggestionPack(pack)
        refreshAvailablePacks()
    }
}
