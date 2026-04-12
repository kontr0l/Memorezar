package com.memorezar.app.ui.viewmodels

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.memorezar.app.core.alert.AlertManager
import com.memorezar.app.core.comparison.ComparisonResult
import com.memorezar.app.core.comparison.WordComparator
import com.memorezar.app.core.speech.SpeechRecognitionDelegate
import com.memorezar.app.core.speech.SpeechRecognitionService
import com.memorezar.app.data.models.LocalRecording
import com.memorezar.app.data.models.MemorizationMode
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.models.Recording
import com.memorezar.app.data.services.AudioRecorderService
import com.memorezar.app.data.services.RecordingService
import com.memorezar.app.data.services.TextToSpeechService
import com.memorezar.app.data.storage.LocalRecordingStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.Date
import java.util.Locale
import javax.inject.Inject

private const val TAG = "RecitationVM"

// ---------------------------------------------------------------------------
// Word Display State
// ---------------------------------------------------------------------------

enum class WordState {
    UPCOMING,   // Not yet reached
    CURRENT,    // Current word being spoken
    CORRECT,    // Correctly spoken
    INCORRECT,  // Mistake
    PENDING     // Awaiting settle confirmation
}

enum class WordDisplayMode {
    FULL,       // Complete word shown
    HIDDEN,     // Gray box, no text
    FIRST_LETTER_1, // 1 letter + underscores
    FIRST_LETTER_2, // 2 letters + underscores
    FIRST_LETTER_3  // 3 letters + underscores
}

data class WordDisplay(
    val text: String,
    val state: WordState = WordState.UPCOMING,
    val isRevealed: Boolean = false
)

// ---------------------------------------------------------------------------
// UI State
// ---------------------------------------------------------------------------

enum class MasterResult {
    FAILED,     // < 95% accuracy, streak reset
    PASSED,     // >= 95%, streak incremented but < 3
    MASTERED    // >= 95%, streak reached 3
}

// ---------------------------------------------------------------------------
// Audio Playback State
// ---------------------------------------------------------------------------

sealed class PlaybackSource {
    data class Local(val recording: LocalRecording) : PlaybackSource()
    data class Community(val recording: Recording) : PlaybackSource()

    val displayName: String get() = when (this) {
        is Local -> recording.name ?: recording.uploaderName ?: "My Recording"
        is Community -> recording.uploaderName
    }
}

data class AudioPlaybackState(
    val isPlaybackMode: Boolean = false,
    val isPlaying: Boolean = false,
    val isLoadingAudio: Boolean = false,
    val currentTime: Double = 0.0,
    val duration: Double = 0.0,
    val playbackRepeat: Boolean = true,
    val currentSource: PlaybackSource? = null,
    val playlist: List<PlaybackSource> = emptyList(),
    // TTS
    val isTTSActive: Boolean = false,
    val isTTSLoading: Boolean = false,
    val ttsError: String? = null,
    // Recording
    val isRecordingMode: Boolean = false,
    val isRecording: Boolean = false,
    val recordingDuration: Double = 0.0,
    val hasRecording: Boolean = false,
    val showSaveSheet: Boolean = false,
    val showDeleteConfirm: Boolean = false,
    val editingRecordingName: String? = null,
    // Picker
    val showRecordingPicker: Boolean = false,
    val localRecordings: List<LocalRecording> = emptyList(),
    val communityRecordings: List<Recording> = emptyList(),
    val isLoadingCommunity: Boolean = false,
    val downloadingId: String? = null
)

/** Lightweight info about a single chunk, used for peek containers in the split UI. */
data class ChunkInfo(
    val text: String,
    val wordCount: Int,
    val accuracy: Double?,     // null if not yet completed
    val isComplete: Boolean
)

data class RecitationUiState(
    val words: List<WordDisplay> = emptyList(),
    val isListening: Boolean = false,
    val currentPosition: Int = 0,
    val isComplete: Boolean = false,
    val accuracy: Double = 0.0,
    val mistakeCount: Int = 0,
    val correctCount: Int = 0,
    val hintCount: Int = 0,
    val totalWords: Int = 0,
    val testedWordCount: Int = 0,
    val audioLevel: Float = 0f,
    val showMistakeFlash: Boolean = false,
    val isPaused: Boolean = false,
    // Mode
    val currentMode: MemorizationMode = MemorizationMode.VOICE,
    // Reveal system
    val displayLevel: Int = 1,         // 1=easy(90%), 2=medium(50%), 3=hard(20%)
    val revealPercentage: Double = 90.0,
    val letterRevealStep: Int = 3,     // letters shown in first-letter mode
    val isFirstLetterToggle: Boolean = false,
    // Hint flash
    val flashingWordIndex: Int? = null,
    // Pause icon (2s silence)
    val showPauseIcon: Boolean = false,
    // Dispute
    val tappedMistakeIndex: Int? = null,
    val tappedMistakeSpoken: String? = null,
    // Typing mode
    val typingInput: String = "",
    // Multiple choice
    val mcChoices: List<String> = emptyList(),
    val mcCorrectIndex: Int = -1,
    val mcWrongIndex: Int? = null,
    // Master mode
    val isMasterMode: Boolean = false,
    val showMasterInfoPopup: Boolean = false,
    val showMasterHintBlock: Boolean = false,
    val masterResult: MasterResult? = null,
    val previousMasteryStreak: Int = 0,  // streak before this session
    // Quote info
    val showQuoteInfo: Boolean = false,
    // Inline split — chunk texts (null = not split). UI nav uses this.
    val splitChunks: List<String>? = null,
    // Parallel to splitChunks: word count + completion/accuracy per chunk for peek rendering.
    val splitChunkInfos: List<ChunkInfo> = emptyList(),
    val activeChunkIndex: Int = 0,
    val showSplitOverlay: Boolean = false,
    val splitCount: Int = 3,
    // Debug/error
    val speechError: String? = null
)

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

@HiltViewModel
class RecitationViewModel @Inject constructor(
    private val speechService: SpeechRecognitionService,
    private val alertManager: AlertManager,
    private val quoteStore: com.memorezar.app.data.storage.QuoteStore,
    val ttsService: TextToSpeechService,
    val recorderService: AudioRecorderService,
    private val recordingService: RecordingService,
    val localRecordingStore: LocalRecordingStore
) : ViewModel(), SpeechRecognitionDelegate {

    private val _uiState = MutableStateFlow(RecitationUiState())
    val uiState: StateFlow<RecitationUiState> = _uiState.asStateFlow()

    private val _audioState = MutableStateFlow(AudioPlaybackState())
    val audioState: StateFlow<AudioPlaybackState> = _audioState.asStateFlow()

    init {
        alertManager.onVisualAlert = { flashMistake() }
    }

    private val comparator = WordComparator()
    private var quote: Quote? = null
    var isTutorialMode = false
    private var tutorialRevealActive = false
    private var activeLanguage: String? = null  // null = original language
    private val mistakes = mutableListOf<ComparisonResult>()
    private var previousWordWasMistake = false
    private var sessionStartTime: Date? = null

    // Pending mismatch settle logic
    private var pendingMismatch: ComparisonResult? = null
    private var pendingMismatchJob: Job? = null
    private var consecutiveMismatchesAtPosition = 0
    private var lastMismatchPosition = -1
    private val MIN_SETTLE_MS = 400L
    private val MAX_SETTLE_MS = 1500L

    // Silence detection for pause icon
    private var silenceJob: Job? = null

    // Hint flash timer
    private var flashJob: Job? = null

    // MC wrong flash timer
    private var mcWrongJob: Job? = null

    // Audio playback
    private var mediaPlayer: MediaPlayer? = null
    private var playbackTimerJob: Job? = null
    private var quoteTextHash: String = ""

    // ---------------------------------------------------------------------------
    // Quote Setup
    // ---------------------------------------------------------------------------

    fun setQuote(quote: Quote) {
        this.quote = quote
        mistakes.clear()
        previousWordWasMistake = false
        sessionStartTime = null
        pendingMismatch = null
        pendingMismatchJob?.cancel()
        consecutiveMismatchesAtPosition = 0
        lastMismatchPosition = -1

        // Clear any in-memory split — it'll be re-built from quote.chunks below.
        internalSplitChunks = null
        activeChunkIndexInternal = 0

        // Restore the last-practiced language so the comparator, TTS, and UI all
        // line up with the translation the user ended their last session in.
        activeLanguage = quote.lastPracticedLanguage

        // Mastered quotes always open at the hardest reveal level.
        if (quote.masteryStreak >= 3 && quote.revealLevel < 3) {
            quote.revealLevel = 3
            quoteStore.updateQuote(quote)
        }

        val comparatorText = getActiveText().ifEmpty { quote.text }
        val comparatorLang = activeLanguage ?: quote.primaryLanguage
        comparator.setTargetText(comparatorText, comparatorLang)

        val targetWords = comparator.getTargetWords()
        val wordDisplays = targetWords.mapIndexed { index, word ->
            WordDisplay(
                text = word,
                state = if (index == 0) WordState.CURRENT else WordState.UPCOMING
            )
        }

        // Determine initial reveal from quote's level
        val level = (quote.revealLevel).coerceIn(1, 3)
        val revealPct = revealPercentageForLevel(level)
        val letterStep = letterStepForLevel(level)

        _uiState.update { state ->
            state.copy(
                words = wordDisplays,
                currentPosition = 0,
                isComplete = false,
                accuracy = 0.0,
                mistakeCount = 0,
                correctCount = 0,
                hintCount = 0,
                totalWords = targetWords.size,
                testedWordCount = 0,
                audioLevel = 0f,
                showMistakeFlash = false,
                isPaused = false,
                displayLevel = level,
                revealPercentage = revealPct,
                letterRevealStep = letterStep,
                isFirstLetterToggle = false,
                flashingWordIndex = null,
                showPauseIcon = false,
                tappedMistakeIndex = null,
                tappedMistakeSpoken = null,
                typingInput = "",
                mcChoices = emptyList(),
                mcCorrectIndex = -1,
                mcWrongIndex = null,
                splitChunks = null,
                splitChunkInfos = emptyList(),
                activeChunkIndex = 0,
                showSplitOverlay = false,
                speechError = null
            )
        }

        applyRevealPercentage()

        // If in MC mode, generate choices immediately
        if (_uiState.value.currentMode == MemorizationMode.MULTIPLE_CHOICE) {
            generateChoices()
        }

        // If this quote was previously split, rebuild the split and jump to the saved chunk.
        restoreSavedSplit()
    }

    // ---------------------------------------------------------------------------
    // Mode Switching
    // ---------------------------------------------------------------------------

    /** Set mode + first-letter without any side effects (for tutorial init). */
    fun setInitialMode(mode: MemorizationMode, firstLetter: Boolean) {
        _uiState.update { it.copy(currentMode = mode, isFirstLetterToggle = firstLetter) }
    }

    fun switchMode(mode: MemorizationMode) {
        // Block mode switching in master mode
        if (_uiState.value.isMasterMode) return

        // Stop speech if leaving voice mode
        if (_uiState.value.currentMode == MemorizationMode.VOICE && mode != MemorizationMode.VOICE) {
            stopRecitation()
        }

        // Enter/exit audio playback mode
        if (mode == MemorizationMode.AUDIO) {
            enterPlaybackMode()
        } else if (_audioState.value.isPlaybackMode) {
            exitPlaybackMode()
        }

        _uiState.update { it.copy(currentMode = mode, typingInput = "", mcWrongIndex = null, speechError = null) }

        if (mode == MemorizationMode.MULTIPLE_CHOICE) {
            skipToNextHiddenWord()
            generateChoices()
        } else if (mode == MemorizationMode.TYPING) {
            if (!_uiState.value.isFirstLetterToggle) {
                skipToNextHiddenWord()
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Audio Playback Mode
    // ---------------------------------------------------------------------------

    private fun enterPlaybackMode() {
        stopAudioPlayback()
        ttsService.stop()
        loadRecordingsForCurrentQuote()

        // Auto-select first local recording if available, otherwise enter recording mode
        val local = localRecordingStore.recordingsForHash(quoteTextHash)
        if (local.isNotEmpty()) {
            _audioState.update { it.copy(isPlaybackMode = true) }
            playLocalRecording(local.first())
        } else {
            // No recordings — show picker sheet so user can choose TTS or record
            _audioState.update { it.copy(isPlaybackMode = true, showRecordingPicker = true) }
        }
    }

    fun exitPlaybackMode() {
        stopAudioPlayback()
        ttsService.stop()
        recorderService.cleanup()
        _audioState.value = AudioPlaybackState()
    }

    fun showRecordingPicker() {
        _audioState.update { it.copy(showRecordingPicker = true) }
        loadRecordingsForCurrentQuote()
    }

    fun dismissRecordingPicker() {
        val state = _audioState.value
        // If nothing is active after dismissing, fall back to recording mode
        val needsRecordingMode = state.currentSource == null && !state.isTTSActive && !state.isRecordingMode
        _audioState.update { it.copy(showRecordingPicker = false, isRecordingMode = it.isRecordingMode || needsRecordingMode) }
    }

    private fun loadRecordingsForCurrentQuote() {
        val q = quote ?: return
        quoteTextHash = recordingService.hashQuoteText(q.displayText)

        // Local recordings
        val local = localRecordingStore.recordingsForHash(quoteTextHash)
        val localPlaylist = local.map { PlaybackSource.Local(it) }
        _audioState.update { it.copy(localRecordings = local, isLoadingCommunity = true, playlist = localPlaylist) }

        // Community recordings
        viewModelScope.launch(Dispatchers.IO) {
            val community = try {
                recordingService.fetchRecordings(quoteTextHash)
            } catch (_: Exception) { emptyList() }
            val fullPlaylist = local.map { PlaybackSource.Local(it) } + community.map { PlaybackSource.Community(it) }
            _audioState.update { it.copy(communityRecordings = community, isLoadingCommunity = false, playlist = fullPlaylist) }
        }
    }

    // -- Playback controls --------------------------------------------------------

    fun playLocalRecording(recording: LocalRecording) {
        viewModelScope.launch {
            _audioState.update { it.copy(
                isLoadingAudio = true,
                showRecordingPicker = false,
                isRecordingMode = false,
                isTTSActive = false
            )}
            val data = localRecordingStore.loadAudioData(recording)
            if (data != null) {
                val source = PlaybackSource.Local(recording)
                startPlaybackWithData(data, source)
            } else {
                _audioState.update { it.copy(isLoadingAudio = false) }
            }
        }
    }

    fun playCommunityRecording(recording: Recording) {
        viewModelScope.launch(Dispatchers.IO) {
            _audioState.update { it.copy(
                downloadingId = recording.id,
                showRecordingPicker = false,
                isRecordingMode = false,
                isTTSActive = false
            )}
            val data = recordingService.downloadAudio(recording.filePath)
            if (data != null) {
                val source = PlaybackSource.Community(recording)
                startPlaybackWithData(data, source)
            }
            _audioState.update { it.copy(downloadingId = null) }
        }
    }

    fun saveCommunityRecording(recording: Recording) {
        viewModelScope.launch(Dispatchers.IO) {
            _audioState.update { it.copy(downloadingId = recording.id) }
            val data = recordingService.downloadAudio(recording.filePath)
            if (data != null) {
                localRecordingStore.saveRecording(
                    audioData = data,
                    quoteTextHash = quoteTextHash,
                    quoteTitle = quote?.displayTitle ?: "",
                    duration = recording.durationSeconds ?: 0.0,
                    isFavorite = true,
                    sourceRecordingId = recording.id,
                    uploaderName = recording.uploaderName,
                    quoteId = quote?.id,
                    language = recording.language
                )
                loadRecordingsForCurrentQuote()
            }
            _audioState.update { it.copy(downloadingId = null) }
        }
    }

    private suspend fun startPlaybackWithData(data: ByteArray, source: PlaybackSource) {
        stopAudioPlayback()

        // Switch quote language to match the recording's language
        val recordingLang = when (source) {
            is PlaybackSource.Local -> source.recording.language
            is PlaybackSource.Community -> source.recording.language
        }
        val primaryLang = quote?.primaryLanguage ?: "en"
        val targetLang = if (recordingLang == primaryLang) null else recordingLang
        if (targetLang != activeLanguage) {
            withContext(Dispatchers.Main) { switchLanguage(targetLang) }
        }

        try {
            val tempFile = File.createTempFile("playback", ".m4a")
            tempFile.writeBytes(data)

            withContext(Dispatchers.Main) {
                val player = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    setDataSource(tempFile.absolutePath)
                    prepare()
                    setOnCompletionListener {
                        if (_audioState.value.playbackRepeat) {
                            seekTo(0)
                            start()
                        } else {
                            _audioState.update { it.copy(isPlaying = false, currentTime = 0.0) }
                            playbackTimerJob?.cancel()
                        }
                    }
                    start()
                }
                mediaPlayer = player
                _audioState.update { it.copy(
                    isPlaying = true,
                    isLoadingAudio = false,
                    duration = player.duration / 1000.0,
                    currentTime = 0.0,
                    currentSource = source
                )}
                startPlaybackTimer()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Playback error: ${e.message}")
            _audioState.update { it.copy(isLoadingAudio = false) }
        }
    }

    fun togglePlayback() {
        val player = mediaPlayer ?: return
        if (player.isPlaying) {
            player.pause()
            _audioState.update { it.copy(isPlaying = false) }
            playbackTimerJob?.cancel()
        } else {
            player.start()
            _audioState.update { it.copy(isPlaying = true) }
            startPlaybackTimer()
        }
    }

    fun seekPlayback(fraction: Float) {
        val player = mediaPlayer ?: return
        val target = (fraction * player.duration).toInt()
        player.seekTo(target)
        _audioState.update { it.copy(currentTime = target / 1000.0) }
    }

    fun toggleRepeat() {
        _audioState.update { it.copy(playbackRepeat = !it.playbackRepeat) }
    }

    private fun stopAudioPlayback() {
        playbackTimerJob?.cancel()
        try {
            mediaPlayer?.let { if (it.isPlaying) it.stop(); it.release() }
        } catch (_: Exception) {}
        mediaPlayer = null
        _audioState.update { it.copy(isPlaying = false, currentTime = 0.0, duration = 0.0, currentSource = null) }
    }

    private fun startPlaybackTimer() {
        playbackTimerJob?.cancel()
        playbackTimerJob = viewModelScope.launch {
            while (isActive) {
                val player = mediaPlayer ?: break
                try {
                    if (player.isPlaying) {
                        _audioState.update { it.copy(currentTime = player.currentPosition / 1000.0) }
                    }
                } catch (_: Exception) { break }
                delay(100)
            }
        }
    }

    // -- TTS (Read Aloud) ---------------------------------------------------------

    fun startTTS() {
        stopAudioPlayback()
        _audioState.update { it.copy(
            isTTSActive = true,
            isTTSLoading = true,
            ttsError = null,
            showRecordingPicker = false,
            isRecordingMode = false
        )}
        // Use the currently-active language (set via the language badge picker),
        // falling back to the quote's primary language.
        val text = getActiveText()
        if (text.isEmpty()) return
        val lang = getActiveLanguageCode()

        ttsService.onFinish = {
            if (_audioState.value.playbackRepeat && _audioState.value.isTTSActive) {
                viewModelScope.launch { ttsService.speak(text, lang) }
            }
        }

        viewModelScope.launch {
            try {
                ttsService.speak(text, lang)
                _audioState.update { it.copy(isTTSLoading = false) }
            } catch (e: Exception) {
                _audioState.update { it.copy(isTTSLoading = false, ttsError = e.message) }
            }
        }
    }

    fun stopTTS() {
        ttsService.stop()
        ttsService.onFinish = null
        _audioState.update { it.copy(isTTSActive = false) }
    }

    /** Pause/resume TTS without tearing down the session (keeps the TTS button visible). */
    fun toggleTTS() {
        ttsService.togglePlayback()
    }

    // -- Recording ----------------------------------------------------------------

    fun enterRecordingMode() {
        stopAudioPlayback()
        ttsService.stop()
        _audioState.update { it.copy(
            isRecordingMode = true,
            showRecordingPicker = false,
            isTTSActive = false,
            isRecording = false,
            hasRecording = false,
            recordingDuration = 0.0
        )}
    }

    fun startRecording() {
        try {
            recorderService.startRecording()
            _audioState.update { it.copy(isRecording = true, recordingDuration = 0.0) }
            // Track duration updates
            viewModelScope.launch {
                recorderService.recordingDuration.collect { dur ->
                    _audioState.update { it.copy(recordingDuration = dur) }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Recording error: ${e.message}")
        }
    }

    fun stopRecordingAudio() {
        recorderService.stopRecording()
        _audioState.update { it.copy(
            isRecording = false,
            hasRecording = recorderService.hasRecording.value,
            showSaveSheet = recorderService.hasRecording.value
        )}
    }

    fun dismissSaveSheet() {
        _audioState.update { it.copy(showSaveSheet = false) }
    }

    /** Get the file path for preview playback of the just-recorded audio. */
    fun getRecordingFilePath(): String? = recorderService.getRecordingFilePath()

    fun saveRecording(name: String? = null, shareWithCommunity: Boolean = false) {
        val data = recorderService.getRecordingData() ?: return
        val q = quote ?: return
        val duration = _audioState.value.recordingDuration

        val saved = localRecordingStore.saveRecording(
            audioData = data,
            quoteTextHash = quoteTextHash,
            quoteTitle = q.displayTitle,
            duration = duration,
            name = name,
            quoteId = q.id,
            language = q.primaryLanguage ?: "en"
        )

        if (shareWithCommunity) {
            viewModelScope.launch(Dispatchers.IO) {
                try {
                    recordingService.uploadRecording(
                        audioData = data,
                        quoteTextHash = quoteTextHash,
                        quoteTitle = q.displayTitle,
                        durationSeconds = duration,
                        language = q.primaryLanguage ?: "en"
                    )
                } catch (e: Exception) {
                    Log.w(TAG, "Upload failed: ${e.message}")
                }
            }
        }

        recorderService.discardRecording()
        _audioState.update { it.copy(isRecordingMode = false, isRecording = false, hasRecording = false) }

        // Auto-play the saved recording
        if (saved != null) playLocalRecording(saved)
    }

    fun discardRecording() {
        recorderService.discardRecording()
        _audioState.update { it.copy(isRecording = false, hasRecording = false, showRecordingPicker = true) }
    }

    fun deleteLocalRecording(recording: LocalRecording) {
        localRecordingStore.deleteRecording(recording)
        loadRecordingsForCurrentQuote()
    }

    /** Navigate to prev/next recording in playlist. */
    fun navigatePlayback(forward: Boolean) {
        val state = _audioState.value
        val playlist = state.playlist
        if (playlist.size <= 1) return
        val current = state.currentSource ?: return
        val currentIndex = playlist.indexOfFirst {
            when {
                it is PlaybackSource.Local && current is PlaybackSource.Local -> it.recording.id == current.recording.id
                it is PlaybackSource.Community && current is PlaybackSource.Community -> it.recording.id == current.recording.id
                else -> false
            }
        }
        if (currentIndex < 0) return
        val nextIndex = if (forward) (currentIndex + 1) % playlist.size else (currentIndex - 1 + playlist.size) % playlist.size
        when (val next = playlist[nextIndex]) {
            is PlaybackSource.Local -> playLocalRecording(next.recording)
            is PlaybackSource.Community -> playCommunityRecording(next.recording)
        }
    }

    /** Show delete confirmation for current recording. */
    fun showDeleteConfirm() {
        _audioState.update { it.copy(showDeleteConfirm = true) }
    }

    fun dismissDeleteConfirm() {
        _audioState.update { it.copy(showDeleteConfirm = false) }
    }

    /** Delete the currently playing local recording. */
    fun deleteCurrentRecording() {
        val src = _audioState.value.currentSource
        if (src is PlaybackSource.Local) {
            stopAudioPlayback()
            localRecordingStore.deleteRecording(src.recording)
            loadRecordingsForCurrentQuote()

            // Auto-select next or switch to recording mode
            val remaining = _audioState.value.playlist.filterNot {
                it is PlaybackSource.Local && it.recording.id == src.recording.id
            }
            _audioState.update { it.copy(showDeleteConfirm = false, currentSource = null, playlist = remaining) }
            if (remaining.isNotEmpty()) {
                when (val next = remaining.first()) {
                    is PlaybackSource.Local -> playLocalRecording(next.recording)
                    is PlaybackSource.Community -> playCommunityRecording(next.recording)
                }
            } else {
                _audioState.update { it.copy(isRecordingMode = true) }
                showRecordingPicker()
            }
        }
    }

    /** Open save sheet for editing current recording name. */
    fun editCurrentRecording() {
        val src = _audioState.value.currentSource
        if (src is PlaybackSource.Local) {
            _audioState.update { it.copy(
                editingRecordingName = src.recording.name ?: "",
                showSaveSheet = true
            )}
        }
    }

    /** Rename an existing local recording. */
    fun renameRecording(newName: String) {
        val src = _audioState.value.currentSource
        if (src is PlaybackSource.Local) {
            localRecordingStore.updateRecordingName(src.recording.id, newName)
            val updated = src.recording.copy(name = newName)
            _audioState.update { it.copy(
                currentSource = PlaybackSource.Local(updated),
                showSaveSheet = false,
                editingRecordingName = null
            )}
            loadRecordingsForCurrentQuote()
        }
    }

    /** Update recording name and optionally share with community. */
    fun updateRecording(newName: String, shareWithCommunity: Boolean) {
        val src = _audioState.value.currentSource
        if (src is PlaybackSource.Local) {
            localRecordingStore.updateRecordingName(src.recording.id, newName)
            val updated = src.recording.copy(name = newName)
            _audioState.update { it.copy(
                currentSource = PlaybackSource.Local(updated),
                showSaveSheet = false,
                editingRecordingName = null
            )}
            loadRecordingsForCurrentQuote()

            // Upload to community if requested
            if (shareWithCommunity) {
                val audioData = localRecordingStore.loadAudioData(src.recording) ?: return
                val q = quote ?: return
                viewModelScope.launch(Dispatchers.IO) {
                    try {
                        recordingService.uploadRecording(
                            audioData = audioData,
                            quoteTextHash = src.recording.quoteTextHash,
                            quoteTitle = q.displayTitle,
                            durationSeconds = src.recording.durationSeconds,
                            language = src.recording.language
                        )
                    } catch (e: Exception) {
                        Log.w(TAG, "Upload failed: ${e.message}")
                    }
                }
            }
        }
    }

    /** Get the language for the current audio context. */
    // ---------------------------------------------------------------------------
    // Language Switching
    // ---------------------------------------------------------------------------

    /** The currently active language code (original or translation) */
    fun getActiveLanguageCode(): String = activeLanguage ?: quote?.primaryLanguage ?: "en"

    fun getQuoteLanguage(): String = getActiveLanguageCode()

    /** Available translation language codes (excluding primary) */
    fun getAvailableLanguages(): List<String> {
        return quote?.translations?.keys?.sorted() ?: emptyList()
    }

    /** Whether this quote has translations */
    fun hasTranslations(): Boolean = !quote?.translations.isNullOrEmpty()

    /** The primary (original) language code */
    fun getPrimaryLanguageCode(): String = quote?.primaryLanguage ?: "en"

    /** The text for the currently active language */
    private fun getActiveText(): String {
        val lang = activeLanguage ?: return quote?.text ?: ""
        return quote?.translations?.get(lang)?.text ?: quote?.text ?: ""
    }

    /** The title for the currently active language */
    fun getActiveTitle(): String {
        val lang = activeLanguage ?: return quote?.title ?: ""
        return quote?.translations?.get(lang)?.title ?: quote?.title ?: ""
    }

    fun switchLanguage(language: String?) {
        if (language == activeLanguage) return
        val q = quote ?: return

        // Stop listening if active
        if (_uiState.value.isListening) pauseRecitation()

        activeLanguage = language

        // Reconfigure comparator with new text
        val text = getActiveText()
        comparator.setTargetText(text, language ?: q.primaryLanguage)

        // Reset word state
        val targetWords = comparator.getTargetWords()
        val level = _uiState.value.displayLevel
        val revealPct = revealPercentageForLevel(level)

        val wordDisplays = targetWords.mapIndexed { index, word ->
            WordDisplay(
                text = word,
                state = if (index == 0) WordState.CURRENT else WordState.UPCOMING
            )
        }

        mistakes.clear()
        previousWordWasMistake = false
        sessionStartTime = null
        pendingMismatch = null
        pendingMismatchJob?.cancel()
        consecutiveMismatchesAtPosition = 0
        lastMismatchPosition = -1

        _uiState.update { state ->
            state.copy(
                words = wordDisplays,
                currentPosition = 0,
                isComplete = false,
                accuracy = 0.0,
                mistakeCount = 0,
                correctCount = 0,
                hintCount = 0,
                totalWords = targetWords.size,
                testedWordCount = 0,
                tappedMistakeIndex = null,
                tappedMistakeSpoken = null,
                flashingWordIndex = null,
                typingInput = "",
                mcChoices = emptyList(),
                masterResult = null
            )
        }

        applyRevealPercentage()

        if (_uiState.value.currentMode == MemorizationMode.MULTIPLE_CHOICE) {
            generateChoices()
        }

        // Update audio hash for recordings lookup
        quoteTextHash = recordingService.hashQuoteText(text)

        // If TTS is currently active, restart it in the new language.
        if (_audioState.value.isTTSActive) {
            ttsService.stop()
            startTTS()
        }
    }

    fun getAudioLanguage(): String {
        val state = _audioState.value
        return when {
            state.currentSource is PlaybackSource.Local -> (state.currentSource as PlaybackSource.Local).recording.language
            state.currentSource is PlaybackSource.Community -> (state.currentSource as PlaybackSource.Community).recording.language
            else -> getActiveLanguageCode()
        }
    }

    // ---------------------------------------------------------------------------
    // Reveal System
    // ---------------------------------------------------------------------------

    private fun revealPercentageForLevel(level: Int): Double = when (level) {
        1 -> 90.0
        2 -> 50.0
        3 -> 20.0
        else -> 90.0
    }

    private fun letterStepForLevel(level: Int): Int = when (level) {
        1 -> 3
        2 -> 2
        3 -> 1
        else -> 3
    }

    fun applyTutorialReveal(revealedIndices: Set<Int>) {
        tutorialRevealActive = true
        _uiState.update { state ->
            val updatedWords = state.words.mapIndexed { index, word ->
                word.copy(isRevealed = revealedIndices.contains(index))
            }
            state.copy(words = updatedWords)
        }
    }

    fun setDisplayLevel(level: Int) {
        if (_uiState.value.isMasterMode) return // locked in master mode
        val clamped = level.coerceIn(1, 3)
        if (clamped == _uiState.value.displayLevel) return
        tutorialRevealActive = false
        val pct = revealPercentageForLevel(clamped)
        val step = letterStepForLevel(clamped)
        _uiState.update { it.copy(displayLevel = clamped, revealPercentage = pct, letterRevealStep = step) }
        applyRevealPercentage()
        // Regenerate MC choices when reveal changes
        if (_uiState.value.currentMode == MemorizationMode.MULTIPLE_CHOICE) {
            generateChoices()
        }
    }

    fun toggleFirstLetterMode() {
        if (_uiState.value.isMasterMode) return // disabled in master mode
        _uiState.update { it.copy(isFirstLetterToggle = !it.isFirstLetterToggle) }
    }

    private fun applyRevealPercentage() {
        _uiState.update { state ->
            val currentPos = state.currentPosition
            val revealPct = state.revealPercentage

            // In tutorial mode, include all words so percentages work with small word counts
            val pendingIndices = if (isTutorialMode) {
                state.words.indices.toList()
            } else {
                state.words.mapIndexedNotNull { index, word ->
                    if (index > currentPos && word.state == WordState.UPCOMING) index else null
                }
            }

            // Calculate how many to reveal
            val revealCount = (pendingIndices.size * (revealPct / 100.0)).toInt()

            // Randomly select which words to reveal (truly random each time, matching iOS)
            val indicesToReveal = pendingIndices.shuffled().take(revealCount).toSet()

            val updatedWords = state.words.mapIndexed { index, word ->
                if (index in indicesToReveal) {
                    word.copy(isRevealed = true)
                } else if (index > currentPos && word.state == WordState.UPCOMING) {
                    word.copy(isRevealed = false)
                } else {
                    word
                }
            }

            state.copy(words = updatedWords)
        }
    }

    /** Determine how a word should be displayed at a given index. */
    fun wordDisplayMode(index: Int): WordDisplayMode {
        val state = _uiState.value
        val word = state.words.getOrNull(index) ?: return WordDisplayMode.FULL

        // Already spoken words: always show full
        if (word.state == WordState.CORRECT || word.state == WordState.INCORRECT) return WordDisplayMode.FULL

        // Flashing hint: show full
        if (state.flashingWordIndex == index) return WordDisplayMode.FULL

        // Current word visibility depends on reveal slider (isRevealed flag)
        val isInputMode = state.currentMode == MemorizationMode.TYPING || state.currentMode == MemorizationMode.MULTIPLE_CHOICE
        val isVoiceFirstLetter = state.isFirstLetterToggle && state.currentMode == MemorizationMode.VOICE

        if (word.state == WordState.CURRENT) {
            // Master mode: always hide current word
            if (state.isMasterMode) return WordDisplayMode.HIDDEN
            // Voice+FL: handled below (partial letters)
            if (isVoiceFirstLetter) { /* fall through to first-letter logic below */ }
            // Revealed by slider: show full
            else if (word.isRevealed) return WordDisplayMode.FULL
            // Not revealed: hide it
            else return WordDisplayMode.HIDDEN
        }
        if (word.state == WordState.PENDING) return WordDisplayMode.FULL

        // Partial letter display ONLY in voice + first-letter mode.
        // In voice+FL, the slider controls letter count (1/2/3), NOT which words are revealed.
        // So we check this BEFORE the isRevealed check.
        if (state.isFirstLetterToggle && state.currentMode == MemorizationMode.VOICE) {
            return when (state.letterRevealStep) {
                1 -> WordDisplayMode.FIRST_LETTER_1
                2 -> WordDisplayMode.FIRST_LETTER_2
                else -> WordDisplayMode.FIRST_LETTER_3
            }
        }

        // Revealed by slider: show full (normal/typing/MC modes only — voice+FL handled above)
        if (word.isRevealed) return WordDisplayMode.FULL

        // Hidden
        return WordDisplayMode.HIDDEN
    }

    // ---------------------------------------------------------------------------
    // Tap-to-Peek (Hint) & Dispute
    // ---------------------------------------------------------------------------

    fun tapWord(index: Int) {
        val state = _uiState.value
        val word = state.words.getOrNull(index) ?: return

        // Tap incorrect word → dispute
        if (word.state == WordState.INCORRECT) {
            val mistake = mistakes.lastOrNull { it.position == index }
            _uiState.update {
                it.copy(
                    tappedMistakeIndex = index,
                    tappedMistakeSpoken = mistake?.spokenWord ?: ""
                )
            }
            return
        }

        // Master mode: block hints
        if (_uiState.value.isMasterMode && (word.state == WordState.UPCOMING || word.state == WordState.CURRENT)) {
            _uiState.update { it.copy(showMasterHintBlock = true) }
            return
        }

        // Tap hidden/pending word → hint peek (UPCOMING or CURRENT in typing/MC modes)
        if ((word.state == WordState.UPCOMING || word.state == WordState.CURRENT) && !word.isRevealed && wordDisplayMode(index) != WordDisplayMode.FULL) {
            _uiState.update { it.copy(hintCount = it.hintCount + 1, flashingWordIndex = index) }
            flashJob?.cancel()
            flashJob = viewModelScope.launch(Dispatchers.Main) {
                delay(1000L)
                _uiState.update { it.copy(flashingWordIndex = null) }
            }
        }
    }

    fun dismissMistakePopup() {
        _uiState.update { it.copy(tappedMistakeIndex = null, tappedMistakeSpoken = null) }
    }

    fun overrideMistake() {
        val state = _uiState.value
        val index = state.tappedMistakeIndex ?: return

        // Remove all mistakes at this position
        mistakes.removeAll { it.position == index }

        // Mark word as correct
        markWordState(index, WordState.CORRECT)

        _uiState.update {
            it.copy(
                mistakeCount = mistakes.size,
                correctCount = computeCorrectCount(),
                tappedMistakeIndex = null,
                tappedMistakeSpoken = null
            )
        }
    }

    // ---------------------------------------------------------------------------
    // Recitation Control (Voice Mode)
    // ---------------------------------------------------------------------------

    fun startRecitation() {
        speechService.delegate = this
        if (sessionStartTime == null) sessionStartTime = Date()

        val langCode = (activeLanguage ?: quote?.primaryLanguage)?.takeIf { it.isNotBlank() }
        val locale = langCode?.let { localeForLanguageCode(it) } ?: Locale.getDefault()
        Log.d(TAG, "startRecitation: langCode=$langCode locale=${locale.toLanguageTag()}")

        speechService.startListening(locale)
        _uiState.update { it.copy(isListening = true, isPaused = false, showPauseIcon = false, speechError = null) }
        resetSilenceTimer()
    }

    fun stopRecitation() {
        pendingMismatchJob?.cancel()
        pendingMismatch = null
        silenceJob?.cancel()
        speechService.stopListening()
        _uiState.update { it.copy(isListening = false, showPauseIcon = false) }
    }

    fun pauseRecitation() {
        speechService.stopListening()
        silenceJob?.cancel()
        _uiState.update { it.copy(isListening = false, isPaused = true, showPauseIcon = false) }
    }

    fun resumeRecitation() {
        speechService.delegate = this
        if (sessionStartTime == null) sessionStartTime = Date()

        val langCode = (activeLanguage ?: quote?.primaryLanguage)?.takeIf { it.isNotBlank() }
        val locale = langCode?.let { localeForLanguageCode(it) } ?: Locale.getDefault()

        speechService.startListening(locale)
        _uiState.update { it.copy(isListening = true, isPaused = false, showPauseIcon = false) }
        resetSilenceTimer()
    }

    /**
     * Reset the current recitation.
     * @param recalculateReveal When true (e.g. "Try Again" after completion),
     *   refreshes reveal from the quote's level. When false (footer reset button),
     *   keeps the current slider position but re-randomizes which words are revealed.
     */
    fun resetSession(recalculateReveal: Boolean = true) {
        val q = quote ?: return
        if (recalculateReveal) {
            setQuote(q)
        } else {
            // Keep current display level and reveal percentage, just reset words
            val savedLevel = _uiState.value.displayLevel
            val savedPct = _uiState.value.revealPercentage
            val savedLetterStep = _uiState.value.letterRevealStep
            val savedFirstLetter = _uiState.value.isFirstLetterToggle
            val savedMode = _uiState.value.currentMode

            stopRecitation()

            val comparatorText = getActiveText().ifEmpty { q.text }
            val comparatorLang = activeLanguage ?: q.primaryLanguage
            comparator.setTargetText(comparatorText, comparatorLang)

            val targetWords = comparator.getTargetWords()
            val wordDisplays = targetWords.mapIndexed { index, word ->
                WordDisplay(
                    text = word,
                    state = if (index == 0) WordState.CURRENT else WordState.UPCOMING
                )
            }

            _uiState.update { state ->
                state.copy(
                    words = wordDisplays,
                    currentPosition = 0,
                    isComplete = false,
                    accuracy = 0.0,
                    mistakeCount = 0,
                    correctCount = 0,
                    hintCount = 0,
                    totalWords = targetWords.size,
                    testedWordCount = 0,
                    audioLevel = 0f,
                    showMistakeFlash = false,
                    isPaused = false,
                    displayLevel = savedLevel,
                    revealPercentage = savedPct,
                    letterRevealStep = savedLetterStep,
                    isFirstLetterToggle = savedFirstLetter,
                    flashingWordIndex = null,
                    showPauseIcon = false,
                    tappedMistakeIndex = null,
                    tappedMistakeSpoken = null,
                    typingInput = "",
                    mcChoices = emptyList(),
                    mcCorrectIndex = -1,
                    mcWrongIndex = null,
                    showSplitOverlay = false,
                    speechError = null,
                    currentMode = savedMode
                )
            }

            applyRevealPercentage()

            if (savedMode == MemorizationMode.MULTIPLE_CHOICE) {
                generateChoices()
            }
        }
    }

    /** Hide the completion overlay without resetting the session. */
    fun dismissCompletion() {
        alertManager.stopResultSound()
        _uiState.update { it.copy(isComplete = false) }
    }

    /** Stop any playing result sounds. */
    fun stopResultSound() {
        alertManager.stopResultSound()
    }

    // ---------------------------------------------------------------------------
    // Typing Mode
    // ---------------------------------------------------------------------------

    fun updateTypingInput(input: String) {
        _uiState.update { it.copy(typingInput = input) }
    }

    /** Submit with explicit input text (avoids state race with BasicTextField). */
    fun submitTypingInput(directInput: String? = null) {
        val state = _uiState.value
        val input = (directInput ?: state.typingInput).trim()
        Log.d(TAG, "submitTypingInput: input='$input' pos=${state.currentPosition}/${state.words.size} FL=${state.isFirstLetterToggle}")
        if (input.isEmpty()) return
        if (state.currentPosition >= state.words.size) return

        _uiState.update { it.copy(typingInput = "") }

        if (sessionStartTime == null) sessionStartTime = Date()

        val pos = state.currentPosition
        val expectedWord = state.words[pos].text

        if (state.isFirstLetterToggle) {
            // First-letter mode: compare first character only
            val expectedFirstLetter = expectedWord
                .firstOrNull { it.isLetterOrDigit() }
                ?.lowercaseChar() ?: return
            val typedFirstLetter = input.firstOrNull()?.lowercaseChar() ?: return
            val totalWords = state.words.size

            if (typedFirstLetter == expectedFirstLetter) {
                markWordState(pos, WordState.CORRECT)
                if (previousWordWasMistake) {
                    alertManager.triggerCorrectWordSound()
                    previousWordWasMistake = false
                }
            } else {
                markWordState(pos, WordState.INCORRECT)
                previousWordWasMistake = true
                alertManager.triggerMistakeAlert()
                mistakes.add(ComparisonResult(
                    isMatch = false, position = pos,
                    spokenWord = input, expectedWord = expectedWord,
                    normalizedExpected = expectedWord.lowercase().filter { it.isLetterOrDigit() },
                    normalizedSpoken = input.lowercase().filter { it.isLetterOrDigit() },
                    confidence = 1f
                ))
                checkMasterModeEarlyFail()
                if (_uiState.value.isComplete) return
            }

            val nextPos = pos + 1
            Log.d(TAG, "FL typing: pos=$pos nextPos=$nextPos totalWords=$totalWords")
            if (nextPos < totalWords) {
                markWordState(nextPos, WordState.CURRENT)
            }
            _uiState.update {
                it.copy(
                    currentPosition = nextPos,
                    correctCount = computeCorrectCount(),
                    mistakeCount = mistakes.size
                )
            }
            if (nextPos >= totalWords) {
                Log.d(TAG, "FL typing: completing session!")
                completeSession()
                return
            }
        } else {
            // Normal typing: full word comparison
            val normalizedTyped = input.lowercase().filter { it.isLetterOrDigit() }
            val normalizedExpected = expectedWord.lowercase().filter { it.isLetterOrDigit() }

            if (normalizedTyped == normalizedExpected) {
                markWordState(pos, WordState.CORRECT)
                if (previousWordWasMistake) {
                    alertManager.triggerCorrectWordSound()
                    previousWordWasMistake = false
                }
                val nextPos = findNextHiddenWord(pos + 1)
                if (nextPos < state.words.size) {
                    markWordState(nextPos, WordState.CURRENT)
                }
                _uiState.update {
                    it.copy(
                        currentPosition = nextPos,
                        correctCount = computeCorrectCount(),
                        mistakeCount = mistakes.size
                    )
                }
                if (nextPos >= state.words.size) {
                    completeSession()
                }
            } else {
                // Mistake
                markWordState(pos, WordState.INCORRECT)
                previousWordWasMistake = true
                alertManager.triggerMistakeAlert()
                mistakes.add(ComparisonResult(
                    isMatch = false, position = pos,
                    spokenWord = input, expectedWord = expectedWord,
                    normalizedExpected = expectedWord.lowercase().filter { it.isLetterOrDigit() },
                    normalizedSpoken = input.lowercase().filter { it.isLetterOrDigit() },
                    confidence = 1f
                ))
                checkMasterModeEarlyFail()
                if (_uiState.value.isComplete) return
                val nextPos = findNextHiddenWord(pos + 1)
                if (nextPos < state.words.size) {
                    markWordState(nextPos, WordState.CURRENT)
                }
                _uiState.update {
                    it.copy(
                        currentPosition = nextPos,
                        correctCount = computeCorrectCount(),
                        mistakeCount = mistakes.size
                    )
                }
                if (nextPos >= state.words.size) {
                    completeSession()
                }
            }
        }
    }

    /** Skip current position to next hidden word (not revealed). */
    private fun skipToNextHiddenWord() {
        val state = _uiState.value
        val nextPos = findNextHiddenWord(state.currentPosition)
        if (nextPos != state.currentPosition) {
            // Clear current marker from old position
            if (state.currentPosition < state.words.size) {
                val oldWord = state.words[state.currentPosition]
                if (oldWord.state == WordState.CURRENT) {
                    markWordState(state.currentPosition, WordState.UPCOMING)
                }
            }
            if (nextPos < state.words.size) {
                markWordState(nextPos, WordState.CURRENT)
            }
            _uiState.update { it.copy(currentPosition = nextPos) }
        }
    }

    /** Find next word index that is hidden (not revealed, not already spoken).
     *  In typing+FL mode, all words are tested sequentially (no skipping).
     *  In normal typing/MC, skip revealed words. */
    private fun findNextHiddenWord(fromIndex: Int): Int {
        val state = _uiState.value
        // In first-letter mode or master mode, test ALL words sequentially
        if (state.isFirstLetterToggle || state.isMasterMode) return fromIndex

        var i = fromIndex
        while (i < state.words.size) {
            val word = state.words[i]
            if (word.state == WordState.UPCOMING || word.state == WordState.CURRENT) {
                if (!word.isRevealed) return i
            }
            i++
        }
        return i // past end = complete
    }

    // ---------------------------------------------------------------------------
    // Multiple Choice Mode
    // ---------------------------------------------------------------------------

    fun generateChoices() {
        val state = _uiState.value
        if (state.currentPosition >= state.words.size) return

        val correctWord = state.words[state.currentPosition].text

        // Gather decoy words from the quote
        val decoys = mutableListOf<String>()
        val usedKeys = mutableSetOf(correctWord.lowercase())
        val shuffledIndices = state.words.indices.shuffled()

        for (idx in shuffledIndices) {
            if (decoys.size >= 3) break
            val candidate = state.words[idx].text
            val key = candidate.lowercase()
            if (key !in usedKeys) {
                usedKeys.add(key)
                decoys.add(candidate)
            }
        }

        // Fallback words if quote is too short
        val fallbacks = listOf("and", "the", "but", "for")
        for (fb in fallbacks) {
            if (decoys.size >= 3) break
            if (fb !in usedKeys) {
                usedKeys.add(fb)
                decoys.add(fb)
            }
        }

        val options = (listOf(correctWord) + decoys.take(3)).shuffled()
        val correctIndex = options.indexOf(correctWord)

        _uiState.update { it.copy(mcChoices = options, mcCorrectIndex = correctIndex, mcWrongIndex = null) }
    }

    fun selectChoice(index: Int) {
        val state = _uiState.value
        if (index !in state.mcChoices.indices) return
        if (state.currentPosition >= state.words.size) return

        if (sessionStartTime == null) sessionStartTime = Date()

        val pos = state.currentPosition

        if (index == state.mcCorrectIndex) {
            // Correct selection
            markWordState(pos, WordState.CORRECT)
            if (previousWordWasMistake) {
                alertManager.triggerCorrectWordSound()
                previousWordWasMistake = false
            }
            val nextPos = findNextHiddenWord(pos + 1)
            if (nextPos < state.words.size) {
                markWordState(nextPos, WordState.CURRENT)
            }
            _uiState.update {
                it.copy(
                    currentPosition = nextPos,
                    correctCount = computeCorrectCount(),
                    mistakeCount = mistakes.size
                )
            }
            if (nextPos >= state.words.size) {
                completeSession()
            } else {
                generateChoices()
            }
        } else {
            // Wrong selection
            val expectedWord = state.words[pos].text
            val chosenWord = state.mcChoices[index]
            markWordState(pos, WordState.INCORRECT)
            previousWordWasMistake = true
            alertManager.triggerMistakeAlert()
            mistakes.add(ComparisonResult(
                isMatch = false, position = pos,
                spokenWord = chosenWord, expectedWord = expectedWord,
                normalizedExpected = expectedWord.lowercase().filter { it.isLetterOrDigit() },
                normalizedSpoken = chosenWord.lowercase().filter { it.isLetterOrDigit() },
                confidence = 1f
            ))
            checkMasterModeEarlyFail()
            if (_uiState.value.isComplete) return

            // Show wrong button flash
            _uiState.update { it.copy(mcWrongIndex = index) }
            mcWrongJob?.cancel()
            mcWrongJob = viewModelScope.launch(Dispatchers.Main) {
                delay(400L)
                _uiState.update { it.copy(mcWrongIndex = null) }
            }

            val nextPos = findNextHiddenWord(pos + 1)
            if (nextPos < state.words.size) {
                markWordState(nextPos, WordState.CURRENT)
            }
            _uiState.update {
                it.copy(
                    currentPosition = nextPos,
                    correctCount = computeCorrectCount(),
                    mistakeCount = mistakes.size
                )
            }
            if (nextPos >= state.words.size) {
                completeSession()
            } else {
                generateChoices()
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Silence Detection (2s → show pause icon)
    // ---------------------------------------------------------------------------

    private fun resetSilenceTimer() {
        silenceJob?.cancel()
        _uiState.update { it.copy(showPauseIcon = false) }
        silenceJob = viewModelScope.launch(Dispatchers.Main) {
            delay(2000L)
            if (_uiState.value.isListening) {
                _uiState.update { it.copy(showPauseIcon = true) }
            }
        }
    }

    // ---------------------------------------------------------------------------
    // SpeechRecognitionDelegate
    // ---------------------------------------------------------------------------

    override fun onWord(word: String, confidence: Float) {
        resetSilenceTimer()

        val result = comparator.compareWord(word, confidence) ?: return

        if (result.isMatch) {
            pendingMismatchJob?.cancel()
            pendingMismatch = null
            consecutiveMismatchesAtPosition = 0

            // If look-ahead jumped over positions, mark them as CORRECT.
            // The user likely said them but they were lost during Android's
            // SpeechRecognizer session gap. Matches iOS behavior (lines 1973-1980).
            if (result.skippedPositions.isNotEmpty()) {
                Log.i(TAG, "Look-ahead: marking ${result.skippedPositions.size} skipped positions as correct: ${result.skippedPositions}")
                for (pos in result.skippedPositions) {
                    markWordState(pos, WordState.CORRECT)
                }
            }

            markWordState(result.position, WordState.CORRECT)

            // Play recovery sound if previous was a mistake
            if (previousWordWasMistake) {
                alertManager.triggerCorrectWordSound()
                previousWordWasMistake = false
            }

            val newPosition = comparator.currentPosition
            if (newPosition < _uiState.value.words.size) {
                markWordState(newPosition, WordState.CURRENT)
            }

            _uiState.update { state ->
                state.copy(
                    currentPosition = newPosition,
                    mistakeCount = mistakes.size,
                    correctCount = computeCorrectCount()
                )
            }

            if (comparator.isComplete) {
                completeSession()
            }
        } else {
            // If a mismatch is already pending, DON'T replace it — the first
            // wrong word is the real mistake. Subsequent words at the same position
            // are ignored; the pending fires via its timer. (Matches iOS logic)
            if (pendingMismatch != null) {
                Log.d(TAG, "Ignoring mismatch \"${result.spokenWord}\" at pos=${result.position} — pending already exists")
                return
            }

            // Track consecutive mismatches at same position
            if (result.position == lastMismatchPosition) {
                consecutiveMismatchesAtPosition++
            } else {
                consecutiveMismatchesAtPosition = 0
                lastMismatchPosition = result.position
            }

            // Adaptive settle interval (matches iOS)
            val charCount = word.length
            val baseMs = MIN_SETTLE_MS + ((charCount - 4).coerceAtLeast(0) * 60L)
            val consecutiveExtra = consecutiveMismatchesAtPosition * 300L
            val confidenceExtra = if (confidence in 0.01f..0.85f) 200L else 0L
            val settleMs = (baseMs + consecutiveExtra + confidenceExtra).coerceIn(MIN_SETTLE_MS, MAX_SETTLE_MS)

            pendingMismatch = result
            // Don't change word visual state — keep it as CURRENT during settlement
            // iOS doesn't show a yellow pending state; the word stays current until confirmed

            pendingMismatchJob = viewModelScope.launch(Dispatchers.Main) {
                delay(settleMs)
                confirmMismatch(result)
            }
        }
    }

    override fun onAudioLevel(level: Float) {
        _uiState.update { it.copy(audioLevel = level) }
    }

    override fun onError(error: String) {
        Log.e(TAG, "Speech recognition error: $error")
        _uiState.update { it.copy(speechError = error) }
    }

    override fun onSessionRestart() {
        Log.d(TAG, "Speech session restarted")
    }

    // ---------------------------------------------------------------------------
    // Mismatch Confirmation
    // ---------------------------------------------------------------------------

    private fun confirmMismatch(result: ComparisonResult) {
        // Last chance: try matching the spoken word against upcoming positions.
        // First try next-word recovery (no min length — handles short words like "of", "all")
        // Then fall back to general tryMatchAhead (requires 4+ chars).
        // Use a larger maxJump (5) here vs normal processing (2) because:
        // - We've already waited the settle interval, so higher confidence this is real
        // - Session gaps can lose 3-4 words, requiring bigger jumps to resync
        val matchedAhead = comparator.tryMatchNext(result.spokenWord)
            ?: comparator.tryMatchAhead(result.spokenWord, range = 5, maxJump = 5)
        if (matchedAhead != null) {
            // Clear pending FIRST — this was causing the app to get permanently stuck.
            // Without this, subsequent mismatches would see "pending already exists" forever.
            pendingMismatch = null

            // Mark skipped positions as CORRECT — the user likely said them but they
            // were lost during Android's SpeechRecognizer session gap. Matches iOS behavior.
            if (matchedAhead.skippedPositions.isNotEmpty()) {
                Log.i(TAG, "Sync recovery: marking ${matchedAhead.skippedPositions.size} skipped positions as correct: ${matchedAhead.skippedPositions}")
                for (pos in matchedAhead.skippedPositions) {
                    markWordState(pos, WordState.CORRECT)
                }
            }
            markWordState(matchedAhead.position, WordState.CORRECT)
            val newPosition = comparator.currentPosition
            if (newPosition < _uiState.value.words.size) {
                markWordState(newPosition, WordState.CURRENT)
            }
            _uiState.update { state ->
                state.copy(
                    currentPosition = newPosition,
                    mistakeCount = mistakes.size,
                    correctCount = computeCorrectCount()
                )
            }
            if (comparator.isComplete) completeSession()
            return
        }

        // Confirmed mistake
        mistakes.add(result)
        previousWordWasMistake = true
        markWordState(result.position, WordState.INCORRECT)

        alertManager.triggerMistakeAlert()

        // Advance position past the mistake
        comparator.advancePosition()
        val newPosition = comparator.currentPosition
        if (newPosition < _uiState.value.words.size) {
            markWordState(newPosition, WordState.CURRENT)
        }

        _uiState.update {
            it.copy(
                mistakeCount = mistakes.size,
                correctCount = computeCorrectCount(),
                currentPosition = newPosition
            )
        }

        pendingMismatch = null

        // Early fail in master mode if 95% is no longer reachable
        checkMasterModeEarlyFail()
        if (!_uiState.value.isComplete && comparator.isComplete) completeSession()
    }

    // ---------------------------------------------------------------------------
    // Session Completion
    // ---------------------------------------------------------------------------

    private fun completeSession() {
        stopRecitation()

        val state = _uiState.value
        val tested = state.words.count { it.state == WordState.CORRECT || it.state == WordState.INCORRECT }
        val correct = computeCorrectCount()
        val accuracy = if (tested > 0) correct.toDouble() / tested.toDouble() else 0.0

        // In master mode, only play win sound if passed (95%+), otherwise fail
        if (_uiState.value.isMasterMode) {
            if (accuracy >= 0.95) alertManager.triggerResultSound(accuracy)
            else alertManager.triggerResultFailSound()
        } else {
            alertManager.triggerResultSound(accuracy)
        }

        // Record session to QuoteStore for stats tracking
        val q = quote
        if (q != null && sessionStartTime != null) {
            val session = com.memorezar.app.data.models.PracticeSession(
                quoteId = q.id,
                startedAt = sessionStartTime!!.time,
                completedAt = System.currentTimeMillis(),
                totalWords = state.totalWords,
                testedWords = tested,
                correctWords = correct,
                mistakes = mistakes.map { m ->
                    com.memorezar.app.data.models.PracticeMistake(
                        position = m.position,
                        expectedWord = m.expectedWord,
                        spokenWord = m.spokenWord,
                        confidence = m.confidence
                    )
                },
                revealPercentage = q.revealPercentageForLevel
            )
            quoteStore.recordSession(session)

            // Refresh local quote from store to pick up updated practiceCount, lastPracticedAt, etc.
            // Also persist the language the user practiced in so the quote reopens
            // in that language and Home / Library cards show the right translation.
            val currentQuote = quoteStore.getQuote(q.id)
            if (currentQuote != null) {
                if (currentQuote.lastPracticedLanguage != activeLanguage) {
                    currentQuote.lastPracticedLanguage = activeLanguage
                    quoteStore.updateQuote(currentQuote)
                }
                this.quote = currentQuote
            }

            // Promote / demote the reveal level based on this session's accuracy.
            // Skip in master mode and while split (per-chunk accuracy isn't representative).
            if (!_uiState.value.isMasterMode && !isSplit) {
                checkLevelAdvancement(accuracy)
            }
        }

        // Split mode: persist progress + try to advance to the next unfinished chunk.
        if (isSplit) {
            saveSplitState()
            if (advanceToNextChunk()) return
        }

        _uiState.update {
            it.copy(
                isComplete = true,
                accuracy = accuracy,
                correctCount = correct,
                testedWordCount = tested,
                isListening = false
            )
        }
    }

    // ---------------------------------------------------------------------------
    // Reveal Level Advancement (mirrors iOS RecitationViewModel.checkLevelAdvancement)
    // ---------------------------------------------------------------------------

    /**
     * Rules:
     *  - accuracy < 70% → demote one level (floor at 1)
     *  - accuracy ≥ 90% and below level 3 → advance, but only if the reveal % actually
     *    used in the session supports the current level (can't cheat by revealing more)
     *  - achieved level from reveal %: ≤20 → 3, ≤50 → 2, else 1
     */
    private fun checkLevelAdvancement(accuracy: Double) {
        val q = quote ?: return
        val currentLevel = maxOf(1, q.revealLevel)
        val revealUsed = _uiState.value.revealPercentage

        // Demote
        if (accuracy < 0.70 && currentLevel > 1) {
            q.revealLevel = currentLevel - 1
            quoteStore.updateQuote(q)
            return
        }

        if (accuracy < 0.90) return
        if (currentLevel >= 3) return

        val achieved = when {
            revealUsed <= 20.0 -> 3
            revealUsed <= 50.0 -> 2
            else -> 1
        }
        if (achieved < currentLevel) return

        val newLevel = minOf(3, achieved + 1)
        if (newLevel <= currentLevel) return

        q.revealLevel = newLevel
        quoteStore.updateQuote(q)
    }

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    private fun flashMistake() {
        _uiState.update { it.copy(showMistakeFlash = true) }
        viewModelScope.launch(Dispatchers.Main) {
            delay(150L)
            _uiState.update { it.copy(showMistakeFlash = false) }
        }
    }

    private fun computeCorrectCount(): Int {
        return _uiState.value.words.count { it.state == WordState.CORRECT }
    }

    private fun markWordState(position: Int, state: WordState) {
        _uiState.update { uiState ->
            val updatedWords = uiState.words.toMutableList()
            if (position in updatedWords.indices) {
                updatedWords[position] = updatedWords[position].copy(state = state)
            }
            uiState.copy(words = updatedWords)
        }
    }

    private fun localeForLanguageCode(code: String): Locale {
        // If the device's language matches the requested language, use the device locale.
        // This avoids error 11 on devices where e.g. en-GB is installed but en-US is not.
        val deviceLocale = Locale.getDefault()
        if (deviceLocale.language == code) {
            return deviceLocale
        }

        val localeMap = mapOf(
            "en" to "en-US", "es" to "es-ES", "fr" to "fr-FR", "de" to "de-DE",
            "pt" to "pt-BR", "ar" to "ar-SA", "it" to "it-IT", "ja" to "ja-JP",
            "zh" to "zh-CN", "ko" to "ko-KR", "ru" to "ru-RU", "hi" to "hi-IN",
            "tr" to "tr-TR", "nl" to "nl-NL", "pl" to "pl-PL", "sv" to "sv-SE"
        )
        val tag = localeMap[code] ?: "$code-${code.uppercase()}"
        return Locale.forLanguageTag(tag)
    }

    // ---------------------------------------------------------------------------
    // Master Mode
    // ---------------------------------------------------------------------------

    fun showQuoteInfo() {
        _uiState.update { it.copy(showQuoteInfo = true) }
    }

    fun dismissQuoteInfo() {
        _uiState.update { it.copy(showQuoteInfo = false) }
    }

    fun getQuoteForInfo(): Quote? = quote

    fun showMasterInfo() {
        _uiState.update { it.copy(showMasterInfoPopup = true) }
    }

    fun dismissMasterInfo() {
        _uiState.update { it.copy(showMasterInfoPopup = false) }
    }

    fun dismissMasterHintBlock() {
        _uiState.update { it.copy(showMasterHintBlock = false) }
    }

    fun enterMasterMode() {
        val q = quote ?: return
        _uiState.update { it.copy(
            showMasterInfoPopup = false,
            isMasterMode = true,
            isFirstLetterToggle = false,
            previousMasteryStreak = q.masteryStreak
        ) }

        // Reset session with 0% reveal (all hidden)
        resetMasterSession()
    }

    fun exitMasterMode() {
        _uiState.update { it.copy(isMasterMode = false, masterResult = null) }
        // Re-apply normal reveal
        val q = quote ?: return
        val level = q.revealLevel.coerceIn(1, 3)
        _uiState.update { it.copy(
            displayLevel = level,
            revealPercentage = revealPercentageForLevel(level),
            letterRevealStep = letterStepForLevel(level)
        ) }
        applyRevealPercentage()
    }

    private fun resetMasterSession() {
        val q = quote ?: return
        mistakes.clear()
        previousWordWasMistake = false
        sessionStartTime = null
        pendingMismatch = null
        pendingMismatchJob?.cancel()
        consecutiveMismatchesAtPosition = 0
        lastMismatchPosition = -1

        comparator.setTargetText(q.displayText, q.primaryLanguage)

        val targetWords = comparator.getTargetWords()
        val wordDisplays = targetWords.mapIndexed { index, word ->
            WordDisplay(text = word, state = if (index == 0) WordState.CURRENT else WordState.UPCOMING)
        }

        _uiState.update { state ->
            state.copy(
                words = wordDisplays,
                currentPosition = 0,
                isComplete = false,
                accuracy = 0.0,
                mistakeCount = 0,
                correctCount = 0,
                hintCount = 0,
                totalWords = targetWords.size,
                testedWordCount = 0,
                displayLevel = 3,
                revealPercentage = 0.0,
                letterRevealStep = 0,
                isFirstLetterToggle = false,
                flashingWordIndex = null,
                showPauseIcon = false,
                tappedMistakeIndex = null,
                tappedMistakeSpoken = null,
                typingInput = "",
                mcChoices = emptyList(),
                mcCorrectIndex = -1,
                mcWrongIndex = null,
                speechError = null,
                masterResult = null
            )
        }
        // 0% reveal: all words hidden
        applyRevealPercentage()
    }

    /** Check if master mode can still pass (need 95%+ accuracy). End session early if impossible. */
    private fun checkMasterModeEarlyFail() {
        val state = _uiState.value
        if (!state.isMasterMode) return

        val tested = state.words.count { it.state == WordState.CORRECT || it.state == WordState.INCORRECT }
        if (tested < 3) return // too early to judge

        val maxAllowedMistakes = (tested.toDouble() * 0.05).toInt()
        if (mistakes.size > maxAllowedMistakes) {
            // Auto-fail: end session early
            completeSession()
        }
    }

    /** Record mastery result and return the outcome */
    fun recordMasteryResult(quoteStore: com.memorezar.app.data.storage.QuoteStore = this.quoteStore): MasterResult {
        val q = quote ?: return MasterResult.FAILED
        val state = _uiState.value
        val passed = state.accuracy >= 0.95

        val result: MasterResult
        if (passed) {
            val newStreak = (q.masteryStreak + 1).coerceAtMost(3)
            val updated = q.copy(masteryStreak = newStreak)
            quoteStore.updateQuote(updated)
            quote = updated
            result = if (newStreak >= 3) MasterResult.MASTERED else MasterResult.PASSED
        } else {
            val updated = q.copy(masteryStreak = 0)
            quoteStore.updateQuote(updated)
            quote = updated
            result = MasterResult.FAILED
        }

        _uiState.update { it.copy(masterResult = result) }
        return result
    }

    // ---------------------------------------------------------------------------
    // Inline Split (Pass 1)
    // ---------------------------------------------------------------------------
    //
    // Mirrors iOS RecitationViewModel split feature. Pass 1 supports the bare
    // essentials: split active chunk into N pieces, navigate with chevrons,
    // unsplit, persistence, and auto-advance on completion. Recursive splits,
    // peek containers, merge ranges, and master-mode aggregation are deferred.

    private data class ChunkState(
        val chunkText: String,
        val words: List<WordDisplay>,
        val currentPosition: Int,
        val mistakes: List<ComparisonResult>,
        val hintCount: Int,
        val previousWordWasMistake: Boolean,
        val revealPercentage: Double
    )

    private var internalSplitChunks: MutableList<ChunkState>? = null
    private var activeChunkIndexInternal: Int = 0
    val isSplit: Boolean get() = internalSplitChunks != null

    fun openSplitOverlay() {
        val current = internalSplitChunks?.size ?: _uiState.value.splitCount
        _uiState.update { it.copy(showSplitOverlay = true, splitCount = current.coerceIn(2, 10)) }
    }

    fun dismissSplitOverlay() {
        _uiState.update { it.copy(showSplitOverlay = false) }
    }

    fun setSplitCount(n: Int) {
        _uiState.update { it.copy(splitCount = n.coerceIn(2, 10)) }
    }

    fun confirmSplit() {
        val n = _uiState.value.splitCount
        splitActiveChunk(n)
        _uiState.update { it.copy(showSplitOverlay = false) }
    }

    fun unsplitAndDismissOverlay() {
        unsplit()
        _uiState.update { it.copy(showSplitOverlay = false) }
    }

    fun mergeWithPreviousAndDismissOverlay() {
        if (activeChunkIndexInternal <= 0) return
        mergeChunks(activeChunkIndexInternal - 1)
        _uiState.update { it.copy(showSplitOverlay = false) }
    }

    /**
     * Merge chunk at [at] with chunk at [at + 1]. Single adjacent merge —
     * mirrors iOS `mergeChunks(at:)`. The first chunk absorbs the second's words,
     * mistakes, and hint count. If only one chunk remains after, fully unsplit.
     */
    fun mergeChunks(at: Int) {
        val chunks = internalSplitChunks ?: return
        if (at < 0 || at >= chunks.size - 1) return

        stopRecitation()
        saveCurrentChunkState()

        val first = chunks[at]
        val second = chunks[at + 1]

        val mergedText = first.chunkText + " " + second.chunkText

        // Reset second chunk's CURRENT marker to UPCOMING if the user hadn't started it.
        val secondWords = second.words.toMutableList()
        if (second.currentPosition == 0) {
            for (i in secondWords.indices) {
                if (secondWords[i].state == WordState.CURRENT) {
                    secondWords[i] = secondWords[i].copy(state = WordState.UPCOMING)
                    break
                }
            }
        }
        val mergedWords = first.words + secondWords

        val merged = ChunkState(
            chunkText = mergedText,
            words = mergedWords,
            currentPosition = first.currentPosition,
            mistakes = first.mistakes + second.mistakes,
            hintCount = first.hintCount + second.hintCount,
            previousWordWasMistake = first.previousWordWasMistake,
            revealPercentage = first.revealPercentage
        )

        chunks[at] = merged
        chunks.removeAt(at + 1)

        // If only one chunk left, fully unsplit.
        if (chunks.size <= 1) {
            unsplit()
            return
        }

        // Keep the active index pointing at a sensible chunk.
        activeChunkIndexInternal = when {
            activeChunkIndexInternal == at + 1 -> at
            activeChunkIndexInternal > at + 1 -> activeChunkIndexInternal - 1
            else -> activeChunkIndexInternal
        }.coerceAtMost(chunks.size - 1)

        loadChunk(activeChunkIndexInternal)
        publishSplitState()
        saveSplitState()
    }

    /** Compute lightweight per-chunk info (word count + completion/accuracy) for the UI. */
    private fun computeChunkInfos(): List<ChunkInfo> {
        val chunks = internalSplitChunks ?: return emptyList()
        return chunks.map { c ->
            val total = c.words.size
            val completed = c.words.count { it.state == WordState.CORRECT || it.state == WordState.INCORRECT }
            val isComplete = total > 0 && completed >= total
            val accuracy = if (isComplete) {
                (total - c.mistakes.size).coerceAtLeast(0).toDouble() / total.toDouble()
            } else null
            ChunkInfo(text = c.chunkText, wordCount = total, accuracy = accuracy, isComplete = isComplete)
        }
    }

    /** Push current split state to uiState. Called after every split mutation. */
    private fun publishSplitState() {
        val chunks = internalSplitChunks
        if (chunks == null) {
            _uiState.update {
                it.copy(splitChunks = null, splitChunkInfos = emptyList(), activeChunkIndex = 0)
            }
        } else {
            _uiState.update {
                it.copy(
                    splitChunks = chunks.map(ChunkState::chunkText),
                    splitChunkInfos = computeChunkInfos(),
                    activeChunkIndex = activeChunkIndexInternal
                )
            }
        }
    }

    private fun buildChunkState(text: String, revealPercentage: Double): ChunkState {
        val tokens = text.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
        val words = tokens.mapIndexed { i, w ->
            WordDisplay(text = w, state = if (i == 0) WordState.CURRENT else WordState.UPCOMING)
        }
        return ChunkState(
            chunkText = text,
            words = words,
            currentPosition = 0,
            mistakes = emptyList(),
            hintCount = 0,
            previousWordWasMistake = false,
            revealPercentage = revealPercentage
        )
    }

    private fun split(count: Int) {
        stopRecitation()
        val q = quote ?: return
        val activeText = getActiveText().ifEmpty { q.text }
        val chunkTexts = com.memorezar.app.core.chunking.TextChunker.split(activeText, count)
        val chunks = chunkTexts.map { buildChunkState(it, q.revealPercentageForLevel) }.toMutableList()
        internalSplitChunks = chunks
        activeChunkIndexInternal = 0
        loadChunk(0)
        publishSplitState()
        saveSplitState()
    }

    fun splitActiveChunk(count: Int) {
        if (internalSplitChunks == null) {
            split(count)
            return
        }
        stopRecitation()
        saveCurrentChunkState()
        val chunks = internalSplitChunks ?: return
        if (activeChunkIndexInternal !in chunks.indices) return
        val active = chunks[activeChunkIndexInternal]
        val subTexts = com.memorezar.app.core.chunking.TextChunker.split(active.chunkText, count)
        val newChunks = subTexts.map { buildChunkState(it, active.revealPercentage) }
        chunks.removeAt(activeChunkIndexInternal)
        chunks.addAll(activeChunkIndexInternal, newChunks)
        loadChunk(activeChunkIndexInternal)
        publishSplitState()
        saveSplitState()
    }

    fun unsplit() {
        stopRecitation()
        internalSplitChunks = null
        activeChunkIndexInternal = 0
        val q = quote ?: return
        val current = quoteStore.getQuote(q.id)
        if (current != null) {
            current.chunks = null
            current.activeChunkIndex = null
            current.chunkAccuracies = null
            current.chunkRevealPercentages = null
            quoteStore.updateQuote(current)
            quote = current
        }
        // Rebuild full-quote state via setQuote (restoreSavedSplit will be a no-op now).
        setQuote(quote ?: return)
    }

    fun switchToChunk(index: Int) {
        val chunks = internalSplitChunks ?: return
        if (index !in chunks.indices || index == activeChunkIndexInternal) return
        stopRecitation()
        saveCurrentChunkState()
        activeChunkIndexInternal = index
        loadChunk(index)
        publishSplitState()
        _uiState.update { it.copy(isComplete = false) }
    }

    private fun saveCurrentChunkState() {
        val chunks = internalSplitChunks ?: return
        if (activeChunkIndexInternal !in chunks.indices) return
        val state = _uiState.value
        chunks[activeChunkIndexInternal] = chunks[activeChunkIndexInternal].copy(
            words = state.words,
            currentPosition = state.currentPosition,
            mistakes = mistakes.toList(),
            hintCount = state.hintCount,
            previousWordWasMistake = previousWordWasMistake,
            revealPercentage = state.revealPercentage
        )
    }

    private fun loadChunk(index: Int) {
        val chunks = internalSplitChunks ?: return
        if (index !in chunks.indices) return
        val chunk = chunks[index]
        val q = quote ?: return
        comparator.setTargetText(chunk.chunkText, activeLanguage ?: q.primaryLanguage)
        comparator.reset()

        mistakes.clear()
        mistakes.addAll(chunk.mistakes)
        previousWordWasMistake = chunk.previousWordWasMistake
        sessionStartTime = null
        pendingMismatch = null
        pendingMismatchJob?.cancel()
        consecutiveMismatchesAtPosition = 0
        lastMismatchPosition = -1

        _uiState.update { state ->
            state.copy(
                words = chunk.words,
                currentPosition = chunk.currentPosition,
                isComplete = false,
                accuracy = 0.0,
                mistakeCount = chunk.mistakes.size,
                correctCount = chunk.words.count { it.state == WordState.CORRECT },
                hintCount = chunk.hintCount,
                totalWords = chunk.words.size,
                testedWordCount = 0,
                revealPercentage = chunk.revealPercentage,
                tappedMistakeIndex = null,
                tappedMistakeSpoken = null,
                flashingWordIndex = null,
                typingInput = "",
                mcChoices = emptyList(),
                mcCorrectIndex = -1,
                mcWrongIndex = null
            )
        }
        applyRevealPercentage()
        if (_uiState.value.currentMode == MemorizationMode.MULTIPLE_CHOICE) generateChoices()
    }

    private fun saveSplitState() {
        val q = quote ?: return
        val current = quoteStore.getQuote(q.id) ?: return
        val chunks = internalSplitChunks
        if (chunks != null) {
            saveCurrentChunkState()
            current.chunks = chunks.map { it.chunkText }
            current.activeChunkIndex = activeChunkIndexInternal
        } else {
            current.chunks = null
            current.activeChunkIndex = null
            current.chunkAccuracies = null
            current.chunkRevealPercentages = null
        }
        quoteStore.updateQuote(current)
        quote = current
    }

    private fun restoreSavedSplit() {
        val q = quote ?: return
        val savedChunks = q.chunks ?: return
        if (savedChunks.size <= 1) return
        val savedIndex = (q.activeChunkIndex ?: 0).coerceIn(0, savedChunks.size - 1)
        val chunks = savedChunks.map { buildChunkState(it, q.revealPercentageForLevel) }.toMutableList()
        internalSplitChunks = chunks
        activeChunkIndexInternal = savedIndex
        loadChunk(savedIndex)
        publishSplitState()
    }

    /** Look for the next non-completed chunk after the active one (wraps around). */
    private fun advanceToNextChunk(): Boolean {
        val chunks = internalSplitChunks ?: return false
        saveCurrentChunkState()
        fun isIncomplete(c: ChunkState): Boolean {
            val completed = c.words.count { it.state == WordState.CORRECT || it.state == WordState.INCORRECT }
            return completed < c.words.size
        }
        for (i in (activeChunkIndexInternal + 1) until chunks.size) {
            if (isIncomplete(chunks[i])) {
                activeChunkIndexInternal = i
                loadChunk(i)
                publishSplitState()
                _uiState.update { it.copy(isComplete = false) }
                return true
            }
        }
        for (i in 0 until activeChunkIndexInternal) {
            if (isIncomplete(chunks[i])) {
                activeChunkIndexInternal = i
                loadChunk(i)
                publishSplitState()
                _uiState.update { it.copy(isComplete = false) }
                return true
            }
        }
        return false
    }

    override fun onCleared() {
        super.onCleared()
        pendingMismatchJob?.cancel()
        silenceJob?.cancel()
        flashJob?.cancel()
        mcWrongJob?.cancel()
        speechService.stopListening()
        stopAudioPlayback()
        ttsService.stop()
        recorderService.cleanup()
    }
}
