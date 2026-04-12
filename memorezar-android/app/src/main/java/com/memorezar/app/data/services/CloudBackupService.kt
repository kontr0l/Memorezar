package com.memorezar.app.data.services

import android.content.Context
import android.util.Log
import com.memorezar.app.data.models.BackupPayload
import com.memorezar.app.data.storage.QuoteStore
import com.memorezar.app.data.storage.SettingsStore
import com.memorezar.app.data.storage.TutorialStore
import dagger.hilt.android.qualifiers.ApplicationContext
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "CloudBackup"
private const val BACKUPS_URL = "${SupabaseConfig.PROJECT_URL}/rest/v1/user_backups"
private const val LAST_BACKUP_KEY = "memorezar_last_backup_millis"

@Singleton
class CloudBackupService @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val httpClient: HttpClient,
    private val authService: AuthService,
    private val quoteStore: QuoteStore,
    private val settingsStore: SettingsStore,
    private val tutorialStore: TutorialStore
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    private val prefs by lazy {
        appContext.getSharedPreferences("memorezar_backup", Context.MODE_PRIVATE)
    }

    enum class BackupState { IDLE, BACKING_UP, RESTORING, ERROR }

    private val _backupState = MutableStateFlow(BackupState.IDLE)
    val backupState: StateFlow<BackupState> = _backupState.asStateFlow()

    private val _lastBackupDate = MutableStateFlow<Long?>(null)
    val lastBackupDate: StateFlow<Long?> = _lastBackupDate.asStateFlow()

    private val _cloudBackupExists = MutableStateFlow(false)
    val cloudBackupExists: StateFlow<Boolean> = _cloudBackupExists.asStateFlow()

    init {
        val stored = prefs.getLong(LAST_BACKUP_KEY, -1L)
        if (stored > 0) _lastBackupDate.value = stored

        // Check for cloud backup on sign-in
        scope.launch {
            authService.currentUser.collect { user ->
                if (user != null) {
                    checkForCloudBackup()
                }
            }
        }
    }

    // MARK: - Backup

    suspend fun performBackup() {
        if (!authService.isSignedIn) return
        _backupState.value = BackupState.BACKING_UP

        try {
            val payload = BackupPayload(
                backupVersion = BackupPayload.CURRENT_VERSION,
                createdAt = System.currentTimeMillis(),
                quotes = quoteStore.quotes.value,
                sessions = quoteStore.sessions.value,
                categories = quoteStore.categories.value,
                packVersions = quoteStore.installedPackVersions(),
                settings = settingsStore.settings.value,
                completedTips = tutorialStore.completedTips.value.toList(),
                hasCompletedOnboarding = tutorialStore.hasCompletedOnboarding.value
            )

            val payloadJson = json.encodeToString(payload)
            upsertBackup(payloadJson)

            val now = System.currentTimeMillis()
            _lastBackupDate.value = now
            _cloudBackupExists.value = true
            prefs.edit().putLong(LAST_BACKUP_KEY, now).apply()
            _backupState.value = BackupState.IDLE
            Log.i(TAG, "Backup complete")
        } catch (e: Exception) {
            Log.e(TAG, "Backup failed: ${e.message}", e)
            _backupState.value = BackupState.ERROR
        }
    }

    // MARK: - Restore

    suspend fun checkForCloudBackup(): Boolean {
        val token = authService.accessToken ?: return false
        val userId = authService.currentUser.value?.id ?: return false

        return try {
            val response = httpClient.get("$BACKUPS_URL?select=updated_at&user_id=eq.$userId") {
                header("apikey", SupabaseConfig.ANON_KEY)
                header("Authorization", "Bearer $token")
                contentType(ContentType.Application.Json)
            }
            if (response.status.isSuccess()) {
                val body: String = response.body()
                val rows = json.parseToJsonElement(body).jsonArray
                val exists = rows.isNotEmpty()
                _cloudBackupExists.value = exists
                exists
            } else {
                false
            }
        } catch (e: Exception) {
            Log.w(TAG, "Check failed: ${e.message}")
            false
        }
    }

    suspend fun fetchAndRestore() {
        val token = authService.accessToken ?: return
        val userId = authService.currentUser.value?.id ?: return

        _backupState.value = BackupState.RESTORING

        try {
            val response = httpClient.get("$BACKUPS_URL?select=data&user_id=eq.$userId") {
                header("apikey", SupabaseConfig.ANON_KEY)
                header("Authorization", "Bearer $token")
                contentType(ContentType.Application.Json)
            }
            if (!response.status.isSuccess()) {
                throw Exception("Fetch failed: ${response.status}")
            }

            val body: String = response.body()
            val rows = json.parseToJsonElement(body).jsonArray
            if (rows.isEmpty()) {
                throw Exception("No backup found")
            }

            val dataJson = rows[0].jsonObject["data"]?.toString()
                ?: throw Exception("Missing data field")
            val payload = json.decodeFromString<BackupPayload>(dataJson)

            // Apply to stores
            quoteStore.restoreFromBackup(
                quotes = payload.quotes,
                sessions = payload.sessions,
                categories = payload.categories,
                packVersions = payload.packVersions
            )

            settingsStore.updateSettings(payload.settings)

            tutorialStore.restoreFromBackup(
                completedTips = payload.completedTips.toSet(),
                hasCompletedOnboarding = payload.hasCompletedOnboarding
            )

            _backupState.value = BackupState.IDLE
            Log.i(TAG, "Restore complete")
        } catch (e: Exception) {
            Log.e(TAG, "Restore failed: ${e.message}", e)
            _backupState.value = BackupState.ERROR
        }
    }

    // MARK: - Supabase REST

    private suspend fun upsertBackup(payloadJson: String) {
        val token = authService.accessToken ?: throw Exception("Not signed in")
        val userId = authService.currentUser.value?.id ?: throw Exception("No user ID")

        val isoDate = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date())

        // Build the row wrapping the payload
        val row = """
            {
                "user_id": "$userId",
                "data": $payloadJson,
                "backup_version": ${BackupPayload.CURRENT_VERSION},
                "updated_at": "$isoDate"
            }
        """.trimIndent()

        val response = httpClient.post("$BACKUPS_URL?on_conflict=user_id") {
            header("apikey", SupabaseConfig.ANON_KEY)
            header("Authorization", "Bearer $token")
            header("Prefer", "return=representation,resolution=merge-duplicates")
            contentType(ContentType.Application.Json)
            setBody(row)
        }

        if (!response.status.isSuccess()) {
            val errorBody = response.bodyAsText()
            Log.e(TAG, "UPSERT failed (${response.status}): $errorBody")
            throw Exception("UPSERT failed: ${response.status}")
        }
    }

    /** Format last backup time as a single rounded-up unit. */
    fun formatRelativeTime(millis: Long): String {
        val seconds = ((System.currentTimeMillis() - millis) / 1000).toInt()
        if (seconds < 60) return "1 min ago"
        val minutes = kotlin.math.ceil(seconds / 60.0).toInt()
        if (minutes < 60) return "$minutes min ago"
        val hours = kotlin.math.ceil(minutes / 60.0).toInt()
        if (hours < 24) return "$hours hr ago"
        val days = kotlin.math.ceil(hours / 24.0).toInt()
        return "$days days ago"
    }
}
