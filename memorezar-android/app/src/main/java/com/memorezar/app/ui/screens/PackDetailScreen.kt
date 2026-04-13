package com.memorezar.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.layout
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.memorezar.app.R
import com.memorezar.app.data.models.LanguageHelper
import com.memorezar.app.data.models.SuggestionPack
import com.memorezar.app.data.models.SuggestionQuote

private val IndigoColor = Color(0xFF7A71F0)
private val SerifQuoteFont = FontFamily(Font(R.font.noto_serif_bold))

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PackDetailScreen(
    pack: SuggestionPack,
    isAdded: Boolean,
    isPro: Boolean,
    bottomNavHeight: Dp = 0.dp,
    onAddToLibrary: (SuggestionPack) -> Unit,
    onShowPaywall: () -> Unit,
    onBack: () -> Unit
) {
    val lang = LanguageHelper.preferredLanguageCode
    var added by remember { mutableStateOf(isAdded) }
    val scrollState = rememberScrollState()

    val showTitleInBar by remember {
        derivedStateOf { scrollState.value > 400 }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(bottom = bottomNavHeight)
    ) {
        // Main layout: scrollable content + pinned button
        Column(modifier = Modifier.fillMaxSize()) {
            // Scrollable content
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(scrollState)
            ) {
                // Cover image header
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(260.dp)
                ) {
                    if (pack.coverURL != null) {
                        AsyncImage(
                            model = pack.coverURL,
                            contentDescription = pack.localizedName(lang),
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize()
                        )
                    } else {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(
                                    Brush.linearGradient(
                                        colors = listOf(
                                            IndigoColor.copy(alpha = 0.6f),
                                            Color(0xFF9C27B0).copy(alpha = 0.8f)
                                        )
                                    )
                                )
                        )
                    }

                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(
                                Brush.verticalGradient(
                                    colors = listOf(
                                        Color.Transparent,
                                        Color.Black.copy(alpha = 0.7f)
                                    ),
                                    startY = 130f
                                )
                            )
                    )

                    Column(
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(
                            text = pack.localizedName(lang),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            text = "${pack.quotes.size} quotes",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color.White.copy(alpha = 0.8f)
                        )
                    }
                }

                // Content below cover
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    Text(
                        text = pack.localizedDescription(lang),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    // Quote preview section (negative offsets inside eat ~110dp; trim via layout)
                    Column(modifier = Modifier.layout { measurable, constraints ->
                        val placeable = measurable.measure(constraints)
                        layout(placeable.width, (placeable.height - 110.dp.roundToPx()).coerceAtLeast(0)) {
                            placeable.placeRelative(0, 0)
                        }
                    }) {
                        // Opening quote mark
                        QuoteMarkView(
                            glyph = "\u201C",
                            alignEnd = false,
                            modifier = Modifier.fillMaxWidth()
                        )

                        // Preview snippets
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .offset(y = (-50).dp)
                                .padding(horizontal = 20.dp),
                            verticalArrangement = Arrangement.spacedBy(14.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            pack.quotes.take(3).forEach { quote ->
                                Text(
                                    text = snippetDisplay(quote, lang),
                                    style = MaterialTheme.typography.bodyLarge,
                                    fontStyle = FontStyle.Italic,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    textAlign = TextAlign.Center,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }
                        }

                        // Closing quote mark
                        QuoteMarkView(
                            glyph = "\u201D",
                            alignEnd = true,
                            modifier = Modifier.fillMaxWidth().offset(y = (-60).dp)
                        )
                    }
                }
            }

            // Add to Library button — pinned just above the bottom nav
            val canAccess = pack.isFree || isPro
            Button(
                onClick = {
                    if (!added) {
                        if (canAccess) {
                            onAddToLibrary(pack)
                            added = true
                        } else {
                            onShowPaywall()
                        }
                    }
                },
                enabled = !added,
                colors = ButtonDefaults.buttonColors(
                    containerColor = IndigoColor,
                    disabledContainerColor = IndigoColor.copy(alpha = 0.5f)
                ),
                shape = CircleShape,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .padding(top = 8.dp, bottom = 12.dp)
                    .height(50.dp)
            ) {
                if (added) {
                    Icon(
                        Icons.Default.Check,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        "Added to Library",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                } else {
                    Text(
                        stringResource(R.string.add_to_library),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(Modifier.width(8.dp))
                    Icon(
                        Icons.Default.Add,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp)
                    )
                    if (!pack.isFree && !isPro) {
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = "PRO",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            modifier = Modifier
                                .background(
                                    Color(0xFFFF9800),
                                    RoundedCornerShape(4.dp)
                                )
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }
            }
        }

        // Floating TopAppBar overlay
        TopAppBar(
            title = {
                if (showTitleInBar) {
                    Text(
                        text = pack.localizedName(lang),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = if (showTitleInBar) MaterialTheme.colorScheme.onSurface else Color.White
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = if (showTitleInBar)
                    MaterialTheme.colorScheme.surface.copy(alpha = 0.95f)
                else
                    Color.Transparent
            )
        )
    }
}

// ── Quote Mark Rendering ────────────────────────────────────────

/**
 * Renders a large decorative quote mark as plain Compose Text.
 */
@Composable
private fun QuoteMarkView(
    glyph: String,
    alignEnd: Boolean,
    modifier: Modifier = Modifier
) {
    Text(
        text = glyph,
        fontSize = 100.sp,
        fontFamily = SerifQuoteFont,
        color = IndigoColor.copy(alpha = 0.25f),
        textAlign = if (alignEnd) TextAlign.End else TextAlign.Start,
        modifier = modifier
    )
}

// ── Snippet Generation ──────────────────────────────────────────

private fun snippetDisplay(quote: SuggestionQuote, lang: String): String {
    val text = quote.localizedText(lang)
    val snippet = fallbackSnippet(text)
    return if (snippet == text) snippet else "$snippet..."
}

private val functionWords: Set<String> = setOf(
    "a", "an", "the",
    "is", "are", "was", "were", "can", "could", "will", "would",
    "shall", "should", "has", "have", "had", "may", "might",
    "which", "who", "whom", "whose", "where", "when", "than",
    "with", "in", "on", "of", "to", "for", "from", "by",
    "and", "but", "or", "nor", "through", "lest", "ere", "not",
    // Spanish
    "el", "la", "los", "las", "un", "una", "de", "del", "en",
    "es", "son", "ser", "y", "o", "que", "por", "para", "con",
    "no", "se", "su", "al",
    // French
    "le", "les", "des", "du", "et", "ou", "est", "sont",
    "dans", "sur", "par", "pour", "avec", "ne", "pas"
)

private fun fallbackSnippet(text: String): String {
    val words = text.split(" ").filter { it.isNotEmpty() }
    if (words.size <= 7) return text

    var bestCount: Int? = null
    var bestScore = Int.MAX_VALUE

    for (count in 4..minOf(7, words.size)) {
        val word = words[count - 1].lowercase()
            .trimEnd('.', ',', ';', ':', '!', '?', '"', '\'', '\u00A1', '\u00BF')
        if (word in functionWords) {
            val snippet = words.take(count).joinToString(" ")
            val charCount = snippet.length
            val score = when {
                charCount in 25..30 -> 0
                charCount < 25 -> 25 - charCount
                else -> charCount - 30
            }
            if (score < bestScore) {
                bestScore = score
                bestCount = count
            }
        }
    }

    if (bestCount != null) {
        return words.take(bestCount).joinToString(" ")
    }

    return words.take(5).joinToString(" ")
}
