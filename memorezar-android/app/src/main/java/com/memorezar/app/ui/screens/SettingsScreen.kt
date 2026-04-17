package com.memorezar.app.ui.screens

import android.widget.Toast
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.automirrored.outlined.ExitToApp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.vectorResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.runtime.rememberCoroutineScope
import com.memorezar.app.R
import com.memorezar.app.core.alert.AlertManager
import com.memorezar.app.core.alert.SoundTheme
import com.memorezar.app.data.models.AppTheme
import com.memorezar.app.data.models.FontSize
import com.memorezar.app.data.models.MemorizationMode
import com.memorezar.app.data.services.AuthService
import com.memorezar.app.data.services.CloudBackupService
import com.memorezar.app.data.services.RecordingService
import com.memorezar.app.data.services.SupportReason
import com.memorezar.app.data.services.SupportTicketService
import com.memorezar.app.data.storage.LocalRecordingStore
import com.memorezar.app.data.storage.QuoteStore
import com.memorezar.app.data.storage.SettingsStore
import com.memorezar.app.data.storage.TutorialStore

private val SettingsIconTint = Color(0xFF3478F6)

@Composable
fun SettingsScreen(
    settingsStore: SettingsStore,
    quoteStore: QuoteStore,
    tutorialStore: TutorialStore,
    authService: AuthService,
    alertManager: AlertManager,
    cloudBackupService: CloudBackupService,
    supportTicketService: SupportTicketService,
    localRecordingStore: LocalRecordingStore,
    recordingService: RecordingService,
    onShowAuthSheet: () -> Unit,
    onShowContactSupport: () -> Unit,
    modifier: Modifier = Modifier
) {
    val settings by settingsStore.settings.collectAsState()
    val currentUser by authService.currentUser.collectAsState()
    var showResetAlert by remember { mutableStateOf(false) }
    var showDeleteDataAlert by remember { mutableStateOf(false) }
    var showTestFlash by remember { mutableStateOf(false) }
    // Counter-keyed trigger so rapid spam always restarts the flash timer and
    // the last tap's coroutine is the one that turns the overlay off — avoids
    // the case where the timer finishes before a re-tap refreshes the boolean
    // and the overlay gets stuck on.
    var testFlashTick by remember { mutableIntStateOf(0) }
    // Non-saveable scroll state — tab switching disposes this composable so
    // coming back to Settings resets scroll to top (matches iOS).
    val scrollState = remember { ScrollState(0) }
    val context = LocalContext.current

    // Scrim alpha animates in once the user scrolls past the title — gives a
    // subtle backdrop behind the status-bar icons without covering real content.
    val showScrim by remember { derivedStateOf { scrollState.value > 80 } }
    val scrimAlpha by animateFloatAsState(
        targetValue = if (showScrim) 0.95f else 0f,
        animationSpec = tween(durationMillis = 250),
        label = "scrimAlpha"
    )
    val surfaceColor = MaterialTheme.colorScheme.surface
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val toolbarHeight = statusBarTop + 8.dp

    // Auto-dismiss test flash — keyed on the tick counter so each tap restarts
    // the timer. If cancelled (another tap came in), the still-running newer
    // coroutine owns the final turn-off.
    LaunchedEffect(testFlashTick) {
        if (testFlashTick > 0) {
            showTestFlash = true
            delay(150L)
            showTestFlash = false
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(horizontal = 16.dp)
                .padding(top = toolbarHeight)
        ) {
            // Title (scrolls away). top=8dp/bottom=2dp lines the baseline up
            // with the Library screen title at the same y-offset.
            Text(
                text = stringResource(R.string.settings),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 8.dp, bottom = 2.dp)
            )

            // ── Alerts ──
            SectionHeader(stringResource(R.string.alerts))
            SettingsCard {
                IconToggleRow(ImageVector.vectorResource(R.drawable.ic_speaker_wave), stringResource(R.string.sound_alerts), settings.audioAlertEnabled) {
                    settingsStore.updateSettings(settings.copy(audioAlertEnabled = it))
                }
                if (settings.audioAlertEnabled) {
                    CardDivider()
                    IconPickerRow(
                        icon = ImageVector.vectorResource(R.drawable.ic_music_note),
                        label = stringResource(R.string.sound_theme),
                        value = settings.soundTheme.displayName,
                        options = SoundTheme.entries.map { it.displayName },
                        onSelect = { selected ->
                            val theme = SoundTheme.entries.first { it.displayName == selected }
                            settingsStore.updateSettings(settings.copy(soundTheme = theme))
                            alertManager.previewTheme(theme)
                        }
                    )
                }
                CardDivider()
                IconToggleRow(ImageVector.vectorResource(R.drawable.ic_lightbulb), stringResource(R.string.visual_flash), settings.visualAlertEnabled) {
                    settingsStore.updateSettings(settings.copy(visualAlertEnabled = it))
                }
                CardDivider()
                IconToggleRow(ImageVector.vectorResource(R.drawable.ic_vibration), stringResource(R.string.haptic_feedback), settings.hapticAlertEnabled) {
                    settingsStore.updateSettings(settings.copy(hapticAlertEnabled = it))
                }
                CardDivider()
                IconClickRow(ImageVector.vectorResource(R.drawable.ic_bell), stringResource(R.string.test_mistake_alert)) {
                    alertManager.triggerMistakeAlert()
                    if (settings.visualAlertEnabled) {
                        testFlashTick++
                    }
                }
            }
            SectionFooter(stringResource(R.string.alert_footer))

            // ── Display ──
            SectionHeader(stringResource(R.string.display))
            SettingsCard {
                IconPickerRow(
                    icon = ImageVector.vectorResource(R.drawable.ic_view_module),
                    label = stringResource(R.string.default_mode),
                    value = settings.defaultMemorizationMode.displayName,
                    options = MemorizationMode.entries.filter { it != MemorizationMode.AUDIO }.map { it.displayName },
                    onSelect = { selected ->
                        val mode = MemorizationMode.entries.first { it.displayName == selected }
                        settingsStore.updateSettings(settings.copy(defaultMemorizationMode = mode))
                    }
                )
                if (settings.defaultMemorizationMode == MemorizationMode.VOICE ||
                    settings.defaultMemorizationMode == MemorizationMode.TYPING
                ) {
                    CardDivider()
                    IconToggleRow(ImageVector.vectorResource(R.drawable.ic_abc), stringResource(R.string.first_letter_mode), settings.firstLetterModeEnabled) {
                        settingsStore.updateSettings(settings.copy(firstLetterModeEnabled = it))
                    }
                }
                CardDivider()
                IconPickerRow(
                    icon = ImageVector.vectorResource(R.drawable.ic_font_download),
                    label = stringResource(R.string.font_size),
                    value = settings.fontSize.displayName,
                    options = FontSize.entries.map { it.displayName },
                    onSelect = { selected ->
                        val size = FontSize.entries.first { it.displayName == selected }
                        settingsStore.updateSettings(settings.copy(fontSize = size))
                    }
                )
                CardDivider()
                IconPickerRow(
                    icon = ImageVector.vectorResource(R.drawable.ic_palette),
                    label = stringResource(R.string.theme),
                    value = settings.theme.displayName,
                    options = AppTheme.entries.map { it.displayName },
                    onSelect = { selected ->
                        val theme = AppTheme.entries.first { it.displayName == selected }
                        settingsStore.updateSettings(settings.copy(theme = theme))
                    }
                )
            }

            // ── Statistics ──
            SectionHeader(stringResource(R.string.statistics))
            SettingsCard {
                IconInfoRow(ImageVector.vectorResource(R.drawable.ic_repeat), stringResource(R.string.total_sessions), "${quoteStore.totalPracticeSessions}")
                CardDivider()
                IconInfoRow(ImageVector.vectorResource(R.drawable.ic_crown), stringResource(R.string.quotes_mastered), "${quoteStore.masteredQuotesCount}")
                CardDivider()
                IconInfoRow(ImageVector.vectorResource(R.drawable.ic_target), stringResource(R.string.average_accuracy), "${(quoteStore.averageAccuracy * 100).toInt()}%")
                CardDivider()
                IconInfoRow(ImageVector.vectorResource(R.drawable.ic_clock), stringResource(R.string.total_practice_time), formatDuration(quoteStore.totalPracticeTime))
            }

            // ── Account ──
            SectionHeader(stringResource(R.string.account))
            SettingsCard {
                if (currentUser != null) {
                    val displayEmail = currentUser?.email
                    val isPrivateRelay = displayEmail?.contains("privaterelay.appleid.com") == true
                    // Match iOS: just show the email next to the person icon, no
                    // separate display name. Falls back to "Apple Account" for
                    // private-relay sign-ins where we don't have a real address.
                    val accountText = if (isPrivateRelay || displayEmail.isNullOrEmpty()) {
                        stringResource(R.string.apple_account)
                    } else {
                        displayEmail
                    }
                    IconInfoRow(Icons.Default.Person, accountText, "")
                    CardDivider()

                    // Backup
                    val backupState by cloudBackupService.backupState.collectAsState()
                    val lastBackup by cloudBackupService.lastBackupDate.collectAsState()
                    val backupExists by cloudBackupService.cloudBackupExists.collectAsState()
                    var showRestoreConfirm by remember { mutableStateOf(false) }
                    val backupSubtext = when {
                        backupState == CloudBackupService.BackupState.BACKING_UP -> stringResource(R.string.backing_up)
                        lastBackup != null -> cloudBackupService.formatRelativeTime(lastBackup!!)
                        else -> ""
                    }
                    val coroutineScope = rememberCoroutineScope()

                    IconClickRow(Icons.Default.ArrowUpward, stringResource(R.string.back_up_now)) {
                        coroutineScope.launch { cloudBackupService.performBackup() }
                    }

                    // Restore row only shows when a backup actually exists on
                    // the server — mirrors iOS behavior. Hiding (vs disabling)
                    // avoids the confusing case where the row is visible but
                    // tapping it fails because there's nothing to restore.
                    if (backupExists) {
                        CardDivider()
                        IconClickRow(Icons.Default.ArrowDownward, stringResource(R.string.restore_from_backup)) {
                            showRestoreConfirm = true
                        }

                        if (showRestoreConfirm) {
                            val bodyText = buildString {
                                append(stringResource(R.string.restore_from_cloud_message))
                                lastBackup?.let { millis ->
                                    append("\n\n")
                                    append(stringResource(R.string.last_backed_up, cloudBackupService.formatRelativeTime(millis)))
                                }
                            }
                            AlertDialog(
                                onDismissRequest = { showRestoreConfirm = false },
                                title = { Text(stringResource(R.string.restore_from_cloud_title)) },
                                text = { Text(bodyText) },
                                confirmButton = {
                                    TextButton(onClick = {
                                        showRestoreConfirm = false
                                        coroutineScope.launch {
                                            cloudBackupService.fetchAndRestore()
                                            // Short confirmation — mirrors the
                                            // PDF-saved toast pattern used
                                            // elsewhere in the app and the
                                            // iOS "Welcome back" bottom toast.
                                            Toast.makeText(
                                                context,
                                                context.getString(R.string.restore_complete_toast),
                                                Toast.LENGTH_SHORT
                                            ).show()
                                        }
                                    }) { Text(stringResource(R.string.replace_with_cloud_data), color = MaterialTheme.colorScheme.error) }
                                },
                                dismissButton = {
                                    TextButton(onClick = { showRestoreConfirm = false }) { Text(stringResource(R.string.cancel)) }
                                }
                            )
                        }
                    }

                    CardDivider()
                    var showSignOutConfirm by remember { mutableStateOf(false) }
                    IconClickRow(Icons.AutoMirrored.Outlined.ExitToApp, stringResource(R.string.sign_out), color = MaterialTheme.colorScheme.error) {
                        showSignOutConfirm = true
                    }

                    if (showSignOutConfirm) {
                        AlertDialog(
                            onDismissRequest = { showSignOutConfirm = false },
                            title = { Text(stringResource(R.string.sign_out_title)) },
                            text = { Text(stringResource(R.string.sign_out_message)) },
                            confirmButton = {
                                TextButton(onClick = {
                                    showSignOutConfirm = false
                                    authService.signOut()
                                }) {
                                    Text(stringResource(R.string.sign_out), color = MaterialTheme.colorScheme.error)
                                }
                            },
                            dismissButton = {
                                TextButton(onClick = { showSignOutConfirm = false }) {
                                    Text(stringResource(R.string.cancel))
                                }
                            }
                        )
                    }

                    CardDivider()
                    var showDeleteAccountConfirm by remember { mutableStateOf(false) }
                    var showDeleteReceivedDialog by remember { mutableStateOf(false) }
                    var deleteAccountInFlight by remember { mutableStateOf(false) }
                    var deleteReceivedMessage by remember { mutableStateOf("") }
                    var deleteSucceeded by remember { mutableStateOf(false) }

                    IconClickRow(Icons.Default.Delete, stringResource(R.string.delete_my_account), color = MaterialTheme.colorScheme.error) {
                        if (!deleteAccountInFlight) showDeleteAccountConfirm = true
                    }

                    val successMsg = stringResource(R.string.delete_account_received_message)
                    val partialMsg = stringResource(R.string.delete_account_partial_message)

                    if (showDeleteAccountConfirm) {
                        AlertDialog(
                            onDismissRequest = { showDeleteAccountConfirm = false },
                            title = { Text(stringResource(R.string.delete_account_title)) },
                            text = { Text(stringResource(R.string.delete_account_message)) },
                            confirmButton = {
                                TextButton(onClick = {
                                    showDeleteAccountConfirm = false
                                    deleteAccountInFlight = true
                                    coroutineScope.launch {
                                        // Server-side cascade delete first so the JWT
                                        // is still valid when the Edge Function checks
                                        // it. If it fails, still wipe locally + sign
                                        // out so the user isn't stuck on a dead session.
                                        val serverError = authService.deleteAccountOnServer()

                                        // Show confirmation BEFORE wiping — because
                                        // tutorialStore.resetAll() flips hasCompletedOnboarding
                                        // which immediately navigates to OnboardingFlow,
                                        // disposing this SettingsScreen and swallowing any
                                        // dialog set after. The user dismisses the dialog,
                                        // THEN the wipe + sign-out fires.
                                        deleteSucceeded = serverError == null
                                        deleteReceivedMessage = if (serverError == null) successMsg else partialMsg
                                        deleteAccountInFlight = false
                                        showDeleteReceivedDialog = true
                                    }
                                }) {
                                    Text(stringResource(R.string.delete_account_confirm), color = MaterialTheme.colorScheme.error)
                                }
                            },
                            dismissButton = {
                                TextButton(onClick = { showDeleteAccountConfirm = false }) {
                                    Text(stringResource(R.string.cancel))
                                }
                            }
                        )
                    }

                    if (showDeleteReceivedDialog) {
                        // Wipe runs AFTER the user dismisses this dialog —
                        // tutorialStore.resetAll() navigates to OnboardingFlow
                        // which would dispose SettingsScreen (and this dialog)
                        // if we wiped before showing it.
                        val finishWipe = {
                            showDeleteReceivedDialog = false
                            quoteStore.clearAllData()
                            tutorialStore.resetAll()
                            settingsStore.resetToDefaults()
                            localRecordingStore.wipeAllAudioFiles()
                            localRecordingStore.replaceAll(emptyList())
                            authService.signOut()
                        }
                        AlertDialog(
                            onDismissRequest = finishWipe,
                            title = { Text(stringResource(if (deleteSucceeded) R.string.delete_account_success_title else R.string.delete_account_failed_title)) },
                            text = { Text(deleteReceivedMessage) },
                            confirmButton = {
                                TextButton(onClick = finishWipe) {
                                    Text(stringResource(R.string.ok))
                                }
                            }
                        )
                    }
                } else {
                    IconClickRow(Icons.Default.Person, stringResource(R.string.sign_in)) { onShowAuthSheet() }
                }
            }
            if (currentUser != null) {
                val lastBackup by cloudBackupService.lastBackupDate.collectAsState()
                if (lastBackup != null) {
                    SectionFooter(stringResource(R.string.last_backed_up, cloudBackupService.formatRelativeTime(lastBackup!!)))
                }
            }
            if (currentUser == null) {
                SectionFooter(stringResource(R.string.sign_in_footer))
            }

            // ── Data ──
            SectionHeader(stringResource(R.string.data))
            SettingsCard {
                IconClickRow(Icons.Default.Refresh, stringResource(R.string.reset_settings)) { showResetAlert = true }
                CardDivider()
                IconClickRow(Icons.Default.Delete, stringResource(R.string.delete_all_data), color = MaterialTheme.colorScheme.error) {
                    showDeleteDataAlert = true
                }
            }

            // ── About ──
            SectionHeader(stringResource(R.string.about))
            SettingsCard {
                IconInfoRow(Icons.Default.Info, stringResource(R.string.version), "v2.9.5")
                CardDivider()
                IconClickRow(Icons.Default.Email, stringResource(R.string.contact_support)) { onShowContactSupport() }
            }

            Spacer(Modifier.height(80.dp))
        }

        // ── Status-bar scrim ──
        // A thin gradient behind the status bar so notifications/time remain
        // legible when the user scrolls down — sits only over the status bar
        // area and fades out to transparent at its bottom edge.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(statusBarTop)
                .align(Alignment.TopStart)
                .background(
                    Brush.verticalGradient(
                        colorStops = arrayOf(
                            0.0f to surfaceColor.copy(alpha = scrimAlpha),
                            0.8f to surfaceColor.copy(alpha = scrimAlpha * 0.75f),
                            1.0f to Color.Transparent
                        )
                    )
                )
        )

        // Alerts
        if (showResetAlert) {
            AlertDialog(
                onDismissRequest = { showResetAlert = false },
                title = { Text(stringResource(R.string.reset_settings)) },
                text = { Text(stringResource(R.string.reset_settings_message)) },
                confirmButton = {
                    TextButton(onClick = {
                        settingsStore.resetToDefaults()
                        showResetAlert = false
                    }) { Text(stringResource(R.string.reset), color = MaterialTheme.colorScheme.error) }
                },
                dismissButton = {
                    TextButton(onClick = { showResetAlert = false }) { Text(stringResource(R.string.cancel)) }
                }
            )
        }

        if (showDeleteDataAlert) {
            val deleteScope = rememberCoroutineScope()
            AlertDialog(
                onDismissRequest = { showDeleteDataAlert = false },
                title = { Text(stringResource(R.string.delete_all_data)) },
                text = { Text(stringResource(R.string.delete_all_data_message)) },
                confirmButton = {
                    TextButton(onClick = {
                        // Fan out an unshare for every local that's linked to a
                        // community row. Runs in the background — we don't block
                        // the UI waiting for each request.
                        val toUnshare = localRecordingStore.recordings.value
                            .filter { !it.isFavorite && it.communityRecordingId != null }
                        deleteScope.launch(Dispatchers.IO) {
                            for (local in toUnshare) {
                                val cid = local.communityRecordingId ?: continue
                                // We don't have the Recording object handy for
                                // every one — construct a stub with just the id
                                // and file_path the server will look up from
                                // the row.
                                try {
                                    recordingService.deleteRecordingById(cid)
                                } catch (e: Exception) {
                                    android.util.Log.w("Settings", "Delete All Data unshare failed for $cid: ${e.message}")
                                }
                            }
                        }
                        quoteStore.clearAllData()
                        tutorialStore.resetAll()
                        localRecordingStore.wipeAllAudioFiles()
                        localRecordingStore.replaceAll(emptyList())
                        showDeleteDataAlert = false
                    }) { Text(stringResource(R.string.delete), color = MaterialTheme.colorScheme.error) }
                },
                dismissButton = {
                    TextButton(onClick = { showDeleteDataAlert = false }) { Text(stringResource(R.string.cancel)) }
                }
            )
        }

        // Red flash overlay for test mistake alert
        if (showTestFlash) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Red.copy(alpha = 0.3f))
            )
        }
    }
}

// ── Reusable components ──

@Composable
private fun SettingsCard(content: @Composable () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        // Horizontal padding is applied inside each row (after .clickable) so the
        // press ripple extends edge-to-edge across the card instead of stopping short.
        Column {
            content()
        }
    }
}

@Composable
private fun CardDivider() {
    HorizontalDivider(
        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
        thickness = 0.5.dp
    )
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(top = 20.dp, bottom = 6.dp, start = 4.dp)
    )
}

@Composable
private fun SectionFooter(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(top = 6.dp, bottom = 4.dp, start = 4.dp, end = 4.dp)
    )
}

@Composable
private fun IconToggleRow(icon: ImageVector, label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .clickable { onCheckedChange(!checked) }
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = SettingsIconTint,
            modifier = Modifier.size(22.dp)
        )
        Spacer(Modifier.width(12.dp))
        Text(label, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun IconInfoRow(icon: ImageVector, label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = SettingsIconTint,
            modifier = Modifier.size(22.dp)
        )
        Spacer(Modifier.width(12.dp))
        Text(label, modifier = Modifier.weight(1f))
        Text(text = value, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun IconClickRow(icon: ImageVector, label: String, color: Color = MaterialTheme.colorScheme.primary, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = if (color == MaterialTheme.colorScheme.error) color else SettingsIconTint,
            modifier = Modifier.size(22.dp)
        )
        Spacer(Modifier.width(12.dp))
        Text(text = label, color = color)
    }
}

@Composable
private fun IconPickerRow(
    icon: ImageVector,
    label: String,
    value: String,
    options: List<String>,
    onSelect: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .clickable { expanded = !expanded }
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = SettingsIconTint,
            modifier = Modifier.size(22.dp)
        )
        Spacer(Modifier.width(12.dp))
        Text(label, modifier = Modifier.weight(1f))
        Text(text = value, color = MaterialTheme.colorScheme.primary)
    }
    if (expanded) {
        // 50dp start = 16dp card padding + 22dp icon + 12dp spacer, keeps option text
        // aligned with the label text above.
        Column(modifier = Modifier.padding(start = 50.dp, end = 16.dp)) {
            options.forEach { option ->
                Text(
                    text = option,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            onSelect(option)
                            expanded = false
                        }
                        .padding(vertical = 8.dp),
                    color = if (option == value) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurface
                )
            }
        }
    }
}

private fun formatDuration(millis: Double): String {
    val totalSeconds = (millis / 1000).toInt()
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}
