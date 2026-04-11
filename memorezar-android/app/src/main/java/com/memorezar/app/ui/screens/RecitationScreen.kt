package com.memorezar.app.ui.screens

import android.Manifest
import kotlin.math.roundToInt
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.runtime.DisposableEffect
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.EaseInOut
import androidx.compose.animation.core.EaseOut
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.ui.res.painterResource
import com.memorezar.app.R
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FontDownload
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.CallMerge
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.FormatQuote
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material.icons.filled.Keyboard
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FastRewind
import androidx.compose.material.icons.filled.FastForward
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Switch
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.memorezar.app.data.models.LocalRecording
import com.memorezar.app.data.models.MemorizationMode
import com.memorezar.app.data.models.MasteryLevel
import com.memorezar.app.data.models.MistakeCertainty
import com.memorezar.app.data.models.PracticeSession
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.models.Recording
import com.memorezar.app.data.services.AuthService
import com.memorezar.app.data.storage.QuoteStore
import java.text.SimpleDateFormat
import java.util.Date
import java.util.concurrent.TimeUnit
import com.memorezar.app.ui.components.BrainCharacter
import com.memorezar.app.ui.components.BrainCharacterView
import com.memorezar.app.ui.theme.CorrectGreen
import com.memorezar.app.ui.theme.MismatchRed
import com.memorezar.app.ui.theme.MistakeFlash
import com.memorezar.app.ui.theme.PendingYellow
import com.memorezar.app.ui.viewmodels.AudioPlaybackState
import com.memorezar.app.ui.viewmodels.ChunkInfo
import com.memorezar.app.ui.viewmodels.MasterResult
import com.memorezar.app.ui.viewmodels.PlaybackSource
import com.memorezar.app.ui.viewmodels.RecitationUiState
import com.memorezar.app.ui.viewmodels.RecitationViewModel
import com.memorezar.app.ui.viewmodels.WordDisplayMode
import com.memorezar.app.ui.viewmodels.WordState
import java.util.Locale
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.layout.offset
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Path
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

// iOS system blue #007AFF
private val iOSBlue = Color(0xFF007AFF)

// ---------------------------------------------------------------------------
// RecitationScreen — Main entry
// ---------------------------------------------------------------------------

@Composable
fun RecitationScreen(
    quoteId: String,
    quoteStore: QuoteStore,
    authService: AuthService,
    onShowAuthSheet: () -> Unit,
    tutorialQuote: Quote? = null,
    tutorialMode: MemorizationMode? = null,
    tutorialFirstLetter: Boolean = false,
    onBack: () -> Unit,
    viewModel: RecitationViewModel = hiltViewModel()
) {
    val isTutorialMode = tutorialQuote != null
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val audioState by viewModel.audioState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val ttsPlaying by viewModel.ttsService.isPlaying.collectAsStateWithLifecycle()
    val isRecording by viewModel.recorderService.isRecording.collectAsStateWithLifecycle()

    LaunchedEffect(quoteId) {
        if (tutorialQuote != null) {
            viewModel.isTutorialMode = true
            // Set mode before setQuote so no side effects from switchMode
            if (tutorialMode != null) {
                viewModel.setInitialMode(tutorialMode, tutorialFirstLetter)
            }
            viewModel.setQuote(tutorialQuote)
            // Restore first letter since setQuote resets it
            if (tutorialFirstLetter) {
                viewModel.setInitialMode(tutorialMode ?: MemorizationMode.VOICE, true)
            }
            // Hide "Happy" (0) and "to" (2), reveal "birthday" (1) and "you" (3)
            val isVoiceFirstLetter = (tutorialMode == MemorizationMode.VOICE) && tutorialFirstLetter
            if (!isVoiceFirstLetter) {
                viewModel.applyTutorialReveal(setOf(1, 3))
            }
        } else {
            val quote = quoteStore.getQuote(quoteId)
            if (quote != null) viewModel.setQuote(quote)
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) viewModel.startRecitation()
    }

    // ---------- Liquid fill animation state ----------
    val liquidFillProgress = remember { Animatable(0f) }
    val micFillProgress = remember { Animatable(0f) }
    val liquidWavePhase = remember { Animatable(0f) }
    var liquidOpacity by remember { mutableFloatStateOf(1f) }
    var showLiquidFill by remember { mutableStateOf(false) }
    var wasMasterMode by remember { mutableStateOf(false) }
    val isDarkTheme = androidx.compose.foundation.isSystemInDarkTheme()

    val liquidOpacityAnimated by animateFloatAsState(
        targetValue = liquidOpacity,
        animationSpec = tween(500, easing = EaseOut),
        label = "liquidOpacity"
    )

    // Continuous wave phase animation — cycles 0→2π over 800ms
    LaunchedEffect(showLiquidFill) {
        if (showLiquidFill) {
            liquidWavePhase.snapTo(0f)
            liquidWavePhase.animateTo(
                targetValue = 100f, // large value, we modulo later
                animationSpec = infiniteRepeatable(
                    animation = tween(durationMillis = 80000, easing = LinearEasing),
                    repeatMode = RepeatMode.Restart
                )
            )
        }
    }

    // React to master mode entering/exiting
    LaunchedEffect(uiState.isMasterMode) {
        if (uiState.isMasterMode) {
            wasMasterMode = true
            // Fill animation
            showLiquidFill = true
            liquidOpacity = 1f
            liquidFillProgress.snapTo(0f)
            micFillProgress.snapTo(0f)
            // Fill mic first (faster, smaller)
            scope.launch {
                micFillProgress.animateTo(1.15f, tween(500, easing = EaseInOut))
            }
            // Fill background slightly after
            scope.launch {
                liquidFillProgress.animateTo(1.15f, tween(700, easing = EaseInOut))
            }
            // After fill, soften for comfortable reading
            scope.launch {
                delay(750)
                liquidOpacity = if (isDarkTheme) 0.85f else 0.6f
            }
        } else if (wasMasterMode) {
            // Drain animation
            scope.launch {
                liquidFillProgress.animateTo(0f, tween(600, easing = EaseInOut))
            }
            scope.launch {
                micFillProgress.animateTo(0f, tween(600, easing = EaseInOut))
            }
            liquidOpacity = 1f
            delay(650)
            showLiquidFill = false
            wasMasterMode = false
        }
    }

    // Outer box fills entire screen including behind system bars
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
    // Liquid fill overlay — full screen yellow wave when entering/exiting master mode
    if (showLiquidFill) {
        val phase = liquidWavePhase.value * (Math.PI.toFloat() * 2f) // each 1.0 = one full cycle
        LiquidWaveCanvas(
            progress = liquidFillProgress.value,
            phase = phase,
            waveHeight = 12f,
            brush = Brush.verticalGradient(
                colors = listOf(
                    MasterYellow.copy(alpha = 0.3f),
                    MasterYellow.copy(alpha = 0.5f),
                    MasterYellow.copy(alpha = 0.7f)
                )
            ),
            modifier = Modifier
                .fillMaxSize()
                .alpha(liquidOpacityAnimated)
        )
    }

    // Inner box with inset padding for actual content
    Box(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.statusBars)
            .windowInsetsPadding(WindowInsets.navigationBars)
    ) {
            Column(modifier = Modifier.fillMaxSize().imePadding()) {
                // Top bar — mode picker + exit (hidden in tutorial mode)
                if (!isTutorialMode) {
                    TopBarWithModePicker(
                        currentMode = uiState.currentMode,
                        progress = if (uiState.totalWords > 0) uiState.currentPosition.toFloat() / uiState.totalWords else -1f,
                        audioState = if (uiState.currentMode == MemorizationMode.AUDIO) audioState else null,
                        ttsPlaying = ttsPlaying,
                        isRecording = isRecording,
                        onModeChange = { viewModel.switchMode(it) },
                        onSeek = { viewModel.seekPlayback(it) },
                        onExit = {
                            viewModel.stopRecitation()
                            onBack()
                        }
                    )
                }

                // "Tutorial" title + progress bar in tutorial mode (no mode picker above it)
                if (isTutorialMode && uiState.totalWords > 0) {
                    ProgressBar(
                        progress = uiState.currentPosition.toFloat() / uiState.totalWords,
                        modifier = Modifier
                    )
                    Text(
                        text = "Tutorial",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp, bottom = 8.dp)
                    )
                }

                // Content area — scrollable quote with controls floating on top (matches iOS)
                Box(modifier = Modifier.weight(1f)) {
                    val contentScrollState = rememberScrollState()
                    val autoScrollScope = rememberCoroutineScope()
                    // Track Y positions of words relative to the scroll content
                    val wordYPositions = remember { mutableMapOf<Int, Float>() }

                    // Auto-scroll to keep current word visible
                    LaunchedEffect(uiState.currentPosition) {
                        val y = wordYPositions[uiState.currentPosition] ?: return@LaunchedEffect
                        val viewportHeight = contentScrollState.viewportSize
                        val scrollOffset = contentScrollState.value
                        // Scroll so current word is in the upper third of the viewport
                        val targetScroll = (y - viewportHeight / 3f).toInt().coerceAtLeast(0)
                        if (y < scrollOffset || y > scrollOffset + viewportHeight * 0.6f) {
                            contentScrollState.animateScrollTo(targetScroll)
                        }
                    }

                    // Scrollable content — fills entire area
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(contentScrollState),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        // Title row — scrolls with content (same as iOS)
                        if (!isTutorialMode) {
                            Spacer(Modifier.height(12.dp))
                            ScrollableTitleRow(
                                title = viewModel.getActiveTitle().ifEmpty { quoteStore.getQuote(quoteId)?.title ?: "Practice" },
                                currentMode = uiState.currentMode,
                                audioState = if (uiState.currentMode == MemorizationMode.AUDIO) audioState else null,
                                isRecording = isRecording,
                                audioSourceName = if (uiState.currentMode == MemorizationMode.AUDIO) audioState.currentSource?.displayName else null,
                                audioSourceLanguage = if (!viewModel.hasTranslations()) null
                                    else if (uiState.currentMode == MemorizationMode.AUDIO) viewModel.getAudioLanguage()
                                    else viewModel.getQuoteLanguage(),
                                availableLanguages = if (viewModel.hasTranslations()) viewModel.getAvailableLanguages() else emptyList(),
                                primaryLanguageCode = viewModel.getPrimaryLanguageCode(),
                                onLanguageSwitch = { viewModel.switchLanguage(it) }
                            )
                        }

                        // Chunk navigation header (only when split)
                        uiState.splitChunks?.let { chunks ->
                            if (chunks.size > 1) {
                                ChunkNavigationHeader(
                                    activeIndex = uiState.activeChunkIndex,
                                    total = chunks.size,
                                    onPrev = { viewModel.switchToChunk(uiState.activeChunkIndex - 1) },
                                    onNext = { viewModel.switchToChunk(uiState.activeChunkIndex + 1) }
                                )
                            }
                        }

                        // Reveal slider (always shown)
                        RevealSlider(
                            displayLevel = uiState.displayLevel,
                            isLetterMode = uiState.isFirstLetterToggle && uiState.currentMode == MemorizationMode.VOICE,
                            enabled = !uiState.isMasterMode,
                            onLevelChanged = { viewModel.setDisplayLevel(it) },
                            modifier = Modifier.padding(horizontal = 16.dp)
                        )

                        // Word grid
                        if (uiState.words.isEmpty()) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 80.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    "Tap a quote to start practicing",
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        } else {
                            val infos = uiState.splitChunkInfos
                            val active = uiState.activeChunkIndex
                            // Peeks above (up to 2)
                            if (infos.isNotEmpty()) {
                                val startAbove = (active - 2).coerceAtLeast(0)
                                for (i in startAbove until active) {
                                    ChunkPeekContainer(
                                        info = infos[i],
                                        isDirectlyAdjacent = (i == active - 1),
                                        isBefore = true,
                                        onTap = { viewModel.switchToChunk(i) }
                                    )
                                }
                            }
                            var wordGridOffsetY by remember { mutableFloatStateOf(0f) }
                            Box(
                                modifier = Modifier
                                    .padding(top = 4.dp)
                                    .padding(horizontal = 16.dp)
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f))
                                    .onGloballyPositioned { coords ->
                                        wordGridOffsetY = coords.positionInParent().y
                                    }
                            ) {
                                WordGrid(
                                    uiState = uiState,
                                    viewModel = viewModel,
                                    wordYPositions = wordYPositions,
                                    wordGridOffsetY = wordGridOffsetY,
                                    modifier = Modifier.padding(12.dp)
                                )
                            }
                            // Peeks below (up to 2)
                            if (infos.isNotEmpty()) {
                                val endBelow = (active + 2).coerceAtMost(infos.size - 1)
                                for (i in (active + 1)..endBelow) {
                                    ChunkPeekContainer(
                                        info = infos[i],
                                        isDirectlyAdjacent = (i == active + 1),
                                        isBefore = false,
                                        onTap = { viewModel.switchToChunk(i) }
                                    )
                                }
                            }
                        }

                        // Bottom spacer so content can scroll above the floating controls
                        Spacer(Modifier.height(160.dp))
                    }

                    // Floating controls — overlaid at bottom (matches iOS)
                    Column(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        // Speech error/status display
                        uiState.speechError?.let { error ->
                            Text(
                                text = error,
                                color = MismatchRed,
                                fontSize = 11.sp,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp),
                                textAlign = TextAlign.Center,
                                maxLines = 2
                            )
                            Spacer(Modifier.height(4.dp))
                        }

                        // Input area — varies by mode
                        when (uiState.currentMode) {
                            MemorizationMode.VOICE -> {
                                val wavePhase = liquidWavePhase.value * (Math.PI.toFloat() * 2f)
                                VoiceInputRow(
                                    uiState = uiState,
                                    onMicTap = {
                                        if (uiState.isListening) {
                                            viewModel.pauseRecitation()
                                        } else if (uiState.isPaused) {
                                            viewModel.resumeRecitation()
                                        } else {
                                            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                                        }
                                    },
                                    onFirstLetterToggle = { viewModel.toggleFirstLetterMode() },
                                    onCrownTap = {
                                        if (uiState.isMasterMode) {
                                            viewModel.exitMasterMode()
                                        } else {
                                            viewModel.showMasterInfo()
                                        }
                                    },
                                    micFillProgress = micFillProgress.value,
                                    liquidWavePhase = wavePhase,
                                    modifier = Modifier.padding(horizontal = 16.dp)
                                )
                            }
                            MemorizationMode.TYPING -> {
                                val wavePhaseTyping = liquidWavePhase.value * (Math.PI.toFloat() * 2f)
                                TypingInputRow(
                                    uiState = uiState,
                                    onInputChange = { viewModel.updateTypingInput(it) },
                                    onSubmit = { viewModel.submitTypingInput() },
                                    onSubmitDirect = { viewModel.submitTypingInput(it) },
                                    onFirstLetterToggle = { viewModel.toggleFirstLetterMode() },
                                    onCrownTap = {
                                        if (uiState.isMasterMode) {
                                            viewModel.exitMasterMode()
                                        } else {
                                            viewModel.showMasterInfo()
                                        }
                                    },
                                    liquidFillProgress = micFillProgress.value,
                                    liquidWavePhase = wavePhaseTyping,
                                    modifier = Modifier.padding(horizontal = 16.dp)
                                )
                            }
                            MemorizationMode.MULTIPLE_CHOICE -> {
                                if (uiState.mcChoices.isNotEmpty()) {
                                    MultipleChoiceGrid(
                                        choices = uiState.mcChoices,
                                        correctIndex = uiState.mcCorrectIndex,
                                        wrongIndex = uiState.mcWrongIndex,
                                        onSelect = { viewModel.selectChoice(it) },
                                        modifier = Modifier.padding(horizontal = 16.dp).padding(top = 16.dp)
                                    )
                                }
                            }
                            MemorizationMode.AUDIO -> {
                                AudioPlayButton(
                                    audioState = audioState,
                                    ttsPlaying = ttsPlaying,
                                    ttsHasPlayer = viewModel.ttsService.hasActivePlayer(),
                                    isRecording = isRecording,
                                    onTogglePlayback = { viewModel.togglePlayback() },
                                    onStartTTS = { viewModel.startTTS() },
                                    onStopTTS = { viewModel.stopTTS() },
                                    onToggleTTS = { viewModel.toggleTTS() },
                                    onStartRecording = { viewModel.startRecording() },
                                    onStopRecording = { viewModel.stopRecordingAudio() },
                                    onPrev = { viewModel.navigatePlayback(forward = false) },
                                    onNext = { viewModel.navigatePlayback(forward = true) }
                                )
                            }
                            else -> { Spacer(Modifier.height(8.dp)) }
                        }

                        // Dark control pill
                        if (uiState.currentMode == MemorizationMode.AUDIO) {
                            AudioControlPill(
                                audioState = audioState,
                                isRecording = isRecording,
                                onToggleRepeat = { viewModel.toggleRepeat() },
                                onBrowse = { viewModel.showRecordingPicker() },
                                onEdit = { viewModel.editCurrentRecording() },
                                onDelete = { viewModel.showDeleteConfirm() },
                                onEnterRecording = { viewModel.enterRecordingMode() },
                                onCancelRecording = { viewModel.discardRecording() },
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        } else {
                            ControlPill(
                                uiState = uiState,
                                onReset = { viewModel.resetSession() },
                                onInfo = { viewModel.showQuoteInfo() },
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }
                }
            }

        // Mistake flash overlay
        if (uiState.showMistakeFlash) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MistakeFlash)
            )
        }

        // Mistake dispute popup
        if (uiState.tappedMistakeIndex != null) {
            MistakeDisputePopup(
                wordIndex = uiState.tappedMistakeIndex!!,
                spokenWord = uiState.tappedMistakeSpoken ?: "",
                onDismiss = { viewModel.dismissMistakePopup() },
                onOverride = { viewModel.overrideMistake() }
            )
        }

        // Master info popup
        if (uiState.showMasterInfoPopup) {
            MasterInfoPopup(
                currentStreak = quoteStore.getQuote(quoteId)?.masteryStreak ?: 0,
                onDismiss = { viewModel.dismissMasterInfo() },
                onStart = { viewModel.enterMasterMode() }
            )
        }

        // Master mode hint block popup
        if (uiState.showMasterHintBlock) {
            MasterHintBlockPopup(onDismiss = { viewModel.dismissMasterHintBlock() })
        }

        // Split / merge overlay
        if (uiState.showSplitOverlay) {
            SplitMergeOverlay(
                isSplit = uiState.splitChunks != null,
                splitCount = uiState.splitCount,
                wordCount = (viewModel.getQuoteForInfo()?.wordCount ?: 0),
                activeChunkIndex = uiState.activeChunkIndex,
                onSetCount = { viewModel.setSplitCount(it) },
                onConfirmSplit = { viewModel.confirmSplit() },
                onUnsplit = { viewModel.unsplitAndDismissOverlay() },
                onMergePrevious = { viewModel.mergeWithPreviousAndDismissOverlay() },
                onDismiss = { viewModel.dismissSplitOverlay() }
            )
        }

        // Quote info sheet
        if (uiState.showQuoteInfo) {
            val infoQuote = viewModel.getQuoteForInfo()
            if (infoQuote != null) {
                QuoteInfoPopup(
                    quote = infoQuote,
                    quoteStore = quoteStore,
                    onDismiss = { viewModel.dismissQuoteInfo() },
                    onScissors = {
                        viewModel.dismissQuoteInfo()
                        viewModel.openSplitOverlay()
                    }
                )
            }
        }

        // Completion overlay — slides up from bottom, ~70% height so word grid stays visible
        if (uiState.isComplete) {
            // Clear TextField focus + dismiss the soft keyboard so the panel's Done button
            // isn't hidden underneath the IME.
            val focusManager = androidx.compose.ui.platform.LocalFocusManager.current
            val keyboardController = androidx.compose.ui.platform.LocalSoftwareKeyboardController.current
            LaunchedEffect(Unit) {
                focusManager.clearFocus(force = true)
                keyboardController?.hide()
            }
            // Record mastery result if in master mode and not yet recorded
            if (uiState.isMasterMode && uiState.masterResult == null) {
                LaunchedEffect(Unit) {
                    viewModel.recordMasteryResult(quoteStore)
                }
            }

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .imePadding()
                    .background(MaterialTheme.colorScheme.background.copy(alpha = 0.4f))
                    .clickable { viewModel.dismissCompletion() },
                contentAlignment = Alignment.BottomCenter
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .fillMaxHeight(0.70f)
                        .shadow(8.dp, RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp))
                        .clip(RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp))
                        .background(MaterialTheme.colorScheme.surface)
                        .clickable {} // consume clicks so they don't pass through to scrim
                ) {
                    if (uiState.isMasterMode && uiState.masterResult != null) {
                        MasterCompletionView(
                            uiState = uiState,
                            onDone = {
                                viewModel.exitMasterMode()
                                onBack()
                            },
                            onRetry = {
                                viewModel.enterMasterMode()
                            }
                        )
                    } else {
                        CompletionView(
                            uiState = uiState,
                            isTutorialMode = isTutorialMode,
                            onDone = onBack,
                            onRetry = {
                                val quote = quoteStore.getQuote(quoteId)
                                if (quote != null) viewModel.setQuote(quote)
                            }
                        )
                    }
                }
            }
        }
    } // inner Box (content with insets)
    } // outer Box (opaque background)

    // Recording picker bottom sheet
    if (audioState.showRecordingPicker) {
        RecordingPickerSheet(
            audioState = audioState,
            onDismiss = { viewModel.dismissRecordingPicker() },
            onPlayLocal = { viewModel.playLocalRecording(it) },
            onPlayCommunity = { viewModel.playCommunityRecording(it) },
            onSaveCommunity = { viewModel.saveCommunityRecording(it) },
            onDeleteLocal = { viewModel.deleteLocalRecording(it) },
            onReadAloud = { viewModel.startTTS() },
            onRecordYourOwn = { viewModel.enterRecordingMode() }
        )
    }

    // Save recording bottom sheet (shown after stopping recording OR when editing)
    if (audioState.showSaveSheet) {
        val isEditing = audioState.editingRecordingName != null
        val isSignedIn by authService.currentUser.collectAsStateWithLifecycle()
        SaveRecordingSheet(
            recordingDuration = audioState.recordingDuration,
            recordingFilePath = if (isEditing) null else viewModel.getRecordingFilePath(),
            initialName = audioState.editingRecordingName ?: "",
            isEditing = isEditing,
            isSignedIn = isSignedIn != null,
            onSignIn = onShowAuthSheet,
            onSave = { name, share ->
                if (isEditing) {
                    viewModel.updateRecording(name ?: "", share)
                } else {
                    viewModel.dismissSaveSheet()
                    viewModel.saveRecording(name, share)
                }
            },
            onDiscard = {
                viewModel.dismissSaveSheet()
                if (!isEditing) viewModel.discardRecording()
            }
        )
    }

    // Delete confirmation dialog
    if (audioState.showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { viewModel.dismissDeleteConfirm() },
            title = { Text("Delete Recording") },
            text = { Text("Are you sure you want to delete this recording? This cannot be undone.") },
            confirmButton = {
                TextButton(onClick = { viewModel.deleteCurrentRecording() }) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.dismissDeleteConfirm() }) { Text("Cancel") }
            }
        )
    }
}

// ---------------------------------------------------------------------------
// TopBar with Mode Picker
// ---------------------------------------------------------------------------

@Composable
private fun TopBarWithModePicker(
    currentMode: MemorizationMode,
    progress: Float,
    audioState: AudioPlaybackState? = null,
    ttsPlaying: Boolean = false,
    isRecording: Boolean = false,
    onModeChange: (MemorizationMode) -> Unit,
    onSeek: (Float) -> Unit = {},
    onExit: () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        // Mode picker row with exit button
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, end = 4.dp, top = 4.dp, bottom = 0.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            ModePicker(
                currentMode = currentMode,
                onModeChange = onModeChange,
                modifier = Modifier.weight(1f)
            )
            Spacer(Modifier.width(4.dp))
            IconButton(onClick = onExit) {
                Icon(
                    painter = painterResource(id = R.drawable.icon_exit),
                    contentDescription = "Exit",
                    tint = Color.Unspecified,
                    modifier = Modifier.size(32.dp)
                )
            }
        }

        // Progress bar — edge-to-edge, same in all modes
        if (currentMode == MemorizationMode.AUDIO && audioState != null) {
            val barColor = when {
                audioState.isRecordingMode -> AudioRed
                audioState.isTTSActive -> AudioOrange
                else -> AudioGreen
            }
            val fraction = when {
                audioState.isTTSActive -> if (ttsPlaying) 1f else 0f
                audioState.isRecordingMode && isRecording -> 1f
                audioState.duration > 0 -> (audioState.currentTime / audioState.duration).toFloat().coerceIn(0f, 1f)
                else -> 0f
            }
            // Edge-to-edge bar (same as ProgressBar)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .pointerInput(Unit) {
                        detectTapGestures { offset ->
                            onSeek((offset.x / size.width).coerceIn(0f, 1f))
                        }
                    }
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(fraction)
                        .height(4.dp)
                        .background(barColor)
                )
            }
        } else if (progress >= 0f) {
            ProgressBar(progress = progress, modifier = Modifier)
        }
    }
}

/** Title row — rendered inside the scrollable area so it scrolls with content */
@Composable
private fun ScrollableTitleRow(
    title: String,
    currentMode: MemorizationMode,
    audioState: AudioPlaybackState? = null,
    isRecording: Boolean = false,
    audioSourceName: String? = null,
    audioSourceLanguage: String? = null,
    availableLanguages: List<String> = emptyList(),
    primaryLanguageCode: String = "en",
    onLanguageSwitch: (String?) -> Unit = {}
) {
    val displayTitle = audioSourceName ?: title
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp)
    ) {
        // Time labels — positioned at top, overlaid
        val showTime = currentMode == MemorizationMode.AUDIO && audioState != null &&
            (audioState.currentSource != null || (audioState.isRecordingMode && isRecording))
        if (showTime && audioState != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                val elapsed = if (audioState.isRecordingMode) audioState.recordingDuration else audioState.currentTime
                val remaining = if (audioState.isRecordingMode) 0.0 else (audioState.duration - audioState.currentTime).coerceAtLeast(0.0)
                Text(formatTime(elapsed), style = TextStyle(fontSize = 13.sp, fontFamily = FontFamily.Monospace), color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("-${formatTime(remaining)}", style = TextStyle(fontSize = 13.sp, fontFamily = FontFamily.Monospace), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        // Title — always centered in this box
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = displayTitle,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f, fill = false)
            )
            if (audioSourceLanguage != null) {
                Spacer(Modifier.width(8.dp))
                val isAudioPlaybackOrRecording = currentMode == MemorizationMode.AUDIO &&
                    audioState != null &&
                    (audioState.currentSource != null || audioState.isRecordingMode)
                if (availableLanguages.isNotEmpty() && !isAudioPlaybackOrRecording) {
                    InteractiveLanguageBadge(
                        code = audioSourceLanguage,
                        primaryLanguageCode = primaryLanguageCode,
                        availableLanguages = availableLanguages,
                        activeLanguage = if (audioSourceLanguage != primaryLanguageCode) audioSourceLanguage else null,
                        onLanguageSwitch = onLanguageSwitch
                    )
                } else if (isAudioPlaybackOrRecording) {
                    GreyedLanguageBadge(code = audioSourceLanguage)
                } else {
                    LanguageBadge(code = audioSourceLanguage)
                }
            }
        }
    }
}

@Composable
private fun ModePicker(
    currentMode: MemorizationMode,
    onModeChange: (MemorizationMode) -> Unit,
    modifier: Modifier = Modifier
) {
    val modes = listOf(
        MemorizationMode.VOICE to Icons.Default.Mic,
        MemorizationMode.TYPING to Icons.Default.Keyboard,
        MemorizationMode.MULTIPLE_CHOICE to Icons.Default.GridView,
        MemorizationMode.AUDIO to Icons.Default.MusicNote
    )
    val selectedIndex = modes.indexOfFirst { it.first == currentMode }.coerceAtLeast(0)

    // Animated indicator position
    val indicatorFraction by animateFloatAsState(
        targetValue = selectedIndex.toFloat() / modes.size,
        animationSpec = tween(250, easing = EaseInOut),
        label = "indicator"
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(42.dp)
            .clip(RoundedCornerShape(9.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(3.dp)
    ) {
        // Sliding white indicator
        Box(
            modifier = Modifier
                .fillMaxWidth(1f / modes.size)
                .height(36.dp)
                .padding(start = with(LocalDensity.current) {
                    // Calculate offset based on animated fraction
                    val totalWidth = this@Box.let { 0.dp } // placeholder
                    0.dp
                })
        )

        // Use Canvas for the indicator to get exact positioning
        Canvas(modifier = Modifier.fillMaxSize()) {
            val segmentWidth = size.width / modes.size
            val indicatorX = indicatorFraction * size.width
            val cornerRadius = 7.dp.toPx()

            drawRoundRect(
                color = Color.White,
                topLeft = Offset(indicatorX, 0f),
                size = Size(segmentWidth, size.height),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(cornerRadius)
            )
        }

        // Mode buttons
        Row(modifier = Modifier.fillMaxSize()) {
            modes.forEach { (mode, icon) ->
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxSize()
                        .clickable { onModeChange(mode) },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = mode.displayName,
                        modifier = Modifier.size(20.dp),
                        tint = if (mode == currentMode)
                            MaterialTheme.colorScheme.primary
                        else
                            MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Progress Bar
// ---------------------------------------------------------------------------

@Composable
private fun ProgressBar(progress: Float, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(4.dp)
            .background(MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(progress.coerceIn(0f, 1f))
                .height(4.dp)
                .background(CorrectGreen)
        )
    }
}

// ---------------------------------------------------------------------------
// WordGrid — FlowRow with WordCells
// ---------------------------------------------------------------------------

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun WordGrid(
    uiState: RecitationUiState,
    viewModel: RecitationViewModel,
    wordYPositions: MutableMap<Int, Float> = mutableMapOf(),
    wordGridOffsetY: Float = 0f,
    modifier: Modifier = Modifier
) {
    var flowRowOffsetY by remember { mutableFloatStateOf(0f) }
    Box(modifier = modifier.onGloballyPositioned { coords ->
        flowRowOffsetY = coords.positionInParent().y
    }) {
        FlowRow(
            modifier = Modifier
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            uiState.words.forEachIndexed { index, word ->
                val displayMode = viewModel.wordDisplayMode(index)
                Box(
                    modifier = Modifier.onGloballyPositioned { coords ->
                        wordYPositions[index] = wordGridOffsetY + flowRowOffsetY + coords.positionInParent().y
                    }
                ) {
                    WordCell(
                        text = word.text,
                        wordState = word.state,
                        displayMode = displayMode,
                        isFlashing = uiState.flashingWordIndex == index,
                        onTap = { viewModel.tapWord(index) }
                    )
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// WordCell — Individual word display
// ---------------------------------------------------------------------------

@Composable
private fun WordCell(
    text: String,
    wordState: WordState,
    displayMode: WordDisplayMode,
    isFlashing: Boolean,
    onTap: () -> Unit
) {
    val textColor = when (wordState) {
        WordState.CORRECT -> CorrectGreen
        WordState.INCORRECT -> MismatchRed
        WordState.CURRENT -> iOSBlue
        WordState.PENDING -> PendingYellow
        WordState.UPCOMING -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
    }

    val bgColor by animateColorAsState(
        targetValue = when {
            isFlashing -> PendingYellow.copy(alpha = 0.2f)
            wordState == WordState.CORRECT -> CorrectGreen.copy(alpha = 0.15f)
            wordState == WordState.INCORRECT -> MismatchRed.copy(alpha = 0.15f)
            wordState == WordState.CURRENT -> iOSBlue.copy(alpha = 0.15f)
            else -> Color.Transparent
        },
        animationSpec = tween(400, easing = EaseInOut),
        label = "wordBg"
    )

    val borderColor by animateColorAsState(
        targetValue = when {
            isFlashing -> PendingYellow
            wordState == WordState.CURRENT -> iOSBlue
            else -> Color.Transparent
        },
        animationSpec = tween(400, easing = EaseInOut),
        label = "wordBorder"
    )

    val (letters, punctuation) = splitPunctuation(text)

    val displayText = when (displayMode) {
        WordDisplayMode.FULL -> text
        WordDisplayMode.HIDDEN -> null
        WordDisplayMode.FIRST_LETTER_1 -> buildFirstLetterText(letters, 1) + punctuation
        WordDisplayMode.FIRST_LETTER_2 -> buildFirstLetterText(letters, 2) + punctuation
        WordDisplayMode.FIRST_LETTER_3 -> buildFirstLetterText(letters, 3) + punctuation
    }

    val isHidden = displayText == null

    // Use a Box that always sizes to the full word text.
    // Render invisible full text for sizing, visible text on top.
    // Hidden current word gets blue highlight bg + border so user knows which to type
    val effectiveBg = when {
        isHidden && wordState == WordState.CURRENT -> iOSBlue.copy(alpha = 0.15f)
        isHidden -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)
        else -> bgColor
    }

    val effectiveBorder = when {
        isHidden && wordState == WordState.CURRENT -> iOSBlue
        isHidden -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)
        else -> borderColor
    }

    val wordStyle = TextStyle(fontSize = 18.sp)

    Box(
        modifier = Modifier
            .clickable { onTap() }
            .clip(RoundedCornerShape(8.dp))
            .background(effectiveBg)
            .then(
                if (effectiveBorder != Color.Transparent)
                    Modifier.border(
                        if (isHidden && wordState != WordState.CURRENT) 1.dp else 2.dp,
                        effectiveBorder,
                        RoundedCornerShape(8.dp)
                    )
                else Modifier
            )
            .padding(horizontal = 6.dp, vertical = 3.dp)
    ) {
        // Invisible full text reserves the exact width/height always
        Text(
            text = text,
            style = wordStyle,
            fontWeight = FontWeight.Bold,
            color = Color.Transparent
        )
        // Visible content — hidden words show nothing (just the gray box)
        if (!isHidden) {
            Text(
                text = displayText!!,
                style = wordStyle,
                fontWeight = if (wordState == WordState.CURRENT) FontWeight.Bold else FontWeight.Normal,
                color = textColor
            )
        }
    }
}

private fun splitPunctuation(word: String): Pair<String, String> {
    val idx = word.indexOfLast { it.isLetterOrDigit() }
    return if (idx < 0) Pair(word, "")
    else if (idx == word.length - 1) Pair(word, "")
    else Pair(word.substring(0, idx + 1), word.substring(idx + 1))
}

private fun buildFirstLetterText(letters: String, count: Int): String {
    if (letters.length <= count) return letters
    return letters.take(count) + "_".repeat(letters.length - count)
}

// ---------------------------------------------------------------------------
// Reveal Slider — 3-level discrete
// ---------------------------------------------------------------------------

@Composable
private fun RevealSlider(
    displayLevel: Int,
    isLetterMode: Boolean,
    enabled: Boolean = true,
    onLevelChanged: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val thumbSize = 26.dp
    var showNumber by remember { mutableStateOf(false) }
    var isDragging by remember { mutableStateOf(false) }
    val currentLevel by rememberUpdatedState(displayLevel)

    LaunchedEffect(isDragging) {
        if (!isDragging && showNumber) {
            delay(2000L)
            showNumber = false
        }
    }

    // Thumb always derives from level — matches iOS normalizedPosition
    val targetFraction = when (displayLevel) {
        3 -> 0f; 2 -> 0.5f; else -> 1f
    }
    val thumbFraction by animateFloatAsState(
        targetValue = targetFraction,
        animationSpec = tween(350, easing = EaseInOut),
        label = "thumbPos"
    )

    val thumbLabel = if (isLetterMode) {
        when (displayLevel) { 1 -> "3"; 2 -> "2"; else -> "1" }
    } else {
        when (displayLevel) { 1 -> "90"; 2 -> "50"; else -> "20" }
    }

    val density = LocalDensity.current
    val thumbSizePx = with(density) { thumbSize.toPx() }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .alpha(if (enabled) 1f else 0.35f),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Slider track
        Box(
            modifier = Modifier
                .weight(1f)
                .height(thumbSize)
                .then(
                    if (enabled) Modifier.pointerInput(Unit) {
                        awaitPointerEventScope {
                            while (true) {
                                val down = awaitFirstDown(requireUnconsumed = false)
                                isDragging = true
                                showNumber = true
                                val totalWidth = size.width - thumbSizePx
                                // Snap to nearest level based on finger position (matches iOS round() approach)
                                val raw = ((down.position.x - thumbSizePx / 2) / totalWidth).coerceIn(0f, 1f)
                                val snapped = 3 - (raw * 2f).roundToInt().coerceIn(0, 2)
                                if (snapped != currentLevel) onLevelChanged(snapped)
                                do {
                                    val event = awaitPointerEvent()
                                    val pos = event.changes.firstOrNull()?.position ?: break
                                    event.changes.forEach { it.consume() }
                                    val rawDrag = ((pos.x - thumbSizePx / 2) / totalWidth).coerceIn(0f, 1f)
                                    val newLevel = 3 - (rawDrag * 2f).roundToInt().coerceIn(0, 2)
                                    if (newLevel != currentLevel) onLevelChanged(newLevel)
                                } while (event.changes.any { it.pressed })
                                isDragging = false
                            }
                        }
                    } else Modifier
                )
        ) {
            // Track line
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = thumbSize / 2)
                    .height(3.dp)
                    .align(Alignment.Center)
                    .clip(RoundedCornerShape(1.5.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            )

            Canvas(modifier = Modifier.fillMaxSize()) {
                val trackStart = thumbSizePx / 2
                val trackEnd = size.width - thumbSizePx / 2
                val trackWidth = trackEnd - trackStart
                val thumbCenterX = trackStart + thumbFraction * trackWidth

                drawCircle(
                    color = iOSBlue,
                    radius = thumbSizePx / 2,
                    center = Offset(thumbCenterX, size.height / 2)
                )
            }

            Row(modifier = Modifier.fillMaxSize()) {
                if (thumbFraction > 0.01f) {
                    Spacer(Modifier.weight(thumbFraction.coerceAtLeast(0.001f)))
                }
                Box(
                    modifier = Modifier.size(thumbSize),
                    contentAlignment = Alignment.Center
                ) {
                    val iconAlpha by animateFloatAsState(
                        targetValue = if (showNumber) 0f else 1f,
                        animationSpec = tween(300, easing = EaseInOut), label = "ia"
                    )
                    val numberAlpha by animateFloatAsState(
                        targetValue = if (showNumber) 1f else 0f,
                        animationSpec = tween(300, easing = EaseInOut), label = "na"
                    )
                    Icon(Icons.Default.Visibility, contentDescription = null, tint = Color.White.copy(alpha = iconAlpha), modifier = Modifier.size(14.dp))
                    if (showNumber) {
                        Text(thumbLabel, fontSize = 9.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace,
                            color = Color.White.copy(alpha = numberAlpha), textAlign = TextAlign.Center)
                    }
                }
                if (thumbFraction < 0.99f) {
                    Spacer(Modifier.weight((1f - thumbFraction).coerceAtLeast(0.001f)))
                }
            }
        }

    }
}

// ---------------------------------------------------------------------------
// Voice Input Row — first-letter toggle, mic, crown
// ---------------------------------------------------------------------------

@Composable
private fun VoiceInputRow(
    uiState: RecitationUiState,
    onMicTap: () -> Unit,
    onFirstLetterToggle: () -> Unit,
    onCrownTap: () -> Unit,
    micFillProgress: Float = 0f,
    liquidWavePhase: Float = 0f,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(80.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (uiState.isMasterMode) {
            // Show streak counter instead of first-letter button in master mode
            MasterStreakCounter(
                streak = uiState.previousMasteryStreak,
                isActive = true
            )
        } else {
            FirstLetterButton(isToggled = uiState.isFirstLetterToggle, onClick = onFirstLetterToggle)
        }
        Spacer(Modifier.width(14.dp))
        MicButton(
            isListening = uiState.isListening,
            audioLevel = uiState.audioLevel,
            showPauseIcon = uiState.showPauseIcon,
            liquidFillProgress = micFillProgress,
            liquidWavePhase = liquidWavePhase,
            onClick = onMicTap
        )
        Spacer(Modifier.width(14.dp))
        CrownButton(
            isMasterMode = uiState.isMasterMode,
            liquidFillProgress = micFillProgress,
            liquidWavePhase = liquidWavePhase,
            onClick = onCrownTap
        )
    }
}

// ---------------------------------------------------------------------------
// Typing Input Row
// ---------------------------------------------------------------------------

@Composable
private fun TypingInputRow(
    uiState: RecitationUiState,
    onInputChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onSubmitDirect: (String) -> Unit,
    onFirstLetterToggle: () -> Unit,
    onCrownTap: () -> Unit,
    liquidFillProgress: Float = 0f,
    liquidWavePhase: Float = 0f,
    modifier: Modifier = Modifier
) {
    // Track local text state to avoid BasicTextField controlled-value mismatch.
    // We need a counter to force the TextField to reset after FL submissions.
    var localText by remember { mutableStateOf("") }
    var textFieldKey by remember { mutableStateOf(0) }

    val handleInput: (String) -> Unit = { newValue ->
        if (uiState.isFirstLetterToggle && newValue.isNotEmpty()) {
            // FL mode: submit the character directly, then force a fresh TextField
            onSubmitDirect(newValue)
            localText = ""
            textFieldKey++ // forces BasicTextField to remount with empty value
        } else if (newValue.endsWith(" ") || newValue.endsWith("\n")) {
            onInputChange(newValue.trimEnd())
            onSubmit()
            localText = ""
            textFieldKey++
        } else {
            localText = newValue
            onInputChange(newValue)
        }
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(80.dp),
        verticalAlignment = Alignment.Bottom
    ) {
        Box(Modifier.offset(y = (-3).dp)) {
            FirstLetterButton(isToggled = uiState.isFirstLetterToggle, onClick = onFirstLetterToggle)
        }
        Spacer(Modifier.width(8.dp))

        // Text input field
        Box(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(10.dp))
                .background(MaterialTheme.colorScheme.surface)
                .border(3.dp, if (uiState.isMasterMode) MasterYellow else iOSBlue, RoundedCornerShape(10.dp))
                .padding(horizontal = 20.dp, vertical = 14.dp)
        ) {
            val placeholder = if (uiState.isFirstLetterToggle) "Type the first letter..." else "Type the word..."

            if (localText.isEmpty()) {
                Text(
                    text = placeholder,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            // key() forces remount after each FL submission so TextField resets cleanly
            key(textFieldKey) {
                val fieldFocus = remember { FocusRequester() }
                LaunchedEffect(Unit) { fieldFocus.requestFocus() }

                BasicTextField(
                    value = localText,
                    onValueChange = handleInput,
                    textStyle = TextStyle(
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                        textAlign = TextAlign.Center
                    ),
                    singleLine = true,
                    cursorBrush = SolidColor(iOSBlue),
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.None,
                        autoCorrectEnabled = false,
                        imeAction = ImeAction.Done
                    ),
                    keyboardActions = KeyboardActions(onDone = { onSubmit() }),
                    modifier = Modifier
                        .fillMaxWidth()
                        .focusRequester(fieldFocus)
                )
            }
        }

        Spacer(Modifier.width(8.dp))
        Box(Modifier.offset(y = (-3).dp)) {
            CrownButton(
                isMasterMode = uiState.isMasterMode,
                liquidFillProgress = liquidFillProgress,
                liquidWavePhase = liquidWavePhase,
                onClick = onCrownTap
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Multiple Choice Grid
// ---------------------------------------------------------------------------

@Composable
private fun MultipleChoiceGrid(
    choices: List<String>,
    correctIndex: Int,
    wrongIndex: Int?,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        modifier = modifier
            .fillMaxWidth()
            .height(88.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        itemsIndexed(choices) { index, choice ->
            val bgColor by animateColorAsState(
                targetValue = if (wrongIndex == index) MismatchRed else iOSBlue,
                animationSpec = tween(200), label = "mcBg$index"
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(38.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(bgColor)
                    .clickable { onSelect(index) },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = choice,
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    style = MaterialTheme.typography.bodyLarge,
                    maxLines = 1
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Shared Buttons
// ---------------------------------------------------------------------------

@Composable
private fun FirstLetterButton(isToggled: Boolean, onClick: () -> Unit) {
    val bgColor by animateColorAsState(
        targetValue = if (isToggled) Color(0xFF7A71F0)
        else Color(0xFFBDBDBD),
        animationSpec = tween(350, easing = EaseInOut), label = "flBg"
    )
    Box(
        modifier = Modifier.size(40.dp).shadow(2.dp, CircleShape).clip(CircleShape)
            .background(bgColor).clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Icon(
            painter = painterResource(id = R.drawable.ic_font_download),
            contentDescription = "First Letter",
            tint = Color.White,
            modifier = Modifier.size(18.dp)
        )
    }
}

@Composable
private fun CrownButton(
    isMasterMode: Boolean,
    liquidFillProgress: Float = 0f,
    liquidWavePhase: Float = 0f,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .shadow(2.dp, CircleShape)
            .clip(CircleShape)
            .background(Color(0xFFBDBDBD))
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        // Liquid yellow fill inside crown button
        if (liquidFillProgress > 0.01f) {
            LiquidWaveCanvas(
                progress = liquidFillProgress,
                phase = liquidWavePhase,
                waveHeight = 2f,
                brush = Brush.verticalGradient(listOf(MasterYellow, MasterYellow)),
                modifier = Modifier.matchParentSize()
            )
        }
        Icon(
            painter = painterResource(id = R.drawable.ic_crown),
            contentDescription = "Master",
            tint = if (isMasterMode) Color.Black else Color.White,
            modifier = Modifier.size(26.dp)
        )
    }
}

@Composable
private fun MasterStreakCounter(streak: Int, isActive: Boolean) {
    Box(
        modifier = Modifier.size(40.dp).shadow(2.dp, CircleShape).clip(CircleShape)
            .background(if (isActive) Color(0xFFFFC107) else Color(0xFFBDBDBD)),
        contentAlignment = Alignment.Center
    ) {
        Text("$streak/3", fontSize = 14.sp, fontWeight = FontWeight.Bold,
            color = if (isActive) Color.Black else MaterialTheme.colorScheme.onSurface)
    }
}

// ---------------------------------------------------------------------------
// Mic Button with waveform
// ---------------------------------------------------------------------------

@Composable
private fun MicButton(
    isListening: Boolean,
    audioLevel: Float,
    showPauseIcon: Boolean,
    liquidFillProgress: Float = 0f,
    liquidWavePhase: Float = 0f,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(70.dp)
            .shadow(4.dp, CircleShape)
            .clip(CircleShape)
            .background(iOSBlue)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        // Yellow liquid fill overlay for master mode
        if (liquidFillProgress > 0.01f) {
            LiquidWaveCanvas(
                progress = liquidFillProgress,
                phase = liquidWavePhase,
                waveHeight = 4f,
                brush = Brush.verticalGradient(listOf(MasterYellow, MasterYellow)),
                modifier = Modifier.matchParentSize()
            )
        }
        if (!isListening) {
            Icon(Icons.Default.Mic, contentDescription = "Start", tint = Color.White, modifier = Modifier.size(42.dp))
        } else if (showPauseIcon) {
            Icon(Icons.Default.Pause, contentDescription = "Paused", tint = Color.White, modifier = Modifier.size(30.dp))
        } else {
            VoiceWaveform(audioLevel = audioLevel)
        }
    }
}

@Composable
private fun VoiceWaveform(audioLevel: Float) {
    val scales = listOf(0.5f, 0.85f, 1.0f, 0.75f, 0.45f)
    val minH = 11.dp; val maxH = 53.dp

    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        scales.forEach { scale ->
            val h by animateDpAsState(minH + (maxH - minH) * audioLevel * scale, tween(80, easing = EaseOut), label = "bh")
            Box(Modifier.width(8.dp).height(h).clip(RoundedCornerShape(4.dp)).background(Color.White))
        }
    }
}

// ---------------------------------------------------------------------------
// Control Pill (dark bottom bar)
// ---------------------------------------------------------------------------

@Composable
private fun ControlPill(
    uiState: RecitationUiState,
    onReset: () -> Unit,
    onInfo: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(50))
            .background(Color(0xFF333333))
            .padding(horizontal = 12.dp).padding(top = 7.dp, bottom = 3.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Top row: info icon — numbers — reset icon
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(Modifier.width(50.dp).clickable { onInfo() }, contentAlignment = Alignment.Center) {
                Icon(painter = painterResource(id = R.drawable.ic_info), "Info", tint = Color.White.copy(alpha = 0.7f), modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.weight(1f))
            Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                Text("${uiState.correctCount}", fontSize = 18.sp, lineHeight = 18.sp, fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace, color = CorrectGreen,
                    textAlign = TextAlign.Center, modifier = Modifier.width(40.dp))
                Text("${uiState.mistakeCount}", fontSize = 18.sp, lineHeight = 18.sp, fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace, color = MismatchRed,
                    textAlign = TextAlign.Center, modifier = Modifier.width(40.dp))
                Text("${uiState.hintCount}", fontSize = 18.sp, lineHeight = 18.sp, fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace, color = PendingYellow,
                    textAlign = TextAlign.Center, modifier = Modifier.width(40.dp))
            }
            Spacer(Modifier.weight(1f))
            Box(Modifier.width(50.dp).clickable { onReset() }, contentAlignment = Alignment.Center) {
                Icon(painter = painterResource(id = R.drawable.ic_refresh), "Reset", tint = Color.White.copy(alpha = 0.7f), modifier = Modifier.size(20.dp))
            }
        }
        // Bottom row: INFO text — icons — RESET text
        Row(
            modifier = Modifier.fillMaxWidth().offset(y = (-3).dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(Modifier.width(50.dp), contentAlignment = Alignment.Center) {
                Text("INFO", fontSize = 8.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.7f))
            }
            Spacer(Modifier.weight(1f))
            Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                Box(Modifier.width(40.dp), contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.Check, null, tint = CorrectGreen.copy(alpha = 0.7f), modifier = Modifier.size(14.dp))
                }
                Box(Modifier.width(40.dp), contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.Close, null, tint = MismatchRed.copy(alpha = 0.7f), modifier = Modifier.size(14.dp))
                }
                Box(Modifier.width(40.dp), contentAlignment = Alignment.Center) {
                    Icon(painter = painterResource(id = R.drawable.ic_lightbulb), null, tint = PendingYellow.copy(alpha = 0.7f), modifier = Modifier.size(14.dp))
                }
            }
            Spacer(Modifier.weight(1f))
            Box(Modifier.width(50.dp), contentAlignment = Alignment.Center) {
                Text("RESET", fontSize = 8.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.7f))
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Mistake Dispute Popup
// ---------------------------------------------------------------------------

/** Stable per-word mistake character map — ensures the same word index always shows the same sprite */
private val stableMistakeCharacters = mutableMapOf<Int, BrainCharacter>()

private fun stableMistakeCharacter(wordIndex: Int): BrainCharacter {
    stableMistakeCharacters[wordIndex]?.let { return it }
    val used = stableMistakeCharacters.values.toSet()
    val available = BrainCharacter.mistakeCharacters.filter { it !in used }
    val character = available.randomOrNull() ?: BrainCharacter.randomMistake()
    stableMistakeCharacters[wordIndex] = character
    return character
}

@Composable
private fun MistakeDisputePopup(wordIndex: Int, spokenWord: String, onDismiss: () -> Unit, onOverride: () -> Unit) {
    val character = remember(wordIndex) { stableMistakeCharacter(wordIndex) }
    Box(
        modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f)).clickable { onDismiss() },
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier.padding(32.dp).clip(RoundedCornerShape(16.dp))
                .background(MaterialTheme.colorScheme.surface).clickable { /* consume */ }.padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            BrainCharacterView(character = character, size = 150.dp)
            Spacer(Modifier.height(16.dp))
            Row {
                Text("I heard you say \"", style = MaterialTheme.typography.bodyLarge)
                Text(spokenWord, style = MaterialTheme.typography.bodyLarge, color = MismatchRed, fontWeight = FontWeight.Bold)
                Text("\"", style = MaterialTheme.typography.bodyLarge)
            }
            Spacer(Modifier.height(20.dp))
            Button(onClick = onOverride, colors = ButtonDefaults.buttonColors(containerColor = CorrectGreen)) {
                Text("No, I said the right word", color = Color.White)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Completion View — score circle + results
// ---------------------------------------------------------------------------

@Composable
private fun CompletionView(uiState: RecitationUiState, isTutorialMode: Boolean = false, onDone: () -> Unit, onRetry: () -> Unit) {
    val accuracyPercent = (uiState.accuracy * 100).toInt()
    val (accentColor, message) = accuracyTier(uiState.accuracy)
    val character = remember { if (uiState.accuracy >= 0.7) BrainCharacter.randomSuccess() else BrainCharacter.randomMistake() }

    var animatedAccuracy by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(uiState.accuracy) { animatedAccuracy = 0f; delay(200); animatedAccuracy = uiState.accuracy.toFloat() }
    val ringProgress by animateFloatAsState(animatedAccuracy, tween(1000, easing = EaseInOut), label = "ring")

    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 32.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("$accuracyPercent%", fontSize = 36.sp, fontWeight = FontWeight.Bold, color = accentColor)
        Spacer(Modifier.height(14.dp))

        Box(Modifier.size(160.dp), contentAlignment = Alignment.Center) {
            Canvas(Modifier.fillMaxSize()) {
                val sw = 16.dp.toPx(); val inset = sw / 2
                drawArc(Color(0xFFE8E8E8), 0f, 360f, false,
                    Offset(inset, inset), Size(size.width - sw, size.height - sw), style = Stroke(sw, cap = StrokeCap.Round))
                drawArc(accentColor, -90f, 360f * ringProgress, false,
                    Offset(inset, inset), Size(size.width - sw, size.height - sw), style = Stroke(sw, cap = StrokeCap.Round))
            }
            BrainCharacterView(character = character, size = 100.dp)
        }

        Spacer(Modifier.height(20.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
            ResultStat("Words", "${uiState.testedWordCount}", MaterialTheme.colorScheme.onSurface)
            ResultStat("Correct", "${uiState.correctCount}", CorrectGreen)
            ResultStat("Mistakes", "${uiState.mistakeCount}", MismatchRed)
        }
        Spacer(Modifier.height(12.dp))
        Text(message, style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.onSurface)
        Spacer(Modifier.height(32.dp))

        if (!isTutorialMode) {
            Button(onClick = onRetry, colors = ButtonDefaults.buttonColors(containerColor = iOSBlue),
                shape = CircleShape,
                modifier = Modifier.fillMaxWidth(0.6f).height(50.dp)) { Text("Try Again", color = Color.White, fontWeight = FontWeight.Bold) }
            Spacer(Modifier.height(8.dp))
        }
        Button(onClick = onDone,
            colors = ButtonDefaults.buttonColors(
                containerColor = if (isTutorialMode) Color(0xFF7A71F0) else MaterialTheme.colorScheme.surfaceVariant
            ),
            shape = CircleShape,
            modifier = Modifier.fillMaxWidth(0.6f).height(50.dp)) {
            Text(
                if (isTutorialMode) "Continue" else "Done",
                color = if (isTutorialMode) Color.White else MaterialTheme.colorScheme.onSurface,
                fontWeight = if (isTutorialMode) FontWeight.Bold else FontWeight.Normal
            )
        }
    }
}

@Composable
private fun ResultStat(label: String, value: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = color)
        Text(label, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
    }
}

private fun accuracyTier(accuracy: Double): Pair<Color, String> = when {
    accuracy >= 0.95 -> Pair(CorrectGreen, "Perfect!")
    accuracy >= 0.90 -> Pair(CorrectGreen, "Excellent!")
    accuracy >= 0.80 -> Pair(Color(0xFFFF9800), "Great job!")
    accuracy >= 0.70 -> Pair(Color(0xFFFF9800), "Good effort!")
    accuracy >= 0.50 -> Pair(Color(0xFFFF9800), "Nice try!")
    else -> Pair(MismatchRed, "Keep practicing!")
}

// ---------------------------------------------------------------------------
// Master Info Popup
// ---------------------------------------------------------------------------

private val MasterYellow = Color(0xFFFFC107)

@Composable
private fun MasterInfoPopup(currentStreak: Int, onDismiss: () -> Unit, onStart: () -> Unit) {
    val character = remember { BrainCharacter.randomSuccess() }
    Box(
        modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f)).clickable { onDismiss() },
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier.padding(32.dp).clip(RoundedCornerShape(20.dp))
                .background(MaterialTheme.colorScheme.surface).clickable { /* consume */ }.padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            BrainCharacterView(character = character, size = 120.dp)
            Spacer(Modifier.height(16.dp))
            Text("Master This Quote", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text(
                "Get 3 consecutive perfect recitations with no hints or reveals.",
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.height(16.dp))

            // Crown progress: 3 crowns (matches iOS CrownFillView)
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                repeat(3) { i ->
                    val filled = i < currentStreak
                    Icon(
                        painter = painterResource(id = R.drawable.ic_crown),
                        contentDescription = if (filled) "Crown filled" else "Crown empty",
                        tint = if (filled) MasterYellow else Color(0xFFBDBDBD),
                        modifier = Modifier.size(36.dp)
                    )
                }
            }

            Spacer(Modifier.height(8.dp))
            Text(
                "Miss one and you start over.",
                style = MaterialTheme.typography.bodySmall,
                color = MismatchRed,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(Modifier.height(20.dp))

            Button(
                onClick = onStart,
                colors = ButtonDefaults.buttonColors(containerColor = MasterYellow),
                shape = CircleShape,
                modifier = Modifier.fillMaxWidth().height(50.dp)
            ) {
                Text("Let's Go ✓", color = Color.Black, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun QuoteInfoPopup(quote: Quote, quoteStore: QuoteStore, onDismiss: () -> Unit, onScissors: () -> Unit) {
    val sessions = quoteStore.getSessions(quote.id)
    val recentSessions = sessions.sortedByDescending { it.completedAt }.take(3)
    var showResetAlert by remember { mutableStateOf(false) }

    // Compute trouble phrases (same logic as iOS)
    val troublePhrases = remember(sessions) {
        val quoteWords = quote.text.trim().split("\\s+".toRegex()).filter { it.isNotEmpty() }
        val positionCounts = mutableMapOf<Int, Int>()
        for (session in sessions) {
            for (mistake in session.mistakes) {
                if (mistake.certainty == MistakeCertainty.DEFINITE) {
                    positionCounts[mistake.position] = (positionCounts[mistake.position] ?: 0) + 1
                }
            }
        }
        val topPositions = positionCounts.entries
            .sortedWith(compareByDescending<Map.Entry<Int, Int>> { it.value }.thenBy { it.key })
            .take(6)
            .map { it.key }

        val seen = mutableSetOf<String>()
        val result = mutableListOf<String>()
        for (pos in topPositions) {
            if (pos < 0 || pos >= quoteWords.size) continue
            val start = maxOf(0, pos - 2)
            val end = minOf(quoteWords.size - 1, pos + 2)
            val phrase = quoteWords.subList(start, end + 1).joinToString(" ")
            val normalized = phrase.lowercase()
            if (normalized in seen) continue
            seen.add(normalized)
            result.add(phrase)
            if (result.size >= 3) break
        }
        result
    }

    // Mastery level colors
    val masteryColor = when (quote.masteryLevel) {
        MasteryLevel.NONE -> Color.Gray
        MasteryLevel.LEARNING -> Color(0xFF4CAF50) // green
        MasteryLevel.ADVANCING -> Color(0xFFFF9800) // orange
        MasteryLevel.PROFICIENT -> Color(0xFF3F51B5) // indigo
        MasteryLevel.MASTERED -> Color(0xFFFFC107) // yellow
    }

    val masteryIcon = when (quote.masteryLevel) {
        MasteryLevel.NONE -> R.drawable.ic_leaf
        MasteryLevel.LEARNING -> R.drawable.ic_leaf
        MasteryLevel.ADVANCING -> R.drawable.ic_lightbulb
        MasteryLevel.PROFICIENT -> R.drawable.ic_sparkles
        MasteryLevel.MASTERED -> R.drawable.ic_crown
    }

    // Full-screen sheet matching iOS QuoteAccuracyDetailView presented via
    // `.presentationDetents([.large])`. Scissors button on the left (opens split
    // overlay), quote title centered, Done button on the right.
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surface)
            .systemBarsPadding()
    ) {
        // Title bar with scissors + title + Done (mirrors iOS NavigationStack toolbar)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Scissors button — opens split overlay
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .shadow(2.dp, CircleShape)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surface)
                    .clickable { onScissors() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.ContentCut,
                    contentDescription = "Split quote",
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(20.dp)
                )
            }
            Spacer(Modifier.width(12.dp))
            Text(
                text = quote.displayTitle,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f)
            )
            TextButton(onClick = onDismiss) {
                Text("Done", fontWeight = FontWeight.SemiBold)
            }
        }
        HorizontalDivider()

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
            // Mastery level badge with icon
            Spacer(Modifier.height(4.dp))
            Icon(
                painter = painterResource(id = masteryIcon),
                contentDescription = quote.masteryLevel.displayName,
                tint = masteryColor,
                modifier = Modifier.size(80.dp)
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = quote.masteryLevel.displayName,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = masteryColor
            )
            Spacer(Modifier.height(16.dp))

            // Stats row card
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                    .border(2.dp, Color(0xFF777777), RoundedCornerShape(12.dp))
                    .padding(vertical = 16.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Attempts
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.weight(1f)) {
                    Text("${quote.practiceCount}", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text("Attempts", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                // Divider
                Box(Modifier.width(1.dp).height(40.dp).background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)))
                // Best
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.weight(1f)) {
                    Text("${(quote.bestAccuracy * 100).toInt()}%", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text("Best", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                // Divider
                Box(Modifier.width(1.dp).height(40.dp).background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)))
                // Last Practiced
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.weight(1f)) {
                    Text(
                        text = formatRelativeDate(quote.lastPracticedAt),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text("Last Practiced", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Spacer(Modifier.height(16.dp))

            // Trouble Spots
            if (troublePhrases.isNotEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                        .border(2.dp, Color(0xFF777777), RoundedCornerShape(12.dp))
                        .padding(16.dp),
                    horizontalAlignment = Alignment.Start
                ) {
                    Text("Trouble Spots", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    troublePhrases.forEach { phrase ->
                        Text(
                            text = phrase,
                            style = MaterialTheme.typography.bodyMedium.copy(
                                fontFamily = FontFamily.Serif
                            ),
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.padding(vertical = 2.dp)
                        )
                    }
                }
                Spacer(Modifier.height(16.dp))
            }

            // Recent Sessions
            if (recentSessions.isNotEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                        .border(2.dp, Color(0xFF777777), RoundedCornerShape(12.dp))
                        .padding(16.dp),
                    horizontalAlignment = Alignment.Start
                ) {
                    Text("Recent Sessions", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    recentSessions.forEach { session ->
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = formatRelativeDate(session.completedAt),
                                    style = MaterialTheme.typography.bodyMedium
                                )
                                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Text(
                                        text = formatSessionDuration(session.duration),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    if (session.mistakes.isNotEmpty()) {
                                        Text(
                                            text = "${session.mistakes.size} mistake${if (session.mistakes.size == 1) "" else "s"}",
                                            style = MaterialTheme.typography.labelSmall,
                                            color = Color(0xFFE53935)
                                        )
                                    }
                                }
                            }
                            Text(
                                text = "${(session.accuracy * 100).toInt()}%",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = when {
                                    session.accuracy >= 0.9 -> Color(0xFF4CAF50)
                                    session.accuracy >= 0.7 -> Color(0xFFFF9800)
                                    else -> Color(0xFFE53935)
                                }
                            )
                        }
                    }
                }
                Spacer(Modifier.height(16.dp))
            }

            // Reset Statistics button
            TextButton(onClick = { showResetAlert = true }) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.error,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(6.dp))
                Text("Reset Statistics", color = MaterialTheme.colorScheme.error)
            }
            Spacer(Modifier.height(16.dp))
        } // inner scrollable Column
    }

    if (showResetAlert) {
        AlertDialog(
            onDismissRequest = { showResetAlert = false },
            title = { Text("Reset Statistics") },
            text = { Text("This will reset all practice history, accuracy, and level progress for this quote.") },
            confirmButton = {
                TextButton(onClick = {
                    quoteStore.resetQuoteStats(quote)
                    showResetAlert = false
                    onDismiss()
                }) { Text("Reset", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showResetAlert = false }) { Text("Cancel") }
            }
        )
    }
}

// ---------------------------------------------------------------------------
// Chunk Navigation Header (shown when quote is inline-split)
// ---------------------------------------------------------------------------

@Composable
private fun ChunkNavigationHeader(
    activeIndex: Int,
    total: Int,
    onPrev: () -> Unit,
    onNext: () -> Unit
) {
    val canPrev = activeIndex > 0
    val canNext = activeIndex < total - 1
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(
            onClick = onPrev,
            enabled = canPrev,
            modifier = Modifier.size(32.dp)
        ) {
            Icon(
                imageVector = Icons.Default.ChevronLeft,
                contentDescription = "Previous chunk",
                tint = if (canPrev) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
            )
        }
        Text(
            text = "${activeIndex + 1} of $total",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 4.dp)
        )
        IconButton(
            onClick = onNext,
            enabled = canNext,
            modifier = Modifier.size(32.dp)
        ) {
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = "Next chunk",
                tint = if (canNext) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Split / Merge Overlay (mirrors iOS splitMergeOverlay — Pass 1 minimal)
// ---------------------------------------------------------------------------

@Composable
private fun ChunkPeekContainer(
    info: ChunkInfo,
    isDirectlyAdjacent: Boolean,
    isBefore: Boolean,
    onTap: () -> Unit
) {
    val words = info.text.split(Regex("\\s+")).filter { it.isNotEmpty() }
    val previewText = when {
        words.size <= 8 -> info.text
        isBefore && isDirectlyAdjacent -> "... " + words.takeLast(8).joinToString(" ")
        else -> words.take(8).joinToString(" ") + " ..."
    }
    val accuracyColor: Color? = info.accuracy?.let { acc ->
        when {
            acc >= 0.9 -> Color(0xFF2E7D32)
            acc >= 0.7 -> Color(0xFFEF6C00)
            else -> Color(0xFFC62828)
        }
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .height(44.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
            .clickable { onTap() }
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = previewText,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )
        if (info.isComplete && accuracyColor != null && info.accuracy != null) {
            Spacer(Modifier.width(8.dp))
            Text(
                text = "${(info.accuracy * 100).toInt()}%",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = accuracyColor
            )
        }
    }
}

@Composable
private fun SplitMergeOverlay(
    isSplit: Boolean,
    splitCount: Int,
    wordCount: Int,
    activeChunkIndex: Int,
    onSetCount: (Int) -> Unit,
    onConfirmSplit: () -> Unit,
    onUnsplit: () -> Unit,
    onMergePrevious: () -> Unit,
    onDismiss: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.4f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onDismiss() },
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = 32.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(MaterialTheme.colorScheme.surface)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) { /* consume */ }
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "Quote Splitting",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )

            if (isSplit) {
                Button(
                    onClick = onMergePrevious,
                    enabled = activeChunkIndex > 0,
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF3F51B5))
                ) {
                    Text("Merge with previous part", color = Color.White, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.width(8.dp))
                    Icon(Icons.Default.CallMerge, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                }
                Button(
                    onClick = onUnsplit,
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2196F3))
                ) {
                    Text("Back to full quote", color = Color.White, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.width(8.dp))
                    Icon(Icons.Default.FormatQuote, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                }
            } else {
                val perSection = if (splitCount > 0) maxOf(1, wordCount / splitCount) else wordCount
                Text(
                    text = "How many parts?",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    IconButton(
                        onClick = { if (splitCount > 2) onSetCount(splitCount - 1) },
                        enabled = splitCount > 2,
                        modifier = Modifier
                            .size(44.dp)
                            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(10.dp))
                    ) {
                        Text("−", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    }
                    Text(
                        text = "$splitCount",
                        fontSize = 42.sp,
                        fontWeight = FontWeight.Bold
                    )
                    IconButton(
                        onClick = { if (splitCount < 10) onSetCount(splitCount + 1) },
                        enabled = splitCount < 10,
                        modifier = Modifier
                            .size(44.dp)
                            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(10.dp))
                    ) {
                        Text("+", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    }
                }
                Text(
                    text = "~$perSection words each",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Button(
                    onClick = onConfirmSplit,
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF3F51B5))
                ) {
                    Icon(Icons.Default.ContentCut, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Split", color = Color.White, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

private fun formatRelativeDate(timestamp: Long?): String {
    if (timestamp == null) return "Never"
    val now = System.currentTimeMillis()
    val diffMs = now - timestamp
    val days = TimeUnit.MILLISECONDS.toDays(diffMs)
    return when {
        days == 0L -> "Today"
        days == 1L -> "Yesterday"
        days < 7L -> "${days}d ago"
        days < 30L -> "${days / 7}w ago"
        else -> "${days / 30}mo ago"
    }
}

private fun formatSessionDuration(durationMs: Long): String {
    val totalSecs = (durationMs / 1000).toInt()
    val mins = totalSecs / 60
    val secs = totalSecs % 60
    return if (mins > 0) "${mins}m ${secs}s" else "${secs}s"
}

private fun formatRecordingDate(timestamp: Long): String {
    val formatter = SimpleDateFormat("MMMM d, yyyy", java.util.Locale.getDefault())
    return formatter.format(Date(timestamp))
}

// Crown row helper used in multiple places
@Composable
private fun CrownRow(filledCount: Int, total: Int = 3, size: Float = 32f) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        repeat(total) { i ->
            Icon(
                painter = painterResource(id = R.drawable.ic_crown),
                contentDescription = if (i < filledCount) "Crown filled" else "Crown empty",
                tint = if (i < filledCount) MasterYellow else Color(0xFFBDBDBD),
                modifier = Modifier.size(size.dp)
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Master Hint Block Popup
// ---------------------------------------------------------------------------

@Composable
private fun MasterHintBlockPopup(onDismiss: () -> Unit) {
    Box(
        modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f)).clickable { onDismiss() },
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier.padding(40.dp).clip(RoundedCornerShape(16.dp))
                .background(MaterialTheme.colorScheme.surface).clickable { /* consume */ }.padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("🚫", fontSize = 40.sp)
            Spacer(Modifier.height(12.dp))
            Text("Hints Disabled", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text(
                "Hints are not available in Master Mode. You must recite entirely from memory!",
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.height(16.dp))
            Button(onClick = onDismiss) { Text("Got it") }
        }
    }
}

// ---------------------------------------------------------------------------
// Master Completion View
// ---------------------------------------------------------------------------

@Composable
private fun MasterCompletionView(uiState: RecitationUiState, onDone: () -> Unit, onRetry: () -> Unit) {
    val result = uiState.masterResult ?: return
    val previousStreak = uiState.previousMasteryStreak

    when (result) {
        MasterResult.MASTERED -> MasteredCelebration(onDone = onDone)
        MasterResult.PASSED -> MasterPassedView(previousStreak = previousStreak, onRetry = onRetry, onDone = onDone)
        MasterResult.FAILED -> MasterFailedView(previousStreak = previousStreak, onRetry = onRetry, onDone = onDone)
    }
}

@Composable
private fun MasterFailedView(previousStreak: Int, onRetry: () -> Unit, onDone: () -> Unit) {
    val character = remember { BrainCharacter.randomMistake() }
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 32.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        BrainCharacterView(character = character, size = 120.dp)
        Spacer(Modifier.height(20.dp))
        Text("Not quite!", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = MismatchRed)
        Spacer(Modifier.height(8.dp))
        Text("Keep practicing!", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(24.dp))

        // Show empty crowns (streak reset to 0)
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            repeat(3) {
                Icon(
                    painter = painterResource(id = R.drawable.ic_crown),
                    contentDescription = "Crown empty",
                    tint = Color(0xFFBDBDBD),
                    modifier = Modifier.size(36.dp)
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        Text("Streak reset to 0", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)

        Spacer(Modifier.height(32.dp))
        Button(onClick = onRetry, colors = ButtonDefaults.buttonColors(containerColor = MasterYellow),
            shape = CircleShape,
            modifier = Modifier.fillMaxWidth(0.6f).height(50.dp)) {
            Text("Try Again", color = Color.Black, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(8.dp))
        Button(onClick = onDone, colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            shape = CircleShape,
            modifier = Modifier.fillMaxWidth(0.6f).height(50.dp)) {
            Text("Done", color = MaterialTheme.colorScheme.onSurface)
        }
    }
}

@Composable
private fun MasterPassedView(previousStreak: Int, onRetry: () -> Unit, onDone: () -> Unit) {
    val character = remember { BrainCharacter.randomSuccess() }
    val newStreak = (previousStreak + 1).coerceAtMost(3)
    val remaining = 3 - newStreak

    // Animate the new crown filling in
    var showNewCrown by remember { mutableStateOf(false) }
    val crownScale by animateFloatAsState(
        targetValue = if (showNewCrown) 1f else 0f,
        animationSpec = tween(500, easing = EaseInOut), label = "crownFill"
    )
    LaunchedEffect(Unit) { delay(600); showNewCrown = true }

    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 32.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        BrainCharacterView(character = character, size = 120.dp)
        Spacer(Modifier.height(20.dp))
        Text("Nice!", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = MasterYellow)
        Spacer(Modifier.height(24.dp))

        // Crown progress with animated new crown
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            repeat(3) { i ->
                val isFilled = i < previousStreak
                val isNew = i == previousStreak
                val iconSize = if (isNew && showNewCrown) 43.dp else 36.dp
                val animatedSize by animateDpAsState(
                    targetValue = iconSize,
                    animationSpec = tween(500, easing = EaseInOut), label = "crownSize$i"
                )
                Icon(
                    painter = painterResource(id = R.drawable.ic_crown),
                    contentDescription = if (isFilled || isNew) "Crown filled" else "Crown empty",
                    tint = if (isFilled) MasterYellow
                        else if (isNew && showNewCrown) MasterYellow
                        else Color(0xFFBDBDBD),
                    modifier = Modifier.size(animatedSize)
                )
            }
        }

        Spacer(Modifier.height(12.dp))
        Text(
            if (remaining > 0) "$remaining more to go!" else "",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(Modifier.height(32.dp))
        Button(onClick = onRetry, colors = ButtonDefaults.buttonColors(containerColor = MasterYellow),
            shape = CircleShape,
            modifier = Modifier.fillMaxWidth(0.6f).height(50.dp)) {
            Text("Try Again", color = Color.Black, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(8.dp))
        Button(onClick = onDone, colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            shape = CircleShape,
            modifier = Modifier.fillMaxWidth(0.6f).height(50.dp)) {
            Text("Done", color = MaterialTheme.colorScheme.onSurface)
        }
    }
}

// ---------------------------------------------------------------------------
// Mastered Celebration (confetti + crown slam)
// ---------------------------------------------------------------------------

@Composable
private fun MasteredCelebration(onDone: () -> Unit) {
    var showCrown by remember { mutableStateOf(false) }
    var showText1 by remember { mutableStateOf(false) }
    var showText2 by remember { mutableStateOf(false) }
    var showCrowns by remember { mutableStateOf(false) }
    var showButton by remember { mutableStateOf(false) }

    // Staggered reveals
    LaunchedEffect(Unit) {
        delay(300); showCrown = true
        delay(300); showText1 = true
        delay(100); showText2 = true
        delay(100); showCrowns = true
        delay(100); showButton = true
    }

    val crownOffset by animateFloatAsState(
        targetValue = if (showCrown) 0f else -300f,
        animationSpec = tween(500, easing = EaseOut), label = "crownSlam"
    )
    val crownScale by animateFloatAsState(
        targetValue = if (showCrown) 1f else 3f,
        animationSpec = tween(500, easing = EaseOut), label = "crownScale"
    )

    Box(modifier = Modifier.fillMaxSize()) {
        // Confetti layer
        ConfettiOverlay()

        // Content
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 32.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Crown slam
            val slamSize = (70 * crownScale).dp
            Icon(
                painter = painterResource(id = R.drawable.ic_crown),
                contentDescription = "Crown",
                tint = MasterYellow,
                modifier = Modifier
                    .size(slamSize)
                    .padding(top = crownOffset.dp.coerceAtLeast(0.dp))
            )

            Spacer(Modifier.height(24.dp))

            if (showText1) {
                Text(
                    "Congratulations!",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MasterYellow
                )
            }
            Spacer(Modifier.height(8.dp))
            if (showText2) {
                Text(
                    "You've mastered this quote!",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(Modifier.height(24.dp))
            if (showCrowns) {
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    repeat(3) {
                        Icon(
                            painter = painterResource(id = R.drawable.ic_crown),
                            contentDescription = "Crown filled",
                            tint = MasterYellow,
                            modifier = Modifier.size(36.dp)
                        )
                    }
                }
            }

            Spacer(Modifier.height(32.dp))
            if (showButton) {
                Button(
                    onClick = onDone,
                    colors = ButtonDefaults.buttonColors(containerColor = MasterYellow),
                    shape = CircleShape,
                    modifier = Modifier.fillMaxWidth(0.6f).height(50.dp)
                ) {
                    Text("Done", color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Confetti
// ---------------------------------------------------------------------------

private data class ConfettiParticle(
    val x: Float, val speed: Float, val size: Float,
    val color: Color, val rotation: Float, val wiggle: Float
)

@Composable
private fun ConfettiOverlay() {
    val particles = remember {
        val colors = listOf(Color(0xFFFFC107), Color(0xFFFF9800), Color(0xFFF44336), Color(0xFF2196F3))
        List(50) {
            ConfettiParticle(
                x = Random.nextFloat(),
                speed = 1.5f + Random.nextFloat() * 2f,
                size = 6f + Random.nextFloat() * 6f,
                color = colors.random(),
                rotation = Random.nextFloat() * 360f,
                wiggle = Random.nextFloat() * 30f
            )
        }
    }

    var elapsed by remember { mutableFloatStateOf(0f) }
    var visible by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        val start = System.currentTimeMillis()
        while (visible) {
            elapsed = (System.currentTimeMillis() - start) / 1000f
            if (elapsed > 4f) { visible = false; break }
            delay(16L) // ~60fps
        }
    }

    if (!visible) return

    val alpha by animateFloatAsState(
        targetValue = if (elapsed > 3f) 0f else 1f,
        animationSpec = tween(1000), label = "confettiAlpha"
    )

    Canvas(modifier = Modifier.fillMaxSize()) {
        particles.forEach { p ->
            val y = (elapsed * p.speed * size.height / 4f) % (size.height + 100f) - 50f
            val x = p.x * size.width + sin(elapsed * 2f + p.rotation) * p.wiggle
            drawCircle(
                color = p.color.copy(alpha = alpha),
                radius = p.size,
                center = Offset(x, y)
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Liquid Wave Shape — draws a filled region from bottom up to a wavy line
// ---------------------------------------------------------------------------

@Composable
private fun LiquidWaveCanvas(
    progress: Float,
    phase: Float,
    waveHeight: Float = 12f,
    brush: Brush,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier) {
        if (progress < 0.01f) return@Canvas
        val w = size.width
        val h = size.height
        val waterY = h * (1f - progress)

        val path = Path().apply {
            moveTo(0f, waterY)
            var x = 0f
            while (x <= w) {
                val relX = x / w
                val y = waterY +
                    sin((relX * Math.PI.toFloat() * 3f) + phase) * waveHeight +
                    sin((relX * Math.PI.toFloat() * 1.5f) + phase * 0.7f) * (waveHeight * 0.5f)
                lineTo(x, y)
                x += 2f
            }
            lineTo(w, h)
            lineTo(0f, h)
            close()
        }
        drawPath(path, brush)
    }
}

// ===========================================================================
// Audio Mode UI
// ===========================================================================

private val AudioGreen = Color(0xFF4CAF50)
private val AudioOrange = Color(0xFFFF9800)
private val AudioRed = Color(0xFFF44336)
private val AudioIndigo = Color(0xFF7A71F0)
private val DarkPillBg = Color(0xFF333333)
private val PillButtonInactive = Color.White.copy(alpha = 0.7f)

// ---------------------------------------------------------------------------
// Audio Progress Bar (top, below title — seekable, colored by mode)
// ---------------------------------------------------------------------------

@Composable
private fun AudioProgressBar(
    audioState: AudioPlaybackState,
    ttsPlaying: Boolean,
    isRecording: Boolean,
    onSeek: (Float) -> Unit,
    modifier: Modifier = Modifier
) {
    val barColor = when {
        audioState.isRecordingMode -> AudioRed
        audioState.isTTSActive -> AudioOrange
        else -> AudioGreen
    }

    val fraction = when {
        audioState.isTTSActive -> if (ttsPlaying) 1f else 0f
        audioState.isRecordingMode && isRecording -> 1f
        audioState.duration > 0 -> (audioState.currentTime / audioState.duration).toFloat().coerceIn(0f, 1f)
        else -> 0f
    }

    val showTimeLabels = audioState.currentSource != null || (audioState.isRecordingMode && isRecording)

    Column(modifier = modifier.fillMaxWidth()) {
        // Time labels (like iOS: elapsed on left, remaining on right)
        if (showTimeLabels) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                val elapsed = if (audioState.isRecordingMode) audioState.recordingDuration else audioState.currentTime
                val remaining = if (audioState.isRecordingMode) 0.0 else (audioState.duration - audioState.currentTime).coerceAtLeast(0.0)
                Text(
                    formatTime(elapsed),
                    style = TextStyle(fontSize = 12.sp, fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    "-${formatTime(remaining)}",
                    style = TextStyle(fontSize = 12.sp, fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Spacer(Modifier.height(2.dp))
        }

        // Progress bar
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .pointerInput(Unit) {
                    detectTapGestures { offset ->
                        val seekFraction = (offset.x / size.width).coerceIn(0f, 1f)
                        onSeek(seekFraction)
                    }
                }
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(fraction)
                    .height(4.dp)
                    .background(barColor)
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Audio Play Button (center area — large circle + prev/next or record/TTS)
// ---------------------------------------------------------------------------

@Composable
private fun AudioPlayButton(
    audioState: AudioPlaybackState,
    ttsPlaying: Boolean,
    ttsHasPlayer: Boolean,
    isRecording: Boolean,
    onTogglePlayback: () -> Unit,
    onStartTTS: () -> Unit,
    onStopTTS: () -> Unit,
    onToggleTTS: () -> Unit,
    onStartRecording: () -> Unit,
    onStopRecording: () -> Unit,
    onPrev: () -> Unit,
    onNext: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .height(90.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        when {
            audioState.isRecordingMode -> {
                // Large red record/stop button (timer is in the control pill)
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .shadow(4.dp, CircleShape)
                        .clip(CircleShape)
                        .background(AudioRed)
                        .clickable(onClick = if (isRecording) onStopRecording else onStartRecording),
                    contentAlignment = Alignment.Center
                ) {
                    if (isRecording) {
                        Box(Modifier.size(28.dp).background(Color.White, RoundedCornerShape(4.dp)))
                    } else {
                        Icon(Icons.Default.Mic, null, tint = Color.White, modifier = Modifier.size(34.dp))
                    }
                }
            }

            audioState.isTTSActive -> {
                // TTS error
                audioState.ttsError?.let {
                    Text(it, color = AudioRed, fontSize = 11.sp, modifier = Modifier.padding(horizontal = 32.dp), textAlign = TextAlign.Center)
                    Spacer(Modifier.height(4.dp))
                }
                // Large orange play/stop button
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .shadow(4.dp, CircleShape)
                        .clip(CircleShape)
                        .background(AudioOrange)
                        .clickable(onClick = {
                            // Resume from pause if we already have a player; otherwise fresh start.
                            if (ttsPlaying || ttsHasPlayer) onToggleTTS() else onStartTTS()
                        }),
                    contentAlignment = Alignment.Center
                ) {
                    if (audioState.isTTSLoading) {
                        CircularProgressIndicator(color = Color.White, modifier = Modifier.size(34.dp), strokeWidth = 3.dp)
                    } else {
                        Icon(
                            if (ttsPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                            null, tint = Color.White, modifier = Modifier.size(34.dp)
                        )
                    }
                }
            }

            audioState.isLoadingAudio -> {
                Box(
                    modifier = Modifier.size(80.dp).clip(CircleShape).background(iOSBlue),
                    contentAlignment = Alignment.Center
                ) { CircularProgressIndicator(color = Color.White, modifier = Modifier.size(34.dp), strokeWidth = 3.dp) }
            }

            audioState.currentSource != null -> {
                val hasMultiple = audioState.playlist.size > 1
                // Play/Pause with prev/next (matching voice mode height)
                Row(
                    horizontalArrangement = Arrangement.spacedBy(20.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Prev
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .shadow(2.dp, CircleShape)
                            .clip(CircleShape)
                            .background(Color(0xFFBDBDBD))
                            .alpha(if (hasMultiple) 0.8f else 0.3f)
                            .then(if (hasMultiple) Modifier.clickable(onClick = onPrev) else Modifier),
                        contentAlignment = Alignment.Center
                    ) { Icon(Icons.Default.FastRewind, null, tint = Color.White, modifier = Modifier.size(22.dp)) }

                    // Large blue play/pause button
                    Box(
                        modifier = Modifier
                            .size(80.dp)
                            .shadow(4.dp, CircleShape)
                            .clip(CircleShape)
                            .background(iOSBlue)
                            .clickable(onClick = onTogglePlayback),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            if (audioState.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                            null, tint = Color.White, modifier = Modifier.size(34.dp)
                        )
                    }

                    // Next
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .shadow(2.dp, CircleShape)
                            .clip(CircleShape)
                            .background(Color(0xFFBDBDBD))
                            .alpha(if (hasMultiple) 0.8f else 0.3f)
                            .then(if (hasMultiple) Modifier.clickable(onClick = onNext) else Modifier),
                        contentAlignment = Alignment.Center
                    ) { Icon(Icons.Default.FastForward, null, tint = Color.White, modifier = Modifier.size(22.dp)) }
                }
            }

            else -> {
                // Nothing playing — show placeholder
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Audio Control Pill (dark pill at bottom — matches ControlPill style)
// ---------------------------------------------------------------------------

@Composable
private fun AudioControlPill(
    audioState: AudioPlaybackState,
    isRecording: Boolean,
    onToggleRepeat: () -> Unit,
    onBrowse: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onEnterRecording: () -> Unit,
    onCancelRecording: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(36.dp))
            .background(DarkPillBg)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        when {
            audioState.isRecordingMode && isRecording -> {
                // CANCEL | timer | spacer
                PillButton(icon = Icons.Default.Close, label = "CANCEL", onClick = onCancelRecording, width = 60.dp)
                Spacer(Modifier.weight(1f))
                Text(
                    formatTime(audioState.recordingDuration),
                    style = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace),
                    color = AudioRed
                )
                Spacer(Modifier.weight(1f))
                Spacer(Modifier.width(60.dp))
            }
            audioState.isRecordingMode -> {
                // CANCEL | 0:00 | BROWSE
                PillButton(icon = Icons.Default.Close, label = "CANCEL", onClick = onCancelRecording, width = 60.dp)
                Spacer(Modifier.weight(1f))
                Text(
                    "0:00",
                    style = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace),
                    color = Color.White.copy(alpha = 0.5f)
                )
                Spacer(Modifier.weight(1f))
                PillButton(icon = Icons.Default.GridView, label = "BROWSE", onClick = onBrowse, width = 60.dp)
            }
            audioState.currentSource != null -> {
                // REPEAT | EDIT | DELETE | BROWSE (4 buttons like iOS)
                PillButton(
                    icon = Icons.Default.Refresh, label = "REPEAT", onClick = onToggleRepeat,
                    tint = if (audioState.playbackRepeat) AudioGreen else PillButtonInactive
                )
                Spacer(Modifier.weight(1f))
                PillButton(icon = Icons.Default.Edit, label = "EDIT", onClick = onEdit)
                Spacer(Modifier.weight(1f))
                PillButton(icon = Icons.Default.Delete, label = "DELETE", onClick = onDelete, tint = AudioRed.copy(alpha = 0.8f))
                Spacer(Modifier.weight(1f))
                PillButton(icon = Icons.AutoMirrored.Filled.List, label = "BROWSE", onClick = onBrowse)
            }
            else -> {
                // REPEAT | BROWSE (TTS or empty state)
                PillButton(
                    icon = Icons.Default.Refresh, label = "REPEAT", onClick = onToggleRepeat,
                    tint = if (audioState.playbackRepeat) AudioGreen else PillButtonInactive
                )
                Spacer(Modifier.weight(1f))
                PillButton(icon = Icons.AutoMirrored.Filled.List, label = "BROWSE", onClick = onBrowse)
            }
        }
    }
}

@Composable
private fun PillButton(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    tint: Color = PillButtonInactive,
    width: androidx.compose.ui.unit.Dp = 50.dp
) {
    Column(
        modifier = Modifier.width(width).height(41.dp).clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(icon, label, tint = tint, modifier = Modifier.size(18.dp))
        Spacer(Modifier.height(3.dp))
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, color = tint)
    }
}

// ---------------------------------------------------------------------------
// Save Recording Dialog
// ---------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SaveRecordingSheet(
    recordingDuration: Double,
    recordingFilePath: String?,
    initialName: String = "",
    isEditing: Boolean = false,
    isSignedIn: Boolean = false,
    onSignIn: () -> Unit = {},
    onSave: (String?, Boolean) -> Unit,
    onDiscard: () -> Unit
) {
    var name by remember { mutableStateOf(initialName) }
    var share by remember { mutableStateOf(false) }
    var isNameError by remember { mutableStateOf(false) }

    // Preview playback state
    var previewPlayer by remember { mutableStateOf<android.media.MediaPlayer?>(null) }
    var isPreviewPlaying by remember { mutableStateOf(false) }
    var previewTime by remember { mutableStateOf(0.0) }

    // Clean up preview player on dismiss
    DisposableEffect(Unit) {
        onDispose {
            previewPlayer?.release()
        }
    }

    // Preview playback timer
    LaunchedEffect(isPreviewPlaying) {
        if (isPreviewPlaying) {
            while (isPreviewPlaying) {
                previewPlayer?.let { player ->
                    previewTime = player.currentPosition.toDouble() / 1000.0
                    if (!player.isPlaying) {
                        isPreviewPlaying = false
                    }
                }
                delay(100L)
            }
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDiscard,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp)
        ) {
            // Title
            Text(
                if (isEditing) "Edit Recording" else "Save Recording",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 20.dp)
            )

            // Name field
            Text(
                "Name",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 4.dp)
            )
            OutlinedTextField(
                value = name,
                onValueChange = { name = it; isNameError = false },
                placeholder = { Text("Recording name") },
                singleLine = true,
                isError = isNameError,
                modifier = Modifier.fillMaxWidth()
            )
            if (isNameError) {
                Text(
                    "Required",
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
            Spacer(Modifier.height(20.dp))

            // Sharing section — shown for both new and editing
            Text(
                "Sharing",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 4.dp)
            )
            if (isSignedIn) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { share = !share }
                        .padding(vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        painter = painterResource(
                            if (share) R.drawable.ic_globe else R.drawable.ic_lock
                        ),
                        contentDescription = null,
                        tint = if (share) iOSBlue else MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            if (share) "Public" else "Private",
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            if (share) "This recording will be shared with the community."
                            else "Only you can see this recording.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Switch(
                        checked = share,
                        onCheckedChange = { share = it }
                    )
                }
            } else {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onSignIn() }
                        .padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        painter = painterResource(R.drawable.ic_lock),
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(Modifier.width(12.dp))
                    Text(
                        "Sign in to share",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Text(
                    "Sign in to share recordings with the community.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 4.dp)
                )
            }
            Spacer(Modifier.height(20.dp))

            if (!isEditing) {
                // Preview playback
                if (recordingFilePath != null) {
                    Text(
                        "Preview",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant)
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Play/Pause button
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(iOSBlue)
                                .clickable {
                                    if (isPreviewPlaying) {
                                        previewPlayer?.pause()
                                        isPreviewPlaying = false
                                    } else {
                                        if (previewPlayer == null) {
                                            previewPlayer = android.media.MediaPlayer().apply {
                                                setDataSource(recordingFilePath)
                                                prepare()
                                                start()
                                            }
                                            isPreviewPlaying = true
                                        } else {
                                            previewPlayer?.start()
                                            isPreviewPlaying = true
                                        }
                                    }
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                if (isPreviewPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(22.dp)
                            )
                        }
                        Spacer(Modifier.width(12.dp))
                        // Duration
                        Text(
                            if (isPreviewPlaying) formatTime(previewTime) else formatTime(recordingDuration),
                            style = TextStyle(
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Medium,
                                fontFamily = FontFamily.Monospace
                            ),
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(Modifier.weight(1f))
                        Text(
                            formatTime(recordingDuration),
                            style = TextStyle(
                                fontSize = 14.sp,
                                fontFamily = FontFamily.Monospace
                            ),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Spacer(Modifier.height(28.dp))
                }
            }

            // Action buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Cancel button
                Button(
                    onClick = {
                        previewPlayer?.release()
                        previewPlayer = null
                        onDiscard()
                    },
                    modifier = Modifier.weight(1f).height(50.dp),
                    shape = CircleShape,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    Text("Cancel", color = MaterialTheme.colorScheme.onSurface)
                }
                // Save button
                Button(
                    onClick = {
                        if (name.isBlank()) {
                            isNameError = true
                            return@Button
                        }
                        previewPlayer?.release()
                        previewPlayer = null
                        onSave(name.ifBlank { null }, share)
                    },
                    modifier = Modifier.weight(1f).height(50.dp),
                    shape = CircleShape,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = iOSBlue
                    )
                ) {
                    Text("Save")
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Recording Picker Sheet (tabs + action buttons at bottom)
// ---------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RecordingPickerSheet(
    audioState: AudioPlaybackState,
    onDismiss: () -> Unit,
    onPlayLocal: (LocalRecording) -> Unit,
    onPlayCommunity: (Recording) -> Unit,
    onSaveCommunity: (Recording) -> Unit,
    onDeleteLocal: (LocalRecording) -> Unit,
    onReadAloud: () -> Unit,
    onRecordYourOwn: () -> Unit
) {
    var selectedTab by remember { mutableStateOf(0) }
    var recordingToDelete by remember { mutableStateOf<LocalRecording?>(null) }

    val screenHeight = LocalConfiguration.current.screenHeightDp.dp
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .height(screenHeight * 0.55f)
                .padding(bottom = 24.dp)
        ) {
            // Tab bar with underline (matching iOS)
            Row(modifier = Modifier.fillMaxWidth()) {
                listOf("Yours", "Community").forEachIndexed { index, label ->
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .clickable { selectedTab = index }
                            .padding(top = 2.dp, bottom = 0.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            label,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = if (selectedTab == index) FontWeight.Bold else FontWeight.Normal,
                            color = if (selectedTab == index) MaterialTheme.colorScheme.onSurface
                                    else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(vertical = 12.dp)
                        )
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(2.dp)
                                .background(
                                    if (selectedTab == index) iOSBlue
                                    else Color.Transparent
                                )
                        )
                    }
                }
            }
            HorizontalDivider()

            // Tab content — fills available space between tabs and buttons
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp)
            ) {
                if (selectedTab == 0) {
                    if (audioState.localRecordings.isEmpty()) {
                        EmptyRecordingState(
                            icon = Icons.Default.MusicNote,
                            title = "No recordings yet",
                            subtitle = "Record yourself reciting this quote to listen back and improve your memorization."
                        )
                    } else {
                        val currentLocalId = (audioState.currentSource as? PlaybackSource.Local)?.recording?.id
                        audioState.localRecordings.forEach { rec ->
                            RecordingRow(
                                title = rec.name ?: rec.uploaderName ?: "Your recording",
                                duration = formatTime(rec.durationSeconds),
                                isFavorite = rec.isFavorite,
                                language = rec.language,
                                createdAt = rec.createdAt,
                                isPlaying = rec.id == currentLocalId && audioState.isPlaying,
                                isSelected = rec.id == currentLocalId,
                                onClick = { onPlayLocal(rec) },
                                onDelete = { recordingToDelete = rec }
                            )
                        }
                    }
                } else {
                    if (audioState.isLoadingCommunity) {
                        Box(
                            modifier = Modifier.fillMaxWidth().height(160.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
                                Spacer(Modifier.height(8.dp))
                                Text("Loading...", color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    } else if (audioState.communityRecordings.isEmpty()) {
                        EmptyRecordingState(
                            icon = Icons.Default.MusicNote,
                            title = "No community recordings",
                            subtitle = "Be the first to share a recording of this quote!"
                        )
                    } else {
                        audioState.communityRecordings.forEach { rec ->
                            CommunityRecordingRow(
                                recording = rec,
                                isDownloading = audioState.downloadingId == rec.id,
                                onClick = { onPlayCommunity(rec) },
                                onSave = { onSaveCommunity(rec) }
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(8.dp))

            // Action buttons at bottom (matching iOS layout)
            Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                Button(
                    onClick = { onDismiss(); onReadAloud() },
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AudioOrange),
                    shape = CircleShape
                ) {
                    Text("Read Aloud")
                    Spacer(Modifier.width(8.dp))
                    Icon(Icons.Default.MusicNote, null, modifier = Modifier.size(18.dp))
                }
                Spacer(Modifier.height(8.dp))
                Button(
                    onClick = { onDismiss(); onRecordYourOwn() },
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AudioIndigo),
                    shape = CircleShape
                ) {
                    Text("Record your own")
                    Spacer(Modifier.width(8.dp))
                    Icon(Icons.Default.Mic, null, modifier = Modifier.size(18.dp))
                }
            }
        }
    }

    // Delete confirmation dialog
    recordingToDelete?.let { rec ->
        AlertDialog(
            onDismissRequest = { recordingToDelete = null },
            title = { Text("Delete Recording") },
            text = { Text("Are you sure you want to delete this recording? This cannot be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    onDeleteLocal(rec)
                    recordingToDelete = null
                }) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { recordingToDelete = null }) { Text("Cancel") }
            }
        )
    }
}

// ---------------------------------------------------------------------------
// Empty recording state with icon + text
// ---------------------------------------------------------------------------

@Composable
private fun EmptyRecordingState(
    icon: ImageVector,
    title: String,
    subtitle: String
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Spacer(Modifier.height(20.dp))
        Icon(
            icon, null,
            modifier = Modifier.size(40.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Text(
            subtitle,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

// ---------------------------------------------------------------------------
// Recording rows
// ---------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RecordingRow(
    title: String,
    duration: String,
    isFavorite: Boolean,
    language: String,
    createdAt: Long,
    isPlaying: Boolean = false,
    isSelected: Boolean = false,
    onClick: () -> Unit,
    onDelete: () -> Unit
) {
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                onDelete()
                false // snap back — let confirmation dialog handle actual delete
            } else false
        }
    )

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.error)
                    .padding(end = 20.dp),
                contentAlignment = Alignment.CenterEnd
            ) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = Color.White
                )
            }
        },
        enableDismissFromStartToEnd = false
    ) {
        Column(modifier = Modifier.background(MaterialTheme.colorScheme.surface)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onClick)
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (isFavorite) {
                    Text("❤️", modifier = Modifier.padding(end = 8.dp))
                }
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(
                            title,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (isSelected) iOSBlue else MaterialTheme.colorScheme.onSurface
                        )
                        if (language.isNotBlank()) {
                            Text(
                                language.uppercase(),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    Text(
                        formatRecordingDate(createdAt),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Text(
                    duration,
                    style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                if (isSelected && isPlaying) {
                    Spacer(Modifier.width(8.dp))
                    Icon(
                        painter = painterResource(R.drawable.ic_speaker_wave),
                        contentDescription = "Playing",
                        tint = iOSBlue,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
            HorizontalDivider(modifier = Modifier.padding(start = 16.dp))
        }
    }
}

@Composable
private fun CommunityRecordingRow(
    recording: Recording,
    isDownloading: Boolean,
    onClick: () -> Unit,
    onSave: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = !isDownloading, onClick = onClick)
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(recording.uploaderName, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
        }
        // Language badge
        if (recording.language.isNotBlank()) {
            LanguageBadge(recording.language)
            Spacer(Modifier.width(8.dp))
        }
        if (isDownloading) {
            CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
        } else {
            Text(
                formatTime(recording.durationSeconds ?: 0.0),
                style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
    HorizontalDivider(modifier = Modifier.padding(start = 16.dp))
}

// ---------------------------------------------------------------------------
// Language Badge (matching iOS languagePill)
// ---------------------------------------------------------------------------

private fun languageColor(code: String): Color = when (code.lowercase()) {
    "en" -> Color(0xFF2196F3)
    "es" -> Color(0xFFFFC107)
    "fr" -> Color(0xFFF44336)
    "it" -> Color(0xFF4CAF50)
    "de" -> Color(0xFFFF9800)
    "pt" -> Color(0xFF4CAF50)
    "ar" -> Color(0xFF4CAF50)
    else -> Color(0xFF7A71F0)
}

private fun languageTextColor(code: String): Color = when (code.lowercase()) {
    "es", "it", "de", "pt" -> Color.Black
    else -> Color.White
}

@Composable
private fun LanguageBadge(code: String) {
    val bg = languageColor(code)
    val fg = languageTextColor(code)
    Row(
        modifier = Modifier
            .background(bg, RoundedCornerShape(20.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Icon(
            painter = painterResource(id = R.drawable.ic_globe),
            contentDescription = null,
            tint = fg,
            modifier = Modifier.size(9.dp)
        )
        Text(
            code.uppercase(),
            fontSize = 10.sp,
            lineHeight = 10.sp,
            fontWeight = FontWeight.Bold,
            color = fg
        )
    }
}

@Composable
private fun GreyedLanguageBadge(code: String) {
    Row(
        modifier = Modifier
            .background(Color(0xFFBDBDBD), RoundedCornerShape(20.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Icon(
            painter = painterResource(id = R.drawable.ic_globe),
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(9.dp)
        )
        Text(
            code.uppercase(),
            fontSize = 10.sp,
            lineHeight = 10.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}

@Composable
private fun InteractiveLanguageBadge(
    code: String,
    primaryLanguageCode: String,
    availableLanguages: List<String>,
    activeLanguage: String?,
    onLanguageSwitch: (String?) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Box(modifier = Modifier.clickable { expanded = true }) {
            LanguageBadge(code = code)
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            // Primary language option
            val primarySelected = activeLanguage == null
            DropdownMenuItem(
                text = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (primarySelected) {
                            Icon(Icons.Default.Check, null, modifier = Modifier.size(16.dp), tint = languageColor(primaryLanguageCode))
                            Spacer(Modifier.width(8.dp))
                        }
                        Text(languageDisplayName(primaryLanguageCode))
                    }
                },
                onClick = {
                    onLanguageSwitch(null)
                    expanded = false
                }
            )
            // Translation options
            availableLanguages.forEach { lang ->
                val selected = activeLanguage == lang
                DropdownMenuItem(
                    text = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (selected) {
                                Icon(Icons.Default.Check, null, modifier = Modifier.size(16.dp), tint = languageColor(lang))
                                Spacer(Modifier.width(8.dp))
                            }
                            Text(languageDisplayName(lang))
                        }
                    },
                    onClick = {
                        onLanguageSwitch(lang)
                        expanded = false
                    }
                )
            }
        }
    }
}

private fun languageDisplayName(code: String): String {
    val locale = Locale(code)
    return locale.getDisplayLanguage(Locale.getDefault()).replaceFirstChar { it.uppercase() }.ifEmpty { code.uppercase() }
}

private fun formatTime(seconds: Double): String {
    val totalSec = seconds.toInt()
    val min = totalSec / 60
    val sec = totalSec % 60
    return "%d:%02d".format(min, sec)
}
