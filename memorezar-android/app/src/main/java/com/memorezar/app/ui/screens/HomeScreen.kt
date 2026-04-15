package com.memorezar.app.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil3.compose.AsyncImage
import com.memorezar.app.R
import com.memorezar.app.data.models.LanguageHelper
import com.memorezar.app.data.models.MasteryLevel
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.models.SuggestionPack
import com.memorezar.app.ui.components.BrainCharacter
import com.memorezar.app.ui.components.BrainCharacterView
import com.memorezar.app.ui.components.ActionTip
import com.memorezar.app.ui.components.MasteryBadge
import com.memorezar.app.data.models.TipDefinition
import com.memorezar.app.data.services.AuthService
import com.memorezar.app.data.services.SupportReason
import com.memorezar.app.data.services.SupportTicketService
import com.memorezar.app.data.storage.TutorialStore
import com.memorezar.app.ui.viewmodels.HomeViewModel

private val IndigoColor = Color(0xFF7A71F0)
private val BorderColor = Color(0xFF777777)
private val CardBg @Composable get() = MaterialTheme.colorScheme.surfaceVariant

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onNavigateToRecitation: (String) -> Unit,
    onNavigateToQuoteInput: () -> Unit,
    onNavigateToStreakDetail: () -> Unit,
    onNavigateToAccuracyDetail: () -> Unit,
    onNavigateToMasteredQuotes: () -> Unit = {},
    onNavigateToPackDetail: (SuggestionPack) -> Unit = {},
    onNavigateToPackSearch: (List<SuggestionPack>) -> Unit = {},
    tutorialStore: TutorialStore? = null,
    authService: AuthService? = null,
    supportTicketService: SupportTicketService? = null,
    modifier: Modifier = Modifier,
    viewModel: HomeViewModel = hiltViewModel()
) {
    var showPackRequest by remember { mutableStateOf(false) }
    val continuePracticing by viewModel.continuePracticingQuotes.collectAsState()
    val availablePacks by viewModel.availablePacks.collectAsState()
    val quotes by viewModel.quoteStore.quotes.collectAsState()
    val completedTips by (tutorialStore?.completedTips ?: kotlinx.coroutines.flow.MutableStateFlow(emptySet<String>())).collectAsState()
    fun shouldShowTip(tip: TipDefinition): Boolean {
        if (tutorialStore == null) return false
        if (tip.id in completedTips) return false
        val required = tip.requiredTipId
        if (required != null && required !in completedTips) return false
        return true
    }
    val heroCharacter = remember { BrainCharacter.randomHero() }

    // Track when the home screen was entered so we only mark an ActionTip
    // as "completed" if the user tapped AFTER the tip had time to actually
    // become visible (matches iOS: only completes if tip was visible at tap).
    val screenEnterTime = remember { System.currentTimeMillis() }
    fun isTipCurrentlyVisible(tip: TipDefinition): Boolean =
        shouldShowTip(tip) && (System.currentTimeMillis() - screenEnterTime) >= 600L

    // Non-saveable scroll state — tab switching disposes this composable so
    // coming back to Home resets scroll to top (matches iOS).
    val rootScrollState = remember { ScrollState(0) }
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rootScrollState)
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Spacer(Modifier.height(WindowInsets.statusBars.asPaddingValues().calculateTopPadding()))

        // Hero Section — logo + brain character
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Image(
                painter = painterResource(R.drawable.memorezar_logo),
                contentDescription = stringResource(R.string.memorezar_logo),
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .height(40.dp),
                contentScale = ContentScale.Fit
            )
            BrainCharacterView(character = heroCharacter, size = 180.dp)
        }

        // Continue Practicing / Get Started
        if (continuePracticing.isNotEmpty()) {
          Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            // Rules (mirrors iOS):
            //  - 1 quote        → card + add card, full width (no scroll)
            //  - 2 quotes       → cards + add card, all inside one horizontal scroll
            //  - 3+ quotes      → only cards in horizontal scroll; add button moves to
            //                     the section header (top-right trailing)
            val showTrailingAdd = continuePracticing.size > 2
            SectionHeaderWithIcon(
                title = stringResource(R.string.continue_practicing),
                icon = "play",
                color = Color(0xFF2196F3),
                trailing = if (showTrailingAdd) {
                    {
                        Text(
                            text = stringResource(R.string.add_quote),
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color(0xFF2196F3),
                            modifier = Modifier.clickable {
                                tutorialStore?.completeTip(TipDefinition.addOwnQuote.id)
                                onNavigateToQuoteInput()
                            }
                        )
                    }
                } else null
            )

            when {
                continuePracticing.size == 1 -> {
                    // 1 quote → card (flexible) + add card, full width, no scroll
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(modifier = Modifier.weight(1f)) {
                            ContinueQuoteCard(
                                quote = continuePracticing[0],
                                flexible = true,
                                onClick = { onNavigateToRecitation(continuePracticing[0].id) }
                            )
                        }
                        ActionTip(
                            text = stringResource(TipDefinition.addOwnQuote.contentRes),
                            visible = shouldShowTip(TipDefinition.addOwnQuote),
                            wiggle = true,
                            horizontalAlign = com.memorezar.app.ui.components.TipHorizontalAlign.Center
                        ) {
                            AddQuoteCard(onClick = {
                                tutorialStore?.completeTip(TipDefinition.addOwnQuote.id)
                                onNavigateToQuoteInput()
                            })
                        }
                    }
                }
                continuePracticing.size == 2 -> {
                    // 2 quotes → all 3 tiles inside a single horizontal scroll
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        continuePracticing.forEach { quote ->
                            ContinueQuoteCard(
                                quote = quote,
                                flexible = false,
                                onClick = { onNavigateToRecitation(quote.id) }
                            )
                        }
                        ActionTip(
                            text = stringResource(TipDefinition.addOwnQuote.contentRes),
                            visible = shouldShowTip(TipDefinition.addOwnQuote),
                            wiggle = true,
                            horizontalAlign = com.memorezar.app.ui.components.TipHorizontalAlign.Center
                        ) {
                            AddQuoteCard(onClick = {
                                tutorialStore?.completeTip(TipDefinition.addOwnQuote.id)
                                onNavigateToQuoteInput()
                            })
                        }
                    }
                }
                else -> {
                    // 3+ quotes → cards only, horizontal scroll; add button lives in header
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        continuePracticing.forEach { quote ->
                            ContinueQuoteCard(
                                quote = quote,
                                flexible = false,
                                onClick = { onNavigateToRecitation(quote.id) }
                            )
                        }
                    }
                }
            }
          }
        } else {
          Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            SectionHeaderWithIcon(
                title = stringResource(R.string.get_started),
                icon = "play",
                color = Color(0xFF2196F3)
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Info tile — flexible width (wider), top-left aligned content
                Card(
                    modifier = Modifier
                        .weight(1.2f)
                        .height(100.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = CardBg),
                    border = BorderStroke(2.dp, BorderColor)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(12.dp),
                        horizontalAlignment = Alignment.Start,
                        verticalArrangement = Arrangement.Top
                    ) {
                        Text(
                            stringResource(R.string.no_quotes_yet_home),
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            stringResource(R.string.add_quote_get_started),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 3
                        )
                    }
                }
                // Add quote tile — narrower, top-left aligned, icon fills remaining space
                ActionTip(
                    text = stringResource(TipDefinition.addOwnQuote.contentRes),
                    visible = shouldShowTip(TipDefinition.addOwnQuote),
                    wiggle = true,
                    modifier = Modifier.weight(1f)
                ) {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(100.dp)
                            .clickable {
                                if (isTipCurrentlyVisible(TipDefinition.addOwnQuote)) {
                                    tutorialStore?.completeTip(TipDefinition.addOwnQuote.id)
                                }
                                onNavigateToQuoteInput()
                            },
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = CardBg),
                        border = BorderStroke(2.dp, BorderColor)
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(12.dp),
                            horizontalAlignment = Alignment.Start
                        ) {
                            Text(
                                stringResource(R.string.add_your_own),
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                maxLines = 1
                            )
                            Spacer(Modifier.height(8.dp))
                            // Icon fills remaining vertical space, matching iOS's
                            // .frame(height: 36).frame(maxWidth: .infinity, maxHeight: .infinity)
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .weight(1f),
                                contentAlignment = Alignment.Center
                            ) {
                                Image(
                                    painter = painterResource(R.drawable.icon_addquote),
                                    contentDescription = stringResource(R.string.add_quote),
                                    contentScale = ContentScale.Fit,
                                    modifier = Modifier.height(36.dp)
                                )
                            }
                        }
                    }
                }
            }
          }
        }

        // Stats Section
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        SectionHeaderWithIcon(
            title = stringResource(R.string.your_progress),
            icon = "chart",
            color = Color(0xFF34C759)
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            val mastered = quotes.count { it.masteryLevel == MasteryLevel.MASTERED }
            val streak = viewModel.quoteStore.dailyStreak
            val avg = viewModel.quoteStore.averageAccuracy

            StatCard(
                iconText = "\uD83D\uDC51",
                value = "$mastered",
                label = stringResource(R.string.mastered),
                color = Color(0xFFFFC107),
                modifier = Modifier.weight(1f),
                onClick = onNavigateToMasteredQuotes
            )
            StatCard(
                iconText = "\uD83D\uDD25",
                value = "${streak}d",
                label = stringResource(R.string.streak),
                color = Color(0xFFFF5722),
                modifier = Modifier.weight(1f),
                onClick = onNavigateToStreakDetail
            )
            StatCard(
                iconText = "\uD83C\uDFAF",
                value = "${(avg * 100).toInt()}%",
                label = stringResource(R.string.accuracy),
                color = Color(0xFF34C759),
                modifier = Modifier.weight(1f),
                onClick = onNavigateToAccuracyDetail
            )
        }
        } // Stats Column

        // Browse Quote Packs
        if (availablePacks.isNotEmpty()) {
          Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            ActionTip(
                text = stringResource(TipDefinition.browsePacks.contentRes),
                visible = shouldShowTip(TipDefinition.browsePacks),
                delayMs = 1000L
            ) {
                SectionHeaderWithIcon(
                    title = stringResource(R.string.browse_quote_packs),
                    icon = "search",
                    color = IndigoColor,
                    trailing = {
                        Text(
                            text = stringResource(R.string.see_all),
                            style = MaterialTheme.typography.bodyMedium,
                            color = IndigoColor,
                            modifier = Modifier.clickable {
                                tutorialStore?.completeTip(TipDefinition.browsePacks.id)
                                onNavigateToPackSearch(availablePacks)
                            }
                        )
                    }
                )
            }
            val displayPacks = availablePacks.take(5) // 5 packs + 1 request card = 6 slots
            val totalItems = displayPacks.size + 1 // +1 for request card
            val rows = (totalItems + 1) / 2 // ceil division for 2 columns
            val gridHeight = (rows * 200 + (rows - 1).coerceAtLeast(0) * 12).dp
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                modifier = Modifier.height(gridHeight),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                userScrollEnabled = false
            ) {
                items(displayPacks, key = { it.id }) { pack ->
                    PackCard(pack = pack, onClick = {
                        tutorialStore?.completeTip(TipDefinition.browsePacks.id)
                        onNavigateToPackDetail(pack)
                    })
                }
                item(key = "pack_request") {
                    PackRequestCard(onClick = { showPackRequest = true })
                }
            }
          }
        }

        Spacer(Modifier.height(16.dp))
    }

    // Quote Pack Request bottom sheet
    if (showPackRequest && authService != null && supportTicketService != null) {
        ModalBottomSheet(
            onDismissRequest = { showPackRequest = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            dragHandle = null
        ) {
            ContactSupportScreen(
                authService = authService,
                supportTicketService = supportTicketService,
                onDismiss = { showPackRequest = false },
                initialReason = SupportReason.QUOTE_PACK_REQUEST
            )
        }
    }
}

@Composable
private fun SectionHeaderWithIcon(
    title: String,
    icon: String,
    color: Color,
    trailing: (@Composable () -> Unit)? = null
) {
    Box(
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = when (icon) {
                    "search" -> Icons.Default.Search
                    else -> Icons.Default.Add // placeholder
                },
                contentDescription = null,
                tint = if (icon == "play" || icon == "chart") Color.Transparent else color,
                modifier = Modifier.size(if (icon == "play" || icon == "chart") 0.dp else 20.dp)
            )
            // Use emoji icons for play and chart to avoid needing extra drawables
            if (icon == "play") {
                Text("\u25B6", color = color, modifier = Modifier.padding(end = 6.dp))
            } else if (icon == "chart") {
                Text("\uD83D\uDCCA", modifier = Modifier.padding(end = 6.dp))
            } else {
                Spacer(Modifier.width(6.dp))
            }
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = color
            )
        }
        if (trailing != null) {
            Box(modifier = Modifier.align(Alignment.CenterEnd)) {
                trailing()
            }
        }
    }
}

@Composable
private fun AddQuoteIconButton(onClick: () -> Unit) {
    Icon(
        painter = painterResource(R.drawable.icon_addquote),
        contentDescription = stringResource(R.string.add_quote),
        tint = Color.Unspecified,
        modifier = Modifier
            .size(36.dp)
            .clickable(onClick = onClick)
    )
}

@Composable
private fun ContinueQuoteCard(quote: Quote, flexible: Boolean = false, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .then(if (flexible) Modifier.fillMaxWidth() else Modifier.width(160.dp))
            .height(100.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg),
        border = BorderStroke(2.dp, BorderColor)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp)
        ) {
            Text(
                text = quote.displayTitle,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = continuationPreview(quote),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(Modifier.weight(1f))
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                MasteryBadge(level = quote.masteryLevel)
                Spacer(Modifier.weight(1f))
                Text(
                    text = formatLastPracticed(quote.lastPracticedAt, quote.wordCount),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun AddQuoteCard(onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .width(160.dp)
            .height(100.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg),
        border = BorderStroke(2.dp, BorderColor)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp)
        ) {
            Text(
                stringResource(R.string.add_your_own),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    painter = painterResource(R.drawable.icon_addquote),
                    contentDescription = stringResource(R.string.add_quote),
                    tint = Color.Unspecified,
                    modifier = Modifier.size(48.dp)
                )
            }
        }
    }
}

@Composable
private fun StatCard(
    iconText: String,
    value: String,
    label: String,
    color: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Card(
        modifier = modifier
            .defaultMinSize(minHeight = 100.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg),
        border = BorderStroke(2.dp, BorderColor)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(iconText, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(4.dp))
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(
                label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
fun PackCard(pack: SuggestionPack, onClick: () -> Unit = {}) {
    val lang = LanguageHelper.preferredLanguageCode
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(2.dp, BorderColor)
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            // Cover image or gradient fallback
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

            // Dark gradient overlay at bottom
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.7f)),
                            startY = 100f
                        )
                    )
            )

            // Pack name and quote count
            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(12.dp)
            ) {
                Text(
                    text = pack.localizedName(lang),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = stringResource(R.string.quotes_count_format, pack.quotes.size),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }
        }
    }
}

@Composable
fun PackRequestCard(onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(2.dp, BorderColor)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            IndigoColor.copy(alpha = 0.15f),
                            IndigoColor.copy(alpha = 0.05f)
                        )
                    )
                ),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier.padding(horizontal = 12.dp)
            ) {
                BrainCharacterView(character = BrainCharacter.WORK1, size = 96.dp)
                Spacer(Modifier.height(8.dp))
                Text(
                    text = stringResource(R.string.pack_request_title),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = IndigoColor,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
            }
        }
    }
}

private fun continuationPreview(quote: Quote): String {
    if (quote.titleMatchesPreview) {
        val titleWordCount = quote.displayTitle.trim().split("\\s+".toRegex()).filter { it.isNotEmpty() }.size
        val allWords = quote.displayText.trim().split("\\s+".toRegex()).filter { it.isNotEmpty() }
        val remaining = allWords.drop(titleWordCount).take(10)
        if (remaining.isEmpty()) return ""
        return remaining.joinToString(" ") + "..."
    }
    return quote.preview
}

private fun formatLastPracticed(lastPracticedAt: Long?, wordCount: Int): String {
    if (lastPracticedAt == null) return "${wordCount}w"
    val now = System.currentTimeMillis()
    val diff = now - lastPracticedAt
    val days = diff / (24 * 3600 * 1000)
    return when {
        days < 1 -> "Today"
        days < 2 -> "1d ago"
        days < 7 -> "${days}d ago"
        days < 30 -> "${days / 7}w ago"
        else -> "${days / 30}mo ago"
    }
}
