package com.memorezar.app.core.alert

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum class SoundTheme(val displayName: String) {
    DEFAULT("Default"),
    MEMES("Memes")
}

enum class SoundEvent(val defaultResField: String, val folderName: String) {
    ERROR("error", "sounds/error"),
    SUCCESS("success", "sounds/success"),
    RESULT_FAIL("result_fail", "sounds/result_fail"),
    RESULT_WIN("result_win", "sounds/result_win");
}

// ---------------------------------------------------------------------------
// AlertManager
// ---------------------------------------------------------------------------

@Singleton
class AlertManager @Inject constructor(
    @ApplicationContext private val appContext: Context
) {

    companion object {
        private const val TAG = "AlertManager"
    }

    // ---- Alert configuration ------------------------------------------------

    var audioAlertEnabled: Boolean = true
    var visualAlertEnabled: Boolean = true
    var hapticAlertEnabled: Boolean = true

    var soundTheme: SoundTheme = SoundTheme.DEFAULT
        set(value) {
            if (field != value) {
                field = value
                // Meme sounds are loaded lazily; nothing extra needed for DEFAULT.
            }
        }

    /** UI layer sets this to receive visual-alert callbacks on the main thread. */
    var onVisualAlert: (() -> Unit)? = null

    // ---- SoundPool ----------------------------------------------------------

    private val audioAttrs: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_GAME)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private val soundPool: SoundPool = SoundPool.Builder()
        .setMaxStreams(4)
        .setAudioAttributes(audioAttrs)
        .build()

    /** Default-theme sound IDs keyed by SoundEvent. */
    private val defaultSoundIds = mutableMapOf<SoundEvent, Int>()

    /** Meme-theme sound IDs keyed by SoundEvent (multiple per event). */
    private val memeSoundIds = mutableMapOf<SoundEvent, MutableList<Int>>()

    /** Currently playing stream ID for result sounds so we can stop them. */
    private var resultStreamId: Int = 0

    // ---- Vibrator -----------------------------------------------------------

    private val vibrator: Vibrator? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val mgr = appContext.getSystemService(VibratorManager::class.java)
            mgr?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            appContext.getSystemService(Vibrator::class.java)
        }
    } catch (_: Exception) {
        null
    }

    // ---- Init ---------------------------------------------------------------

    init {
        loadDefaultSounds()
        loadMemeSounds()
    }

    // ---- Sound loading ------------------------------------------------------

    /**
     * Load default sounds from res/raw. Resource names must match
     * [SoundEvent.defaultResField] (e.g. R.raw.error, R.raw.success, ...).
     */
    private fun loadDefaultSounds() {
        for (event in SoundEvent.entries) {
            val resId = appContext.resources.getIdentifier(
                event.defaultResField, "raw", appContext.packageName
            )
            if (resId != 0) {
                defaultSoundIds[event] = soundPool.load(appContext, resId, 1)
            } else {
                Log.w(TAG, "Missing default sound resource: raw/${event.defaultResField}")
            }
        }
    }

    /**
     * Load meme sounds from the assets folder.
     * Expected layout: assets/sounds/<event>/ containing .mp3/.wav/.m4a/.aac files.
     */
    private fun loadMemeSounds() {
        val assets = appContext.assets
        for (event in SoundEvent.entries) {
            val folder = event.folderName
            try {
                val files = assets.list(folder) ?: continue
                val ids = mutableListOf<Int>()
                for (file in files) {
                    val ext = file.substringAfterLast('.', "").lowercase()
                    if (ext !in listOf("mp3", "wav", "m4a", "aac")) continue
                    val afd: AssetFileDescriptor = assets.openFd("$folder/$file")
                    val id = soundPool.load(afd, 1)
                    ids.add(id)
                    afd.close()
                }
                if (ids.isNotEmpty()) {
                    memeSoundIds[event] = ids
                }
            } catch (e: Exception) {
                Log.w(TAG, "No meme sounds for ${event.folderName}: ${e.message}")
            }
        }
    }

    // ---- Public API ---------------------------------------------------------

    /** Trigger all enabled alerts when the user speaks the wrong word. */
    fun triggerMistakeAlert() {
        if (hapticAlertEnabled) {
            fireHaptic()
        }
        if (audioAlertEnabled) {
            playSound(SoundEvent.ERROR, volume = 0.8f)
        }
        if (visualAlertEnabled) {
            onVisualAlert?.invoke()
        }
    }

    /** Play the "correct word" chime after recovering from a mistake. */
    fun triggerCorrectWordSound() {
        if (!audioAlertEnabled) return
        playSound(SoundEvent.SUCCESS, volume = 0.5f)
    }

    /** Play the win jingle (accuracy >= 70%). */
    fun triggerResultWinSound() {
        if (!audioAlertEnabled) return
        resultStreamId = playSound(SoundEvent.RESULT_WIN, volume = 0.9f)
    }

    /** Play the fail sound (accuracy < 70%). */
    fun triggerResultFailSound() {
        if (!audioAlertEnabled) return
        resultStreamId = playSound(SoundEvent.RESULT_FAIL, volume = 0.9f)
    }

    /** Convenience: choose win/fail based on accuracy threshold. */
    fun triggerResultSound(accuracy: Double) {
        if (accuracy >= 0.7) triggerResultWinSound() else triggerResultFailSound()
    }

    /** Stop any currently playing result sound. */
    fun stopResultSound() {
        if (resultStreamId != 0) {
            soundPool.stop(resultStreamId)
            resultStreamId = 0
        }
    }

    /** Preview a theme by playing its error sound. */
    fun previewTheme(theme: SoundTheme) {
        val id = when (theme) {
            SoundTheme.DEFAULT -> defaultSoundIds[SoundEvent.ERROR]
            SoundTheme.MEMES -> {
                val ids = memeSoundIds[SoundEvent.ERROR]
                if (!ids.isNullOrEmpty()) ids.random() else defaultSoundIds[SoundEvent.ERROR]
            }
        }
        if (id != null && id != 0) {
            soundPool.play(id, 0.8f, 0.8f, 1, 0, 1.0f)
        }
    }

    /** Fire the haptic pattern (for the settings test button). */
    fun testHaptic() {
        fireHaptic()
    }

    // ---- Internal helpers ---------------------------------------------------

    /**
     * Play a sound for the given event/theme and return the stream ID.
     */
    private fun playSound(event: SoundEvent, volume: Float): Int {
        val id = resolveSoundId(event)
        if (id == 0) return 0
        return soundPool.play(id, volume, volume, 1, 0, 1.0f)
    }

    private fun resolveSoundId(event: SoundEvent): Int {
        return when (soundTheme) {
            SoundTheme.DEFAULT -> defaultSoundIds[event] ?: 0
            SoundTheme.MEMES -> {
                val ids = memeSoundIds[event]
                if (!ids.isNullOrEmpty()) {
                    ids.random()
                } else {
                    // Fallback to default
                    defaultSoundIds[event] ?: 0
                }
            }
        }
    }

    /**
     * Double-pulse haptic: pulse, 100 ms gap, pulse.
     * Uses VibrationEffect.createWaveform on API 26+, deprecated vibrate() below that.
     */
    private fun fireHaptic() {
        val vib = vibrator ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // timings:  [wait, vibrate, wait, vibrate]
            // amplitudes: matching array
            val timings = longArrayOf(0, 40, 100, 40)
            val amplitudes = intArrayOf(0, 255, 0, 255)
            val effect = VibrationEffect.createWaveform(timings, amplitudes, -1)
            vib.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vib.vibrate(longArrayOf(0, 40, 100, 40), -1)
        }
    }
}
