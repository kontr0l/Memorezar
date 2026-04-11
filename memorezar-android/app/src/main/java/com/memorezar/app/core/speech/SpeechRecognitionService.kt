package com.memorezar.app.core.speech

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Delegate interface for receiving word-by-word speech recognition events.
 */
interface SpeechRecognitionDelegate {
    /** Called when a word is recognized and stable enough to emit. */
    fun onWord(word: String, confidence: Float)

    /** Called with normalized audio level (0.0-1.0) for waveform visualization. */
    fun onAudioLevel(level: Float)

    /** Called when an error occurs during recognition. */
    fun onError(error: String)

    /** Called when the recognition session is proactively restarted. */
    fun onSessionRestart()
}

/**
 * Streaming Speech Recognition Service using Android's SpeechRecognizer.
 *
 * Key features:
 * - Real-time partial results (words as they're spoken)
 * - Word-by-word emission via transcript diff tracking
 * - 200ms trailing-word debounce to handle STT revisions
 * - Proactive session restart at 55s to avoid degradation
 * - Locale support for non-English languages
 *
 * IMPORTANT: All SpeechRecognizer calls and all state mutations happen on
 * Dispatchers.Main to avoid threading races.
 */
@Singleton
class SpeechRecognitionService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    companion object {
        private const val TAG = "SpeechRecognition"
        private const val SESSION_TIMEOUT_MS = 55_000L
        private const val DEBOUNCE_MS = 200L
        private const val RESTART_DELAY_MS = 150L  // Must be long enough for service unbinding (~100-150ms)
        private const val MAX_CONSECUTIVE_REAL_ERRORS = 8  // Give up after real errors (not error 11)

        // Android RMS range is roughly -2 to 10
        private const val RMS_MIN = -2f
        private const val RMS_MAX = 10f
    }

    var delegate: SpeechRecognitionDelegate? = null

    @Volatile
    var isListening: Boolean = false
        private set

    private var speechRecognizer: SpeechRecognizer? = null
    private var previousTranscript: String = ""
    private var emittedWordCount: Int = 0
    private var debounceJob: Job? = null
    private var pendingWord: String? = null
    private var sessionStartTime: Long = 0
    private var sessionRestartJob: Job? = null
    private var autoRestartJob: Job? = null
    private var locale: Locale = Locale.getDefault()
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var isRestarting: Boolean = false
    private var highWaterMark: Int = 0
    private var consecutiveErrorCount: Int = 0
    private var hasLocaleFailedOver: Boolean = false
    private var originalLocale: Locale = Locale.getDefault()

    /**
     * Start listening for speech with the given locale.
     * Requires RECORD_AUDIO permission to be granted before calling.
     */
    fun startListening(locale: Locale = Locale.getDefault()) {
        this.locale = locale

        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            Log.e(TAG, "Speech recognition not available on this device")
            delegate?.onError("Speech recognition is not available on this device")
            return
        }

        // All state changes on main thread
        scope.launch {
            previousTranscript = ""
            emittedWordCount = 0
            highWaterMark = 0
            pendingWord = null
            debounceJob?.cancel()
            debounceJob = null
            isRestarting = false
            consecutiveErrorCount = 0
            hasLocaleFailedOver = false
            originalLocale = locale

            createAndStartRecognizer()
            isListening = true
            sessionStartTime = System.currentTimeMillis()
            scheduleSessionRestart()
            Log.i(TAG, "Started listening with locale: ${locale.toLanguageTag()}")
        }
    }

    /**
     * Stop listening and release the recognizer.
     */
    fun stopListening() {
        // All state changes on main thread
        scope.launch {
            debounceJob?.cancel()
            debounceJob = null

            // Flush pending word on main thread
            flushPendingWord()

            sessionRestartJob?.cancel()
            sessionRestartJob = null
            autoRestartJob?.cancel()
            autoRestartJob = null

            try {
                speechRecognizer?.stopListening()
                speechRecognizer?.destroy()
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping recognizer: ${e.message}")
            }
            speechRecognizer = null

            isListening = false
            previousTranscript = ""
            emittedWordCount = 0
            highWaterMark = 0
            pendingWord = null
            isRestarting = false

            Log.i(TAG, "Stopped listening")
        }
    }

    /**
     * Update the locale for future recognition sessions.
     */
    fun setLocale(locale: Locale) {
        this.locale = locale
        Log.i(TAG, "Locale set to: ${locale.toLanguageTag()}")
    }

    /**
     * Cancel scope on shutdown.
     */
    fun destroy() {
        scope.cancel()
    }

    // ── Private: Recognizer lifecycle ────────────────────────────────────────

    private fun createAndStartRecognizer() {
        // Destroy any existing recognizer
        try {
            speechRecognizer?.destroy()
        } catch (e: Exception) {
            Log.w(TAG, "Error destroying old recognizer: ${e.message}")
        }

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
            setRecognitionListener(recognitionListener)
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale.toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

        Log.d(TAG, "createAndStartRecognizer: locale=${locale.toLanguageTag()}")
        speechRecognizer?.startListening(intent)
    }

    private fun scheduleSessionRestart() {
        sessionRestartJob?.cancel()
        sessionRestartJob = scope.launch {
            delay(SESSION_TIMEOUT_MS)
            if (isListening && !isRestarting) {
                restartSession()
            }
        }
    }

    private fun restartSession() {
        if (!isListening || isRestarting) return

        Log.i(TAG, "Restarting recognition session (anti-degradation, ${SESSION_TIMEOUT_MS}ms)")

        isRestarting = true

        // Flush any pending word before restart
        flushPendingWord()

        // Save high water mark so we skip replayed words after restart
        highWaterMark = emittedWordCount

        scope.launch {
            try {
                speechRecognizer?.stopListening()
                speechRecognizer?.destroy()
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping recognizer during restart: ${e.message}")
            }
            speechRecognizer = null

            // Short delay before restarting
            delay(RESTART_DELAY_MS)

            if (isListening) {
                previousTranscript = ""
                // Do NOT reset emittedWordCount — highWaterMark guards against replays

                createAndStartRecognizer()
                sessionStartTime = System.currentTimeMillis()
                scheduleSessionRestart()

                isRestarting = false
                delegate?.onSessionRestart()
                Log.i(TAG, "Recognition session restarted (highWaterMark=$highWaterMark)")
            } else {
                isRestarting = false
            }
        }
    }

    // ── Private: Transcript diff processing ──────────────────────────────────

    /**
     * Process a partial or final transcript by diffing against the previous one
     * to find newly spoken words. Emits confirmed words immediately and debounces
     * the trailing word (which STT may still revise).
     */
    private fun processPartialResult(text: String) {
        val words = text.trim().split("\\s+".toRegex()).filter { it.isNotEmpty() }
        if (words.isEmpty()) return

        val previousWords = if (previousTranscript.isBlank()) {
            emptyList()
        } else {
            previousTranscript.trim().split("\\s+".toRegex()).filter { it.isNotEmpty() }
        }

        // Find new words: those beyond the previous transcript length
        val newStartIndex = previousWords.size
        if (words.size <= newStartIndex) {
            // Transcript shrank or stayed the same — possible revision of trailing word
            if (words.size == previousWords.size && words.isNotEmpty() && previousWords.isNotEmpty()) {
                val currentLast = words.last()
                val previousLast = previousWords.last()
                if (currentLast != previousLast) {
                    // Trailing word revised — update debounce
                    Log.d(TAG, "REVISION: \"$previousLast\" -> \"$currentLast\"")
                    scheduleDebouncedEmit(currentLast)
                }
            } else if (words.size < previousWords.size) {
                Log.d(TAG, "COUNT DROP: ${previousWords.size} -> ${words.size} (keeping high water mark)")
            }
            previousTranscript = text
            return
        }

        val newWords = words.subList(newStartIndex, words.size)

        // Post-restart replay guard: skip words until we exceed the high water mark
        if (highWaterMark > 0) {
            val pendingHasWord = pendingWord != null
            val effectiveEmitted = emittedWordCount + if (pendingHasWord) 1 else 0
            val wordsNeededToExceed = highWaterMark - effectiveEmitted

            if (wordsNeededToExceed > 0 && newWords.size <= wordsNeededToExceed) {
                // All "new" words are still replay — skip them, but advance emittedWordCount
                Log.d(TAG, "POST-RESTART: skipping ${newWords.size} replayed words (need $wordsNeededToExceed more to exceed highWaterMark=$highWaterMark)")
                emittedWordCount += newWords.size
                previousTranscript = text
                return
            }
        }

        // Flush any pending debounced word — it's confirmed by arrival of new words
        flushPendingWord()

        // Emit all confirmed words (all new words except the trailing one)
        for (i in 0 until newWords.size - 1) {
            val word = newWords[i]
            if (highWaterMark > 0 && emittedWordCount < highWaterMark) {
                // Still in replay zone — skip
                emittedWordCount++
                Log.d(TAG, "POST-RESTART: skipping replayed word \"$word\" (emitted=$emittedWordCount, hwm=$highWaterMark)")
                continue
            }
            Log.d(TAG, "SEND (confirmed): \"$word\"")
            emittedWordCount++
            delegate?.onWord(word, 0.0f) // Android partial results don't provide per-word confidence
        }

        // Debounce the trailing word — STT may still revise it
        val trailingWord = newWords.last()
        if (highWaterMark > 0 && emittedWordCount < highWaterMark) {
            // Trailing word is still in replay zone — skip debounce, just count it
            emittedWordCount++
            Log.d(TAG, "POST-RESTART: skipping replayed trailing word \"$trailingWord\"")
            if (emittedWordCount >= highWaterMark) {
                highWaterMark = 0
                Log.d(TAG, "POST-RESTART: caught up to highWaterMark, resuming normal processing")
            }
        } else {
            Log.d(TAG, "DEBOUNCE (trailing): \"$trailingWord\"")
            scheduleDebouncedEmit(trailingWord)
            if (highWaterMark > 0) {
                highWaterMark = 0
                Log.d(TAG, "POST-RESTART: past highWaterMark, resuming normal processing")
            }
        }

        previousTranscript = text
    }

    /**
     * Process a final result — emit all remaining words immediately.
     */
    private fun processFinalResult(text: String) {
        val words = text.trim().split("\\s+".toRegex()).filter { it.isNotEmpty() }
        if (words.isEmpty()) return

        // Flush any pending debounced word
        flushPendingWord()

        val previousWords = if (previousTranscript.isBlank()) {
            emptyList()
        } else {
            previousTranscript.trim().split("\\s+".toRegex()).filter { it.isNotEmpty() }
        }

        val newStartIndex = previousWords.size
        if (words.size > newStartIndex) {
            for (i in newStartIndex until words.size) {
                val word = words[i]
                if (highWaterMark > 0 && emittedWordCount < highWaterMark) {
                    emittedWordCount++
                    continue
                }
                Log.d(TAG, "SEND (final): \"$word\"")
                emittedWordCount++
                delegate?.onWord(word, 1.0f) // Final results have high confidence
            }
        }

        if (highWaterMark > 0) {
            highWaterMark = 0
        }

        // Final result means the session ended — prepare for auto-restart.
        // Set highWaterMark so any replayed words from the next session are skipped.
        previousTranscript = ""
    }

    // ── Private: Debounce ────────────────────────────────────────────────────

    private fun scheduleDebouncedEmit(word: String) {
        debounceJob?.cancel()
        pendingWord = word

        debounceJob = scope.launch {
            delay(DEBOUNCE_MS)
            if (pendingWord == word) {
                Log.d(TAG, "SEND (settled): \"$word\"")
                emittedWordCount++
                delegate?.onWord(word, 0.0f)
                pendingWord = null
            }
        }
    }

    /**
     * Flush the pending debounced word immediately (called on stop, restart, or
     * when new words confirm the pending word).
     */
    private fun flushPendingWord() {
        debounceJob?.cancel()
        debounceJob = null

        pendingWord?.let { word ->
            Log.d(TAG, "SEND (flushed): \"$word\"")
            emittedWordCount++
            delegate?.onWord(word, 0.0f)
        }
        pendingWord = null
    }

    // ── Private: RecognitionListener ─────────────────────────────────────────

    private val recognitionListener = object : RecognitionListener {

        override fun onPartialResults(partialResults: Bundle?) {
            val matches = partialResults
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            val text = matches?.firstOrNull()

            if (text == null) {
                Log.d(TAG, "PARTIAL: null (no recognition result in bundle)")
                return
            }

            if (text.isBlank()) {
                Log.d(TAG, "PARTIAL: \"\" (empty — recognizer hearing audio but no words yet)")
                return
            }

            Log.d(TAG, "PARTIAL: \"$text\" (emitted=$emittedWordCount hwm=$highWaterMark)")
            consecutiveErrorCount = 0  // Got real words — recognizer is healthy
            processPartialResult(text)
        }

        override fun onResults(results: Bundle?) {
            val matches = results
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            val text = matches?.firstOrNull() ?: return

            Log.d(TAG, "FINAL: \"$text\"")
            processFinalResult(text)

            // Android's SpeechRecognizer stops after a final result.
            // Auto-restart if we're still supposed to be listening.
            // Set highWaterMark to prevent duplicate emissions from replayed transcript.
            if (isListening && !isRestarting) {
                Log.i(TAG, "Auto-restarting after final result")
                consecutiveErrorCount = 0  // Successful session resets error count
                highWaterMark = emittedWordCount
                isRestarting = true  // Prevent overlapping restarts
                autoRestartJob?.cancel()
                autoRestartJob = scope.launch {
                    delay(RESTART_DELAY_MS)
                    if (isListening) {
                        previousTranscript = ""
                        createAndStartRecognizer()
                        scheduleSessionRestart()
                        isRestarting = false
                    }
                }
            }
        }

        override fun onRmsChanged(rmsdB: Float) {
            // Normalize Android's RMS range (-2 to 10) to 0.0-1.0
            val clamped = rmsdB.coerceIn(RMS_MIN, RMS_MAX)
            val normalized = (clamped - RMS_MIN) / (RMS_MAX - RMS_MIN)
            delegate?.onAudioLevel(normalized)
        }

        override fun onError(error: Int) {
            val errorMessage = mapErrorCode(error)
            Log.e(TAG, "Recognition error: $errorMessage (code=$error) [consecutiveErrors=$consecutiveErrorCount]")

            // Error 11 (language not supported) is a destroy/create race condition on OnePlus.
            // The system service hasn't finished unbinding when we create the new recognizer.
            // Strategy: DON'T count toward consecutive errors, just retry with a fixed short delay.
            val isServiceRace = error == 11

            if (!isServiceRace) {
                consecutiveErrorCount++
            }

            // Language not supported — fall back to device default ONCE
            if (error == 11 && isListening && !hasLocaleFailedOver) {
                val fallback = Locale.getDefault()
                if (locale != fallback) {
                    Log.w(TAG, "Language ${locale.toLanguageTag()} not supported, falling back to ${fallback.toLanguageTag()}")
                    locale = fallback
                    hasLocaleFailedOver = true
                } else {
                    Log.w(TAG, "Error 11 on device default ${locale.toLanguageTag()} — service unbind race, retrying")
                }
            }

            // Auto-restart on any error if we were listening.
            // Never show errors to the user — they are confusing and unhelpful.
            // The user can always tap the mic to restart manually if something truly breaks.
            if (isListening && !isRestarting) {
                if (consecutiveErrorCount > MAX_CONSECUTIVE_REAL_ERRORS) {
                    Log.e(TAG, "Too many consecutive real errors ($consecutiveErrorCount), giving up silently")
                    return
                }

                // Error 11: fixed short delay (it's a race condition, backoff makes it worse)
                // Other errors: small backoff to avoid tight loops
                val delayMs = if (isServiceRace) {
                    RESTART_DELAY_MS  // Fixed 150ms — just enough for service unbind
                } else {
                    // Mild backoff: 150, 300, 450, 600ms max
                    RESTART_DELAY_MS * consecutiveErrorCount.coerceAtMost(4)
                }
                Log.i(TAG, "Auto-restarting after error: $errorMessage (delay=${delayMs}ms)")

                highWaterMark = emittedWordCount
                isRestarting = true  // Prevent overlapping restarts
                autoRestartJob?.cancel()
                autoRestartJob = scope.launch {
                    delay(delayMs)
                    if (isListening) {
                        previousTranscript = ""
                        createAndStartRecognizer()
                        scheduleSessionRestart()
                        isRestarting = false
                    }
                }
                return
            }

            // Only reaches here if not listening — log but don't show to user
            Log.w(TAG, "Error while not listening: $errorMessage (code=$error)")
        }

        override fun onReadyForSpeech(params: Bundle?) {
            Log.d(TAG, "Ready for speech (emitted=$emittedWordCount hwm=$highWaterMark)")
        }

        override fun onBeginningOfSpeech() {
            Log.d(TAG, "Speech started (emitted=$emittedWordCount hwm=$highWaterMark)")
        }

        override fun onEndOfSpeech() {
            Log.d(TAG, "Speech ended (emitted=$emittedWordCount hwm=$highWaterMark pending=${pendingWord != null})")
        }

        override fun onBufferReceived(buffer: ByteArray?) {
            // Ignored — we don't process raw audio buffers
        }

        override fun onEvent(eventType: Int, params: Bundle?) {
            // Reserved for future use
        }
    }

    // ── Private: Error mapping ───────────────────────────────────────────────

    private fun mapErrorCode(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
        SpeechRecognizer.ERROR_CLIENT -> "Client side error"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
        SpeechRecognizer.ERROR_NETWORK -> "Network error"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
        SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
        SpeechRecognizer.ERROR_SERVER -> "Server error"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
        10 -> "Too many requests" // ERROR_TOO_MANY_REQUESTS (API 31)
        11 -> "Language not supported" // ERROR_LANGUAGE_NOT_SUPPORTED (API 31)
        12 -> "Language unavailable — try downloading it in device settings" // ERROR_LANGUAGE_UNAVAILABLE (API 31)
        13 -> "Cannot check for language support" // ERROR_CANNOT_CHECK_SUPPORT (API 33)
        14 -> "Cannot listen to language — download required" // ERROR_CANNOT_LISTEN_TO_DOWNLOAD_EVENTS (API 34)
        else -> "Unknown error (code=$error)"
    }
}
