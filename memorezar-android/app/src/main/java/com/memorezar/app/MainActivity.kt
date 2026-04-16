package com.memorezar.app

import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.memorezar.app.core.alert.AlertManager
import com.memorezar.app.data.models.AppTheme
import com.memorezar.app.data.services.AuthService
import com.memorezar.app.data.services.CloudBackupService
import com.memorezar.app.data.services.PurchaseService
import com.memorezar.app.data.services.SupportTicketService
import com.memorezar.app.data.storage.QuoteStore
import com.memorezar.app.data.storage.SettingsStore
import com.memorezar.app.data.storage.TutorialStore
import com.memorezar.app.ui.navigation.AppNavigation
import com.memorezar.app.ui.theme.MemorezerTheme
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var quoteStore: QuoteStore
    @Inject lateinit var settingsStore: SettingsStore
    @Inject lateinit var tutorialStore: TutorialStore
    @Inject lateinit var authService: AuthService
    @Inject lateinit var alertManager: AlertManager
    @Inject lateinit var purchaseService: PurchaseService
    @Inject lateinit var supportTicketService: SupportTicketService
    @Inject lateinit var cloudBackupService: CloudBackupService
    @Inject lateinit var localRecordingStore: com.memorezar.app.data.storage.LocalRecordingStore
    @Inject lateinit var recordingService: com.memorezar.app.data.services.RecordingService

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Route hardware volume keys to the media stream so TTS / recordings play
        // through the loudspeaker at media volume (instead of ringer / call volume).
        volumeControlStream = AudioManager.STREAM_MUSIC

        // Initialize services
        authService.restoreSession()
        purchaseService.configure()

        // Handle OAuth callback if launched via deep link
        handleOAuthIntent(intent)

        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(
                android.graphics.Color.TRANSPARENT,
                android.graphics.Color.TRANSPARENT
            ),
            navigationBarStyle = SystemBarStyle.light(
                android.graphics.Color.TRANSPARENT,
                android.graphics.Color.TRANSPARENT
            )
        )
        setContent {
            val settings by settingsStore.settings.collectAsState()
            val darkTheme = when (settings.theme) {
                AppTheme.LIGHT -> false
                AppTheme.DARK -> true
            }

            MemorezerTheme(darkTheme = darkTheme) {
                AppNavigation(
                    quoteStore = quoteStore,
                    settingsStore = settingsStore,
                    tutorialStore = tutorialStore,
                    authService = authService,
                    alertManager = alertManager,
                    purchaseService = purchaseService,
                    supportTicketService = supportTicketService,
                    cloudBackupService = cloudBackupService,
                    localRecordingStore = localRecordingStore,
                    recordingService = recordingService
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleOAuthIntent(intent)
    }

    private fun handleOAuthIntent(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme == "com.memorezar.app" && uri.host == "callback") {
            val fragment = uri.fragment ?: return
            Log.d("MainActivity", "OAuth callback received")
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    authService.handleOAuthCallback(fragment)
                } catch (e: Exception) {
                    Log.e("MainActivity", "OAuth callback failed: ${e.message}")
                }
            }
        }
    }
}
