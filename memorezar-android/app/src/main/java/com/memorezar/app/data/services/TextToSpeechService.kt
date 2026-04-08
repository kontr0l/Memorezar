package com.memorezar.app.data.services

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import java.io.File
import java.security.MessageDigest
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "TextToSpeechService"

@Singleton
class TextToSpeechService @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val httpClient: HttpClient
) {
    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private var mediaPlayer: MediaPlayer? = null

    /** True if a player exists (playing or paused). Used to distinguish resume vs fresh start. */
    fun hasActivePlayer(): Boolean = mediaPlayer != null

    var onFinish: (() -> Unit)? = null

    private val cacheDir: File by lazy {
        File(appContext.cacheDir, "tts_cache").also { it.mkdirs() }
    }

    /**
     * Speak text via Supabase Edge Function TTS. Caches audio files locally.
     */
    suspend fun speak(text: String, language: String = "en") {
        stop()
        _error.value = null

        try {
            val audioData = getCachedOrFetch(text, language)
            playAudio(audioData)
        } catch (e: Exception) {
            Log.e(TAG, "TTS error: ${e.message}")
            _error.value = e.message
        }
    }

    fun stop() {
        mediaPlayer?.let {
            if (it.isPlaying) it.stop()
            it.release()
        }
        mediaPlayer = null
        _isPlaying.value = false
    }

    fun togglePlayback() {
        val player = mediaPlayer ?: return
        if (player.isPlaying) {
            player.pause()
            _isPlaying.value = false
        } else {
            player.start()
            _isPlaying.value = true
        }
    }

    private suspend fun getCachedOrFetch(text: String, language: String): ByteArray {
        val cacheKey = sha256("$language:$text")
        val cacheFile = File(cacheDir, "$cacheKey.aac")

        if (cacheFile.exists()) {
            return withContext(Dispatchers.IO) { cacheFile.readBytes() }
        }

        // Fetch from Supabase Edge Function
        val response = httpClient.post(SupabaseConfig.TTS_URL) {
            header("apikey", SupabaseConfig.ANON_KEY)
            header("Authorization", "Bearer ${SupabaseConfig.ANON_KEY}")
            contentType(ContentType.Application.Json)
            setBody("""{"text":"${text.replace("\"", "\\\"")}","language":"$language"}""")
        }

        if (!response.status.isSuccess()) {
            throw Exception("TTS server error: ${response.status.value}")
        }

        val data: ByteArray = response.body()
        if (data.isEmpty()) throw Exception("Empty TTS response")

        // Cache to disk
        withContext(Dispatchers.IO) { cacheFile.writeBytes(data) }

        return data
    }

    private suspend fun playAudio(data: ByteArray) {
        withContext(Dispatchers.IO) {
            val tempFile = File.createTempFile("tts_play", ".aac", appContext.cacheDir)
            tempFile.writeBytes(data)

            withContext(Dispatchers.Main) {
                val player = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    setDataSource(tempFile.absolutePath)
                    prepare()
                    setOnCompletionListener {
                        _isPlaying.value = false
                        onFinish?.invoke()
                        tempFile.delete()
                    }
                    start()
                }
                mediaPlayer = player
                _isPlaying.value = true
            }
        }
    }

    private fun sha256(input: String): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest(input.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
