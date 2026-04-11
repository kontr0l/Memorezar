package com.memorezar.app.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Keyboard
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.memorezar.app.data.models.MemorizationMode
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.services.AuthService
import com.memorezar.app.data.storage.QuoteStore
import com.memorezar.app.ui.components.BrainCharacter
import com.memorezar.app.ui.components.BrainCharacterView
import kotlinx.coroutines.delay

private val BlueColor = Color(0xFF2196F3)
private val IndigoColor = Color(0xFF7A71F0)

private val tutorialWords = listOf("Happy", "birthday", "to", "you")

private val tutorialQuote = Quote(
    id = "tutorial-onboarding",
    title = "Tutorial",
    text = "Happy birthday to you",
    revealLevel = 2 // 50% reveal
)

@Composable
fun OnboardingFlow(
    quoteStore: QuoteStore? = null,
    authService: AuthService? = null,
    onComplete: (MemorizationMode, Boolean) -> Unit
) {
    var step by remember { mutableIntStateOf(0) }
    var selectedMode by remember { mutableStateOf(MemorizationMode.VOICE) }
    var firstLetterEnabled by remember { mutableStateOf(false) }

    AnimatedContent(
        targetState = step,
        transitionSpec = { fadeIn(tween(300)) togetherWith fadeOut(tween(300)) },
        label = "onboarding"
    ) { currentStep ->
        when (currentStep) {
            0 -> ModeChoiceStep(
                onSelectMode = { mode ->
                    selectedMode = mode
                    step = 1
                }
            )
            1 -> FirstLetterChoiceStep(
                mode = selectedMode,
                onBack = { step = 0 },
                onSelect = { useFirstLetter ->
                    firstLetterEnabled = useFirstLetter
                    step = 2
                }
            )
            2 -> {
                if (quoteStore != null && authService != null) {
                    RecitationScreen(
                        quoteId = tutorialQuote.id,
                        quoteStore = quoteStore,
                        authService = authService,
                        onShowAuthSheet = {},
                        tutorialQuote = tutorialQuote,
                        tutorialMode = selectedMode,
                        tutorialFirstLetter = firstLetterEnabled,
                        onBack = {
                            onComplete(selectedMode, firstLetterEnabled)
                        }
                    )
                } else {
                    LaunchedEffect(Unit) {
                        onComplete(selectedMode, firstLetterEnabled)
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Step 1: Voice or Typing — T-split layout
// ---------------------------------------------------------------------------

@Composable
private fun ModeChoiceStep(onSelectMode: (MemorizationMode) -> Unit) {
    Column(modifier = Modifier.fillMaxSize()) {
        // Top section — centered content
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(0.55f)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            BrainCharacterView(character = BrainCharacter.PRAY1, size = 130.dp)
            Spacer(Modifier.height(16.dp))
            Text(
                text = "How do you want to practice?",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Text(
                text = "You can always change this later.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
        }

        // T-split bottom
        HorizontalDivider(thickness = 0.5.dp, color = MaterialTheme.colorScheme.outlineVariant)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .weight(0.45f)
        ) {
            // Voice
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .background(BlueColor.copy(alpha = 0.06f))
                    .clickable { onSelectMode(MemorizationMode.VOICE) },
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Default.Mic,
                        contentDescription = "Voice",
                        modifier = Modifier.size(34.dp),
                        tint = BlueColor
                    )
                    Spacer(Modifier.height(10.dp))
                    Text("Voice", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                }
            }

            VerticalDivider(thickness = 0.5.dp, color = MaterialTheme.colorScheme.outlineVariant)

            // Typing
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .background(IndigoColor.copy(alpha = 0.06f))
                    .clickable { onSelectMode(MemorizationMode.TYPING) },
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Default.Keyboard,
                        contentDescription = "Typing",
                        modifier = Modifier.size(34.dp),
                        tint = IndigoColor
                    )
                    Spacer(Modifier.height(10.dp))
                    Text("Typing", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Step 2: First Letter Choice — T-split with previews and colored buttons
// ---------------------------------------------------------------------------

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FirstLetterChoiceStep(
    mode: MemorizationMode,
    onBack: () -> Unit,
    onSelect: (Boolean) -> Unit
) {
    val isVoice = mode == MemorizationMode.VOICE

    // Animated word fade for the top preview (typing mode)
    var wordHidden by remember { mutableStateOf(false) }
    val wordAlpha = remember { Animatable(1f) }

    LaunchedEffect(Unit) {
        wordHidden = false
        wordAlpha.snapTo(1f)
        delay(800L)
        wordHidden = true
        wordAlpha.animateTo(0f, tween(1000))
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // Top section — same 0.55f + Arrangement.Center as screen 1
        // Extra ~26dp spacer before character compensates for the extra content
        // (Let's try + words) so the character lands at the same Y as screen 1
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(0.55f)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Invisible spacer to offset extra content below title
            Spacer(Modifier.height(26.dp))
            BrainCharacterView(character = BrainCharacter.PRAY2, size = 130.dp)
            Spacer(Modifier.height(16.dp))

            Text(
                text = if (isVoice) "How should we hide the words?" else "How much do you want to type?",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(6.dp))

            // "Let's try" + tutorial phrase
            if (isVoice) {
                Text(
                    text = "Let's try",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "\"Happy birthday to you\"",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    fontStyle = FontStyle.Italic,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else {
                Text(
                    text = "Let's try",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                // Animated word fade: full words → hidden first word
                Box {
                    Row(
                        modifier = Modifier.alpha(wordAlpha.value),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        tutorialWords.forEach { word ->
                            Text(
                                text = word,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                fontStyle = FontStyle.Italic,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    Row(
                        modifier = Modifier.alpha(1f - wordAlpha.value),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        HiddenWordBox(word = tutorialWords[0], fontSize = 14)
                        tutorialWords.drop(1).forEach { word ->
                            Text(
                                text = word,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                fontStyle = FontStyle.Italic,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }

        // T-split bottom + Back row — all inside 0.45f so divider lands at same Y as screen 1
        HorizontalDivider(thickness = 0.5.dp, color = MaterialTheme.colorScheme.outlineVariant)

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(0.45f)
        ) {
            Row(modifier = Modifier.weight(1f)) {
                // Left: Normal
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .background(BlueColor.copy(alpha = 0.06f))
                        .clickable { onSelect(false) },
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Spacer(Modifier.weight(1f))
                    if (isVoice) {
                        VoiceWordPreview(
                            words = listOf(
                                WordPreviewItem(tutorialWords[0], WordPreviewMode.HIDDEN),
                                WordPreviewItem(tutorialWords[1], WordPreviewMode.FULL),
                                WordPreviewItem(tutorialWords[2], WordPreviewMode.HIDDEN),
                                WordPreviewItem(tutorialWords[3], WordPreviewMode.FULL)
                            )
                        )
                    } else {
                        TypingPreview(word = tutorialWords[0], fullWord = true)
                    }
                    Spacer(Modifier.weight(1f))
                    Button(
                        onClick = { onSelect(false) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp)
                            .padding(bottom = 16.dp)
                            .height(50.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = BlueColor)
                    ) {
                        Text("Normal", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    }
                }

                VerticalDivider(thickness = 0.5.dp, color = MaterialTheme.colorScheme.outlineVariant)

                // Right: First Letter
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .background(IndigoColor.copy(alpha = 0.06f))
                        .clickable { onSelect(true) },
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Spacer(Modifier.weight(1f))
                    if (isVoice) {
                        VoiceWordPreview(
                            words = tutorialWords.map {
                                WordPreviewItem(it, WordPreviewMode.FIRST_LETTER)
                            }
                        )
                    } else {
                        TypingPreview(word = tutorialWords[0], fullWord = false)
                    }
                    Spacer(Modifier.weight(1f))
                    Button(
                        onClick = { onSelect(true) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp)
                            .padding(bottom = 16.dp)
                            .height(50.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = IndigoColor)
                    ) {
                        Text("First Letter", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    }
                }
            }

            // Back row — inside the 0.45f section so it doesn't shift the divider
            HorizontalDivider(thickness = 0.5.dp, color = MaterialTheme.colorScheme.outlineVariant)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onBack() }
                    .padding(vertical = 14.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "Back",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Word preview types
// ---------------------------------------------------------------------------

private enum class WordPreviewMode { FULL, HIDDEN, FIRST_LETTER }
private data class WordPreviewItem(val word: String, val mode: WordPreviewMode)

/**
 * Hidden word rendered as a grey rounded rectangle (matching iOS).
 */
@Composable
private fun HiddenWordBox(word: String, fontSize: Int = 20) {
    val charWidth = (fontSize * 0.6f).dp
    Box(
        modifier = Modifier
            .width(charWidth * word.length + 8.dp)
            .height((fontSize + 8).dp)
            .clip(RoundedCornerShape(4.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = 0.15f), RoundedCornerShape(4.dp))
    )
}

/**
 * Voice mode word preview — flow layout with hidden boxes and visible/first-letter words.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun VoiceWordPreview(words: List<WordPreviewItem>) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier.padding(horizontal = 20.dp)
    ) {
        words.forEach { item ->
            when (item.mode) {
                WordPreviewMode.FULL -> {
                    Text(
                        text = item.word,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
                WordPreviewMode.HIDDEN -> {
                    HiddenWordBox(word = item.word)
                }
                WordPreviewMode.FIRST_LETTER -> {
                    Text(
                        text = "${item.word.first()}${"_".repeat(item.word.length - 1)}",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

/**
 * Typing mode preview — grey letters above dashes.
 */
@Composable
private fun TypingPreview(word: String, fullWord: Boolean) {
    val letters = if (fullWord) word.toList() else listOf(word.first())
    val description = if (fullWord) "Type full\nmissing word" else "Type only\nfirst letter"

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = description,
            style = MaterialTheme.typography.bodySmall,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            lineHeight = 16.sp
        )
        Spacer(Modifier.height(12.dp))
        // Grey letters row
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            letters.forEach { ch ->
                Text(
                    text = ch.uppercase(),
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                    modifier = Modifier.width(20.dp),
                    textAlign = TextAlign.Center
                )
            }
        }
        Spacer(Modifier.height(4.dp))
        // Dashes row
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            letters.forEach { _ ->
                Box(
                    modifier = Modifier
                        .width(20.dp)
                        .height(2.dp)
                        .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f))
                )
            }
        }
    }
}
