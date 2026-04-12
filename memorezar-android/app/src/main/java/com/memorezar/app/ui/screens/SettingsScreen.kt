package com.memorezar.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.runtime.rememberCoroutineScope
import com.memorezar.app.core.alert.AlertManager
import com.memorezar.app.core.alert.SoundTheme
import com.memorezar.app.data.models.AppTheme
import com.memorezar.app.data.models.FontSize
import com.memorezar.app.data.models.MemorizationMode
import com.memorezar.app.data.services.AuthService
import com.memorezar.app.data.services.CloudBackupService
import com.memorezar.app.data.storage.QuoteStore
import com.memorezar.app.data.storage.SettingsStore
import com.memorezar.app.data.storage.TutorialStore

@Composable
fun SettingsScreen(
    settingsStore: SettingsStore,
    quoteStore: QuoteStore,
    tutorialStore: TutorialStore,
    authService: AuthService,
    alertManager: AlertManager,
    cloudBackupService: CloudBackupService,
    onShowAuthSheet: () -> Unit,
    onShowContactSupport: () -> Unit,
    modifier: Modifier = Modifier
) {
    val settings by settingsStore.settings.collectAsState()
    val currentUser by authService.currentUser.collectAsState()
    var showResetAlert by remember { mutableStateOf(false) }
    var showDeleteDataAlert by remember { mutableStateOf(false) }
    var showTestFlash by remember { mutableStateOf(false) }

    // Auto-dismiss test flash
    LaunchedEffect(showTestFlash) {
        if (showTestFlash) {
            delay(150L)
            showTestFlash = false
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
    ) {
        Text(
            text = "Settings",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(vertical = 16.dp)
        )

        // Alerts
        SectionHeader("Alerts")
        ToggleRow("Sound Alerts", settings.audioAlertEnabled) {
            settingsStore.updateSettings(settings.copy(audioAlertEnabled = it))
        }
        if (settings.audioAlertEnabled) {
            PickerRow(
                label = "Sound Theme",
                value = settings.soundTheme.displayName,
                options = SoundTheme.entries.map { it.displayName },
                onSelect = { selected ->
                    val theme = SoundTheme.entries.first { it.displayName == selected }
                    settingsStore.updateSettings(settings.copy(soundTheme = theme))
                    alertManager.previewTheme(theme)
                }
            )
        }
        ToggleRow("Visual Flash", settings.visualAlertEnabled) {
            settingsStore.updateSettings(settings.copy(visualAlertEnabled = it))
        }
        ToggleRow("Haptic Feedback", settings.hapticAlertEnabled) {
            settingsStore.updateSettings(settings.copy(hapticAlertEnabled = it))
        }
        ClickRow("Test Mistake Alert") {
            alertManager.triggerMistakeAlert()
            if (settings.visualAlertEnabled) {
                showTestFlash = true
            }
        }
        SectionDivider()

        // Display
        SectionHeader("Display")
        PickerRow(
            label = "Default Mode",
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
            ToggleRow("First Letter Mode", settings.firstLetterModeEnabled) {
                settingsStore.updateSettings(settings.copy(firstLetterModeEnabled = it))
            }
        }
        PickerRow(
            label = "Font Size",
            value = settings.fontSize.displayName,
            options = FontSize.entries.map { it.displayName },
            onSelect = { selected ->
                val size = FontSize.entries.first { it.displayName == selected }
                settingsStore.updateSettings(settings.copy(fontSize = size))
            }
        )
        PickerRow(
            label = "Theme",
            value = settings.theme.displayName,
            options = AppTheme.entries.map { it.displayName },
            onSelect = { selected ->
                val theme = AppTheme.entries.first { it.displayName == selected }
                settingsStore.updateSettings(settings.copy(theme = theme))
            }
        )
        SectionDivider()

        // Statistics
        SectionHeader("Statistics")
        InfoRow("Total Sessions", "${quoteStore.totalPracticeSessions}", compact = true)
        InfoRow("Quotes Mastered", "${quoteStore.masteredQuotesCount}", compact = true)
        InfoRow("Average Accuracy", "${(quoteStore.averageAccuracy * 100).toInt()}%", compact = true)
        InfoRow("Total Practice Time", formatDuration(quoteStore.totalPracticeTime), compact = true)
        SectionDivider()

        // Account
        SectionHeader("Account")
        if (currentUser != null) {
            val displayEmail = currentUser?.email
            val isPrivateRelay = displayEmail?.contains("privaterelay.appleid.com") == true
            val accountLabel = if (!isPrivateRelay && !displayEmail.isNullOrEmpty()) {
                displayEmail
            } else {
                "Apple Account"
            }
            InfoRow(accountLabel, "")

            // Backup
            val backupState by cloudBackupService.backupState.collectAsState()
            val lastBackup by cloudBackupService.lastBackupDate.collectAsState()
            val backupExists by cloudBackupService.cloudBackupExists.collectAsState()
            var showRestoreConfirm by remember { mutableStateOf(false) }

            val backupSubtext = when {
                backupState == CloudBackupService.BackupState.BACKING_UP -> "Backing up..."
                lastBackup != null -> cloudBackupService.formatRelativeTime(lastBackup!!)
                else -> ""
            }
            val coroutineScope = rememberCoroutineScope()

            ClickRow(
                label = "Back Up Now",
                detail = backupSubtext,
                enabled = backupState != CloudBackupService.BackupState.BACKING_UP
            ) {
                coroutineScope.launch { cloudBackupService.performBackup() }
            }

            ClickRow(
                label = "Restore from Backup",
                enabled = backupExists && backupState != CloudBackupService.BackupState.RESTORING
            ) {
                showRestoreConfirm = true
            }

            if (showRestoreConfirm) {
                AlertDialog(
                    onDismissRequest = { showRestoreConfirm = false },
                    title = { Text("Restore from cloud backup?") },
                    text = { Text("This will replace all local data with your cloud backup.") },
                    confirmButton = {
                        TextButton(onClick = {
                            showRestoreConfirm = false
                            coroutineScope.launch { cloudBackupService.fetchAndRestore() }
                        }) { Text("Replace with Cloud Data", color = MaterialTheme.colorScheme.error) }
                    },
                    dismissButton = {
                        TextButton(onClick = { showRestoreConfirm = false }) { Text("Cancel") }
                    }
                )
            }

            if (lastBackup != null) {
                SectionFooter("Last backed up ${cloudBackupService.formatRelativeTime(lastBackup!!)}")
            }

            ClickRow("Sign Out", color = MaterialTheme.colorScheme.error) {
                authService.signOut()
            }
        } else {
            ClickRow("Sign In") { onShowAuthSheet() }
            SectionFooter("Sign in to back up your data and share recordings.")
        }
        SectionDivider()

        // Data
        SectionHeader("Data")
        ClickRow("Reset Settings") { showResetAlert = true }
        ClickRow("Delete All Data", color = MaterialTheme.colorScheme.error) {
            showDeleteDataAlert = true
        }
        SectionDivider()

        // About
        SectionHeader("About")
        InfoRow("Version", "v2.4.64")
        ClickRow("Contact Support") { onShowContactSupport() }

        Spacer(Modifier.height(80.dp))
    }

    if (showResetAlert) {
        AlertDialog(
            onDismissRequest = { showResetAlert = false },
            title = { Text("Reset Settings") },
            text = { Text("This will reset all settings to their default values.") },
            confirmButton = {
                TextButton(onClick = {
                    settingsStore.resetToDefaults()
                    showResetAlert = false
                }) { Text("Reset", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showResetAlert = false }) { Text("Cancel") }
            }
        )
    }

    if (showDeleteDataAlert) {
        AlertDialog(
            onDismissRequest = { showDeleteDataAlert = false },
            title = { Text("Delete All Data") },
            text = { Text("This will delete all your quotes, practice history, and statistics. This action cannot be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    quoteStore.clearAllData()
                    tutorialStore.resetAll()
                    showDeleteDataAlert = false
                }) { Text("Delete", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDataAlert = false }) { Text("Cancel") }
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
    } // Box
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(top = 12.dp, bottom = 4.dp)
    )
}

@Composable
private fun SectionFooter(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(top = 4.dp, bottom = 8.dp)
    )
}

@Composable
private fun SectionDivider() {
    HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun InfoRow(label: String, value: String, compact: Boolean = false) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (compact) Modifier.padding(vertical = 4.dp) else Modifier.height(48.dp)),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, modifier = Modifier.weight(1f))
        Text(text = value, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun ClickRow(
    label: String,
    color: Color = MaterialTheme.colorScheme.primary,
    detail: String = "",
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    val displayColor = if (enabled) color else color.copy(alpha = 0.4f)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .clickable(enabled = enabled, onClick = onClick),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, color = displayColor, modifier = Modifier.weight(1f))
        if (detail.isNotEmpty()) {
            Text(
                text = detail,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}

@Composable
private fun PickerRow(
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
            .clickable { expanded = !expanded },
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, modifier = Modifier.weight(1f))
        Text(text = value, color = MaterialTheme.colorScheme.primary)
    }
    if (expanded) {
        Column(modifier = Modifier.padding(start = 16.dp)) {
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
