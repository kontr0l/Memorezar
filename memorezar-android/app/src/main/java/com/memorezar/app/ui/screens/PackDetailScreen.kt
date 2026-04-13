package com.memorezar.app.ui.screens

import android.graphics.Typeface
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
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

    // Paint for Canvas-drawn quote marks (bypasses Compose text clipping)
    val quoteColor = IndigoColor.copy(alpha = 0.25f)
    val density = LocalDensity.current
    val quoteFontSizePx = with(density) { 80.sp.toPx() }
    val quotePaint = remember {
        android.graphics.Paint().apply {
            textSize = quoteFontSizePx
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
            color = quoteColor.toArgb()
            isAntiAlias = true
        }
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

                    // Quote preview section
                    Column {
                        // Opening quote mark — Canvas to avoid Compose text clipping
                        Canvas(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(60.dp)
                        ) {
                            val text = "\u201C"
                            val bounds = android.graphics.Rect()
                            quotePaint.getTextBounds(text, 0, text.length, bounds)
                            val y = (size.height + bounds.height()) / 2f
                            drawIntoCanvas { canvas ->
                                canvas.nativeCanvas.drawText(text, 0f, y, quotePaint)
                            }
                        }

                        // Preview snippets
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
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

                        // Closing quote mark — Canvas
                        Canvas(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(60.dp)
                        ) {
                            val text = "\u201D"
                            val bounds = android.graphics.Rect()
                            quotePaint.getTextBounds(text, 0, text.length, bounds)
                            val y = (size.height + bounds.height()) / 2f
                            val x = size.width - bounds.width() - bounds.left
                            drawIntoCanvas { canvas ->
                                canvas.nativeCanvas.drawText(text, x, y, quotePaint)
                            }
                        }
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
