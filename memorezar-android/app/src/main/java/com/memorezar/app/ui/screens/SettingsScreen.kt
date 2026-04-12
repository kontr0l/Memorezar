package com.memorezar.app.ui.screens

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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.vectorResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
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
    onShowAuthSheet: () -> Unit,
    onShowContactSupport: () -> Unit,
    modifier: Modifier = Modifier
) {
    val settings by settingsStore.settings.collectAsState()
    val currentUser by authService.currentUser.collectAsState()
    var showResetAlert by remember { mutableStateOf(false) }
    var showDeleteDataAlert by remember { mutableStateOf(false) }
    var showTestFlash by remember { mutableStateOf(false) }
    val scrollState = rememberScrollState()

    val showNavTitle by remember {
        derivedStateOf { scrollState.value > 80 }
    }
    val toolbarAlpha by animateFloatAsState(
        targetValue = if (showNavTitle) 0.78f else 0f,
        animationSpec = tween(durationMillis = 250),
        label = "toolbarAlpha"
    )
    val surfaceColor = MaterialTheme.colorScheme.surface
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val toolbarHeight = statusBarTop + 8.dp

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
                .verticalScroll(scrollState)
                .padding(horizontal = 16.dp)
                .padding(top = toolbarHeight)
        ) {
            // Title (scrolls away)
            Text(
                text = "Settings",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 24.dp, bottom = 8.dp)
            )

            // ── Alerts ──
            SectionHeader("Alerts")
            SettingsCard {
                IconToggleRow(ImageVector.vectorResource(R.drawable.ic_speaker_wave), "Sound Alerts", settings.audioAlertEnabled) {
                    settingsStore.updateSettings(settings.copy(audioAlertEnabled = it))
                }
                if (settings.audioAlertEnabled) {
                    CardDivider()
                    IconPickerRow(
                        icon = ImageVector.vectorResource(R.drawable.ic_music_note),
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
                CardDivider()
                IconToggleRow(ImageVector.vectorResource(R.drawable.ic_lightbulb), "Visual Flash", settings.visualAlertEnabled) {
                    settingsStore.updateSettings(settings.copy(visualAlertEnabled = it))
                }
                CardDivider()
                IconToggleRow(ImageVector.vectorResource(R.drawable.ic_vibration), "Haptic Feedback", settings.hapticAlertEnabled) {
                    settingsStore.updateSettings(settings.copy(hapticAlertEnabled = it))
                }
                CardDivider()
                IconClickRow(ImageVector.vectorResource(R.drawable.ic_bell), "Test Mistake Alert") {
                    alertManager.triggerMistakeAlert()
                    if (settings.visualAlertEnabled) {
                        showTestFlash = true
                    }
                }
            }
            SectionFooter("Choose how you want to be notified during recitation. Default plays clean tones, Memes plays random funny sounds.")

            // ── Display ──
            SectionHeader("Display")
            SettingsCard {
                IconPickerRow(
                    icon = ImageVector.vectorResource(R.drawable.ic_view_module),
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
                    CardDivider()
                    IconToggleRow(ImageVector.vectorResource(R.drawable.ic_abc), "First Letter Mode", settings.firstLetterModeEnabled) {
                        settingsStore.updateSettings(settings.copy(firstLetterModeEnabled = it))
                    }
                }
                CardDivider()
                IconPickerRow(
                    icon = ImageVector.vectorResource(R.drawable.ic_font_download),
                    label = "Font Size",
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
                    label = "Theme",
                    value = settings.theme.displayName,
                    options = AppTheme.entries.map { it.displayName },
                    onSelect = { selected ->
                        val theme = AppTheme.entries.first { it.displayName == selected }
                        settingsStore.updateSettings(settings.copy(theme = theme))
                    }
                )
            }

            // ── Statistics ──
            SectionHeader("Statistics")
            SettingsCard {
                IconInfoRow(ImageVector.vectorResource(R.drawable.ic_repeat), "Total Sessions", "${quoteStore.totalPracticeSessions}")
                CardDivider()
                IconInfoRow(ImageVector.vectorResource(R.drawable.ic_crown), "Quotes Mastered", "${quoteStore.masteredQuotesCount}")
                CardDivider()
                IconInfoRow(ImageVector.vectorResource(R.drawable.ic_target), "Average Accuracy", "${(quoteStore.averageAccuracy * 100).toInt()}%")
                CardDivider()
                IconInfoRow(ImageVector.vectorResource(R.drawable.ic_clock), "Total Practice Time", formatDuration(quoteStore.totalPracticeTime))
            }

            // ── Account ──
            SectionHeader("Account")
            SettingsCard {
                if (currentUser != null) {
                    val displayEmail = currentUser?.email
                    val isPrivateRelay = displayEmail?.contains("privaterelay.appleid.com") == true
                    val displayName = if (!isPrivateRelay && !displayEmail.isNullOrEmpty()) {
                        currentUser?.displayName ?: displayEmail.substringBefore("@")
                    } else {
                        "Apple Account"
                    }
                    IconInfoRow(Icons.Default.Person, displayName, if (isPrivateRelay) "Signed in with Apple" else (displayEmail ?: ""))
                    CardDivider()

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

                    IconClickRow(Icons.Default.ArrowUpward, "Back Up Now") {
                        coroutineScope.launch { cloudBackupService.performBackup() }
                    }
                    CardDivider()
                    IconClickRow(Icons.Default.ArrowDownward, "Restore from Backup") {
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

                    CardDivider()
                    IconClickRow(Icons.AutoMirrored.Outlined.ExitToApp, "Sign Out", color = MaterialTheme.colorScheme.error) {
                        authService.signOut()
                    }
                } else {
                    IconClickRow(Icons.Default.Person, "Sign In") { onShowAuthSheet() }
                }
            }
            if (currentUser != null) {
                val lastBackup by cloudBackupService.lastBackupDate.collectAsState()
                if (lastBackup != null) {
                    SectionFooter("Last backed up ${cloudBackupService.formatRelativeTime(lastBackup!!)}")
                }
            }
            if (currentUser == null) {
                SectionFooter("Sign in to back up your data and share recordings.")
            }

            // ── Data ──
            SectionHeader("Data")
            SettingsCard {
                IconClickRow(Icons.Default.Refresh, "Reset Settings") { showResetAlert = true }
                CardDivider()
                IconClickRow(Icons.Default.Delete, "Delete All Data", color = MaterialTheme.colorScheme.error) {
                    showDeleteDataAlert = true
                }
            }

            // ── About ──
            SectionHeader("About")
            SettingsCard {
                IconInfoRow(Icons.Default.Info, "Version", "v2.5.0")
                CardDivider()
                IconClickRow(Icons.Default.Email, "Contact Support") { onShowContactSupport() }
            }

            Spacer(Modifier.height(80.dp))
        }

        // ── Floating toolbar with gradient fade ──
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopStart)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(toolbarHeight + 20.dp)
                    .background(
                        Brush.verticalGradient(
                            colorStops = arrayOf(
                                0.0f to surfaceColor.copy(alpha = toolbarAlpha.coerceAtLeast(0.01f)),
                                0.75f to surfaceColor.copy(alpha = toolbarAlpha.coerceAtLeast(0.01f) * 0.92f),
                                0.9f to surfaceColor.copy(alpha = toolbarAlpha * 0.4f),
                                1.0f to Color.Transparent
                            )
                        )
                    )
            )
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(toolbarHeight)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = {}
                    )
            ) {
                Spacer(Modifier.windowInsetsPadding(WindowInsets.statusBars))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    if (showNavTitle) {
                        Text(
                            text = "Settings",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }

        // Alerts
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
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
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
            .height(48.dp),
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
            .height(48.dp),
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
            .clickable(onClick = onClick),
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
            .clickable { expanded = !expanded },
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
        Column(modifier = Modifier.padding(start = 34.dp)) {
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
