package com.memorezar.app.data.services

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "AudioRecorderService"

@Singleton
class AudioRecorderService @Inject constructor(
    @ApplicationContext private val appContext: Context
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _isRecording = MutableStateFlow(false)
    val isRecording: StateFlow<Boolean> = _isRecording.asStateFlow()

    private val _recordingDuration = MutableStateFlow(0.0)
    val recordingDuration: StateFlow<Double> = _recordingDuration.asStateFlow()

    private val _hasRecording = MutableStateFlow(false)
    val hasRecording: StateFlow<Boolean> = _hasRecording.asStateFlow()

    private var recorder: MediaRecorder? = null
    private var recordingFile: File? = null
    private var durationJob: Job? = null

    /**
     * Start recording to a temp M4A file.
     * Format: MPEG4 AAC, 44100 Hz, mono.
     */
    fun startRecording() {
        // Clean up previous recording
        recordingFile?.let { if (it.exists()) it.delete() }

        val file = File(appContext.cacheDir, "community_recording.m4a")
        recordingFile = file

        try {
            val mr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(appContext)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            mr.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioChannels(1)
                setAudioEncodingBitRate(128000)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }

            recorder = mr
            _isRecording.value = true
            _recordingDuration.value = 0.0
            _hasRecording.value = false

            // Update duration every 100ms
            durationJob = scope.launch {
                while (isActive && _isRecording.value) {
                    delay(100)
                    _recordingDuration.value += 0.1
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording: ${e.message}")
            cleanup()
            throw e
        }
    }

    fun stopRecording() {
        durationJob?.cancel()
        try {
            recorder?.apply {
                stop()
                release()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping recorder: ${e.message}")
        }
        recorder = null
        _isRecording.value = false
        _hasRecording.value = recordingFile?.exists() == true
    }

    /** Get the file path for preview playback. */
    fun getRecordingFilePath(): String? = recordingFile?.absolutePath

    /** Read the recorded audio as bytes. */
    fun getRecordingData(): ByteArray? {
        return try {
            recordingFile?.readBytes()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read recording: ${e.message}")
            null
        }
    }

    fun discardRecording() {
        recordingFile?.let { if (it.exists()) it.delete() }
        recordingFile = null
        _hasRecording.value = false
        _recordingDuration.value = 0.0
    }

    fun cleanup() {
        if (_isRecording.value) {
            try {
                recorder?.apply { stop(); release() }
            } catch (_: Exception) { }
            recorder = null
            _isRecording.value = false
        }
        durationJob?.cancel()
        discardRecording()
    }
}
