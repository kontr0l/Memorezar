package com.memorezar.app.ui.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.models.SuggestionPack
import com.memorezar.app.data.services.PackFetchException
import com.memorezar.app.data.services.PackService
import com.memorezar.app.data.storage.QuoteStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
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

    private val _isLoadingPacks = MutableStateFlow(false)
    val isLoadingPacks: StateFlow<Boolean> = _isLoadingPacks.asStateFlow()

    private val _packsLoadFailed = MutableStateFlow(false)
    val packsLoadFailed: StateFlow<Boolean> = _packsLoadFailed.asStateFlow()

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

    /**
     * Fetch packs with one automatic retry after 2s. On terminal failure,
     * sets `packsLoadFailed` so the UI can show the Refresh button and the
     * ON_RESUME / tab-retap observers know to retry later.
     * Guards against overlapping calls via `_isLoadingPacks`.
     */
    fun loadPacks() {
        if (_isLoadingPacks.value) return
        viewModelScope.launch {
            _isLoadingPacks.value = true
            try {
                try {
                    _remotePacks.value = packService.fetchPacks()
                    _packsLoadFailed.value = false
                    return@launch
                } catch (_: PackFetchException) {
                    // First attempt failed — wait and retry once. Handles
                    // cold-launch races where the network hadn't settled
                    // when the app opened.
                }

                delay(2000)

                try {
                    _remotePacks.value = packService.fetchPacks()
                    _packsLoadFailed.value = false
                } catch (_: PackFetchException) {
                    _packsLoadFailed.value = true
                }
            } finally {
                _isLoadingPacks.value = false
            }
        }
    }

    /** Retry pack load only if the previous attempt failed. Used by ON_RESUME
     *  and home-tab re-tap hooks to avoid hammering the server. */
    fun retryPacksIfFailed() {
        if (_packsLoadFailed.value) loadPacks()
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
