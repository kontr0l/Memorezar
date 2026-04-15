package com.memorezar.app.ui.screens

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Intent
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.widget.Toast
import java.util.Locale
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.ui.layout.ContentScale
import coil3.compose.AsyncImage
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.AddPhotoAlternate
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.memorezar.app.R
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.models.QuoteCategory
import com.memorezar.app.data.services.UnsplashImageInfo
import com.memorezar.app.ui.components.BrainCharacter
import com.memorezar.app.ui.components.BrainCharacterView
import com.memorezar.app.ui.components.ActionTip
import com.memorezar.app.ui.components.MasteryBadge
import com.memorezar.app.data.models.TipDefinition
import com.memorezar.app.data.storage.TutorialStore
import com.memorezar.app.ui.viewmodels.LibraryViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
// FileProvider no longer needed for PDF
import java.io.File
import java.util.UUID

private val gradientPalettes = listOf(
    listOf(Color(0xFF7A71F0), Color(0xFF3949AB)),
    listOf(Color(0xFF26A69A), Color(0xFF00897B)),
    listOf(Color(0xFFEF5350), Color(0xFFE53935)),
    listOf(Color(0xFFAB47BC), Color(0xFF8E24AA)),
    listOf(Color(0xFF42A5F5), Color(0xFF1E88E5)),
    listOf(Color(0xFFFF7043), Color(0xFFE64A19)),
    listOf(Color(0xFF66BB6A), Color(0xFF43A047)),
    listOf(Color(0xFFEC407A), Color(0xFFD81B60)),
    listOf(Color(0xFF7A71F0), Color(0xFF283593)),
    listOf(Color(0xFF78909C), Color(0xFF546E7A)),
    listOf(Color(0xFFFFA726), Color(0xFFF57C00)),
    listOf(Color(0xFF8D6E63), Color(0xFF6D4C41))
)

private val BorderColor = Color(0xFF777777)
private val IndigoColor = Color(0xFF7A71F0)

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun QuoteLibraryScreen(
    onNavigateToRecitation: (String) -> Unit,
    onNavigateToQuoteInput: () -> Unit,
    onNavigateToCategory: (String) -> Unit,
    onNavigateToQuoteInputForCategory: (String) -> Unit = {},
    onEditQuote: (Quote) -> Unit = {},
    tutorialStore: TutorialStore? = null,
    modifier: Modifier = Modifier,
    viewModel: LibraryViewModel = hiltViewModel()
) {
    val categories by viewModel.categories.collectAsState()
    val quotes by viewModel.quotes.collectAsState()
    var categoryToDelete by remember { mutableStateOf<QuoteCategory?>(null) }
    var showNewCategorySheet by remember { mutableStateOf(false) }

    // Auto-navigate into a newly added pack category
    val pendingNav by viewModel.quoteStore.pendingCategoryNavigation.collectAsState()
    LaunchedEffect(pendingNav) {
        pendingNav?.let { category ->
            onNavigateToCategory(category.id)
            viewModel.quoteStore.pendingCategoryNavigation.value = null
        }
    }

    run {
        // Non-saveable scroll state — tab switching disposes this composable so
        // coming back to Library resets scroll to top (matches iOS).
        val rootScrollState = remember { ScrollState(0) }
        Column(
            modifier = modifier
                .fillMaxSize()
                .verticalScroll(rootScrollState)
                .padding(horizontal = 16.dp)
        ) {
            Spacer(Modifier.height(WindowInsets.statusBars.asPaddingValues().calculateTopPadding()))

            // Header: "Library" + AddQuote icon
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.library),
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                IconButton(onClick = onNavigateToQuoteInput) {
                    Icon(
                        painter = painterResource(R.drawable.icon_addquote),
                        contentDescription = stringResource(R.string.add_quote),
                        tint = Color.Unspecified,
                        modifier = Modifier.size(32.dp)
                    )
                }
            }

            // Category grid
            val totalItems = categories.size + 1 // +1 for add-folder tile
            val rows = (totalItems + 1) / 2
            val gridHeight = rows * 200 + (rows - 1) * 12 // 200dp per row + 12dp spacing
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                modifier = Modifier.height(gridHeight.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                userScrollEnabled = false
            ) {
                items(categories, key = { it.id }) { category ->
                    val quoteCount = quotes.count { it.categoryId == category.id }
                    var showContextMenu by remember { mutableStateOf(false) }

                    Box {
                        CategoryCard(
                            category = category,
                            quoteCount = quoteCount,
                            onClick = { onNavigateToCategory(category.id) },
                            onLongClick = {
                                if (categories.size > 1) showContextMenu = true
                            }
                        )

                        DropdownMenu(
                            expanded = showContextMenu,
                            onDismissRequest = { showContextMenu = false },
                            offset = DpOffset(0.dp, 0.dp)
                        ) {
                            DropdownMenuItem(
                                text = {
                                    Text(
                                        if (category.sourcePackId != null) stringResource(R.string.remove_pack) else stringResource(R.string.delete_category),
                                        color = MaterialTheme.colorScheme.error
                                    )
                                },
                                leadingIcon = {
                                    Icon(
                                        painter = painterResource(R.drawable.icon_trash),
                                        contentDescription = null,
                                        tint = Color.Unspecified,
                                        modifier = Modifier.size(20.dp)
                                    )
                                },
                                onClick = {
                                    showContextMenu = false
                                    categoryToDelete = category
                                }
                            )
                        }
                    }
                }

                // Add new category tile — no background, just icon centered
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp)
                            .clickable {
                                tutorialStore?.completeTip(TipDefinition.addCategory.id)
                                showNewCategorySheet = true
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        ActionTip(
                            text = stringResource(TipDefinition.addCategory.contentRes),
                            visible = tutorialStore?.shouldShowTip(TipDefinition.addCategory) == true,
                            wiggle = true
                        ) {
                            Icon(
                                painter = painterResource(R.drawable.icon_addfolder),
                                contentDescription = stringResource(R.string.new_category),
                                tint = Color.Unspecified,
                                modifier = Modifier.size(80.dp)
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(80.dp))
        }
    }

    // Delete confirmation dialog
    categoryToDelete?.let { cat ->
        val count = quotes.count { it.categoryId == cat.id }
        val isPack = cat.sourcePackId != null
        val quotesWord = if (count == 1) stringResource(R.string.quote_singular) else stringResource(R.string.quote_plural)
        AlertDialog(
            onDismissRequest = { categoryToDelete = null },
            title = {
                Text(if (isPack) stringResource(R.string.remove_name, cat.name) else stringResource(R.string.delete_name, cat.name))
            },
            text = {
                Text(
                    if (isPack) stringResource(R.string.remove_pack_message, count, quotesWord)
                    else if (count > 0) stringResource(R.string.delete_category_message, count, quotesWord)
                    else stringResource(R.string.category_no_quotes)
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteCategory(cat)
                    categoryToDelete = null
                }) {
                    Text(
                        if (isPack) stringResource(R.string.remove) else stringResource(R.string.delete),
                        color = MaterialTheme.colorScheme.error
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { categoryToDelete = null }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }

    // New Category bottom sheet
    if (showNewCategorySheet) {
        ModalBottomSheet(
            onDismissRequest = { showNewCategorySheet = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            dragHandle = null
        ) {
            NewCategorySheet(
                viewModel = viewModel,
                onSave = { name, coverImageUrl ->
                    val category = QuoteCategory(
                        name = name,
                        gradientIndex = viewModel.nextGradientIndex(),
                        coverImageUrl = coverImageUrl
                    )
                    viewModel.addCategory(category)
                    showNewCategorySheet = false
                },
                onDismiss = { showNewCategorySheet = false }
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun CategoryCard(
    category: QuoteCategory,
    quoteCount: Int,
    onClick: () -> Unit,
    onLongClick: () -> Unit = {}
) {
    val gradientIndex = (category.gradientIndex ?: 0) % gradientPalettes.size
    val gradient = gradientPalettes[gradientIndex]

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
            .combinedClickable(
                onClick = onClick,
                onLongClick = onLongClick
            ),
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(2.dp, BorderColor)
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            // Diagonal gradient background (topLeading → bottomTrailing)
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.linearGradient(
                            colors = gradient
                        )
                    )
            )

            // Cover image if available
            if (category.coverImageUrl != null) {
                AsyncImage(
                    model = category.coverImageUrl,
                    contentDescription = category.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
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

            // Category name and quote count
            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(12.dp)
            ) {
                Text(
                    text = category.name,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = stringResource(R.string.quotes_format, quoteCount),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoryDetailScreen(
    categoryId: String,
    onBack: () -> Unit,
    onQuoteClick: (Quote) -> Unit,
    onAddQuote: (String) -> Unit,
    onEditQuote: (Quote) -> Unit,
    viewModel: LibraryViewModel = hiltViewModel()
) {
    val allCategories by viewModel.categories.collectAsState()
    val allQuotes by viewModel.quotes.collectAsState()
    val category = allCategories.firstOrNull { it.id == categoryId } ?: run {
        LaunchedEffect(Unit) { onBack() }
        return
    }
    val quotes = allQuotes.filter { it.categoryId == categoryId }.sortedBy { it.sortOrder }
    val isPack = category.sourcePackId != null
    var quoteToDelete by remember { mutableStateOf<Quote?>(null) }
    var searchText by remember { mutableStateOf("") }
    var editedName by remember(category.name) { mutableStateOf(category.name) }
    var showCategorySettings by remember { mutableStateOf(false) }

    val filteredQuotes = remember(quotes, searchText) {
        if (searchText.isBlank()) quotes
        else {
            val query = searchText.lowercase()
            quotes.filter {
                it.title.lowercase().contains(query) ||
                        it.text.lowercase().contains(query)
            }
        }
    }

    val listState = rememberLazyListState()
    // Show pack/category name in toolbar once the header scrolls off screen
    val showNavTitle by remember {
        derivedStateOf {
            listState.firstVisibleItemIndex > 0 ||
                    (listState.firstVisibleItemIndex == 0 && listState.firstVisibleItemScrollOffset > 150)
        }
    }

    // Animated toolbar alpha for smooth fade like iOS
    val toolbarAlpha by animateFloatAsState(
        targetValue = if (showNavTitle) 0.95f else 0f,
        animationSpec = tween(durationMillis = 250),
        label = "toolbarAlpha"
    )
    val surfaceColor = MaterialTheme.colorScheme.surface

    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val toolbarHeight = statusBarTop + 56.dp

    Box(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = toolbarHeight, bottom = 80.dp)
        ) {
            // Header: thumbnail + editable name + search
            item {
                CategoryDetailHeader(
                    category = category,
                    editedName = editedName,
                    onNameChange = { editedName = it },
                    onNameCommit = {
                        val trimmed = editedName.trim()
                        if (trimmed.isNotEmpty() && trimmed != category.name) {
                            viewModel.updateCategory(category.copy(name = trimmed))
                        } else {
                            editedName = category.name
                        }
                    },
                    searchText = searchText,
                    onSearchChange = { searchText = it },
                    onThumbnailClick = { showCategorySettings = true }
                )
            }

            if (filteredQuotes.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(300.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        if (searchText.isBlank()) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                BrainCharacterView(character = BrainCharacter.WORK1, size = 120.dp)
                                Spacer(Modifier.height(12.dp))
                                Text(
                                    text = stringResource(R.string.no_quotes_in_category),
                                    style = MaterialTheme.typography.titleMedium
                                )
                                Spacer(Modifier.height(4.dp))
                                Text(
                                    text = if (isPack) stringResource(R.string.pack_appears_empty)
                                    else stringResource(R.string.add_quote_to_get_started),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                if (!isPack) {
                                    Spacer(Modifier.height(16.dp))
                                    Button(onClick = { onAddQuote(categoryId) }) {
                                        Text(stringResource(R.string.add_quote))
                                    }
                                }
                            }
                        } else {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(
                                    Icons.Default.Search,
                                    contentDescription = null,
                                    modifier = Modifier.size(60.dp),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Spacer(Modifier.height(8.dp))
                                Text(stringResource(R.string.no_results_found), style = MaterialTheme.typography.titleMedium)
                                Text(
                                    stringResource(R.string.try_different_search),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            } else {
                items(filteredQuotes, key = { it.id }) { quote ->
                    if (isPack) {
                        QuoteListRow(
                            quote = quote,
                            onClick = { onQuoteClick(quote) }
                        )
                    } else {
                        SwipeableQuoteRow(
                            onDelete = { quoteToDelete = quote },
                            onEdit = { onEditQuote(quote) }
                        ) {
                            QuoteListRow(
                                quote = quote,
                                onClick = { onQuoteClick(quote) }
                            )
                        }
                    }
                    HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                }
            }
        }

        // Floating toolbar with gradient fade — matches iOS navigation bar blur
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopStart)
        ) {
            // Gradient background layer — tall enough to fade smoothly below the toolbar
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(toolbarHeight + 30.dp)
                    .background(
                        Brush.verticalGradient(
                            colorStops = arrayOf(
                                0.0f to surfaceColor.copy(alpha = toolbarAlpha.coerceAtLeast(0.01f)),
                                0.7f to surfaceColor.copy(alpha = toolbarAlpha.coerceAtLeast(0.01f) * 0.92f),
                                0.85f to surfaceColor.copy(alpha = toolbarAlpha * 0.4f),
                                1.0f to Color.Transparent
                            )
                        )
                    )
            )
            // Toolbar content — solid touch target that blocks pass-through
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(toolbarHeight)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = { /* consume touches — block pass-through */ }
                    )
            ) {
                Spacer(Modifier.windowInsetsPadding(WindowInsets.statusBars))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .padding(horizontal = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Back button with circular background like iOS
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .background(
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                                shape = CircleShape
                            )
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                onClick = onBack
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.ChevronLeft,
                            contentDescription = stringResource(R.string.back),
                            modifier = Modifier.size(24.dp),
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }
                    if (showNavTitle) {
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = category.name,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f).padding(end = if (isPack) 16.dp else 48.dp)
                        )
                    } else {
                        Text(
                            stringResource(R.string.library),
                            color = MaterialTheme.colorScheme.primary,
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier
                                .clickable(
                                    interactionSource = remember { MutableInteractionSource() },
                                    indication = null,
                                    onClick = onBack
                                )
                                .padding(start = 4.dp)
                        )
                        Spacer(Modifier.weight(1f))
                    }
                    if (!isPack) {
                        IconButton(onClick = { onAddQuote(categoryId) }) {
                            Icon(
                                painter = painterResource(R.drawable.icon_addquote),
                                contentDescription = stringResource(R.string.add_quote),
                                tint = Color.Unspecified,
                                modifier = Modifier.size(32.dp)
                            )
                        }
                    }
                }
            }
        }
    } // Box

    quoteToDelete?.let { q ->
        AlertDialog(
            onDismissRequest = { quoteToDelete = null },
            title = { Text(stringResource(R.string.delete_quote)) },
            text = { Text(stringResource(R.string.delete_quote_name, q.title)) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteQuote(q)
                    quoteToDelete = null
                }) { Text(stringResource(R.string.delete), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { quoteToDelete = null }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }

    // Category Settings bottom sheet
    if (showCategorySettings) {
        ModalBottomSheet(
            onDismissRequest = { showCategorySettings = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            dragHandle = null
        ) {
            // Fill to match iOS height — content at top, empty space below
            Column(modifier = Modifier.fillMaxHeight(0.85f)) {
            CategorySettingsSheet(
                category = category,
                quotes = quotes,
                isPack = isPack,
                viewModel = viewModel,
                onSave = { updatedCategory ->
                    viewModel.updateCategory(updatedCategory)
                    showCategorySettings = false
                },
                onDelete = {
                    viewModel.deleteCategory(category)
                    showCategorySettings = false
                    onBack()
                },
                onDismiss = { showCategorySettings = false }
            )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Category Detail Header (thumbnail + editable name + search)
// ---------------------------------------------------------------------------

@Composable
private fun CategoryDetailHeader(
    category: QuoteCategory,
    editedName: String,
    onNameChange: (String) -> Unit,
    onNameCommit: () -> Unit,
    searchText: String,
    onSearchChange: (String) -> Unit,
    onThumbnailClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        // Gradient thumbnail — tappable to open settings
        CategoryThumbnail(
            category = category,
            size = 70.dp,
            onClick = onThumbnailClick
        )

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Inline editable category name
            BasicTextField(
                value = editedName,
                onValueChange = onNameChange,
                textStyle = TextStyle(
                    fontSize = MaterialTheme.typography.titleLarge.fontSize,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                ),
                singleLine = true,
                cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                modifier = Modifier
                    .fillMaxWidth()
                    .onFocusChanged { state ->
                        if (!state.isFocused) onNameCommit()
                    }
            )

            // Embedded search bar — aligned with title, to the right of thumbnail
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant,
                        RoundedCornerShape(8.dp)
                    )
                    .padding(horizontal = 10.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    Icons.Default.Search,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                BasicTextField(
                    value = searchText,
                    onValueChange = onSearchChange,
                    textStyle = TextStyle(
                        fontSize = MaterialTheme.typography.bodyMedium.fontSize,
                        color = MaterialTheme.colorScheme.onSurface
                    ),
                    singleLine = true,
                    cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                    modifier = Modifier.weight(1f),
                    decorationBox = { innerTextField ->
                        if (searchText.isEmpty()) {
                            Text(
                                stringResource(R.string.search_in_category, category.name),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                        innerTextField()
                    }
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Category Thumbnail (small gradient square)
// ---------------------------------------------------------------------------

@Composable
private fun CategoryThumbnail(
    category: QuoteCategory,
    size: androidx.compose.ui.unit.Dp,
    onClick: () -> Unit = {}
) {
    val gradientIndex = (category.gradientIndex ?: 0) % gradientPalettes.size
    val gradient = gradientPalettes[gradientIndex]
    val shape = RoundedCornerShape(8.dp)

    Card(
        modifier = Modifier
            .size(size)
            .clickable(onClick = onClick),
        shape = shape,
        border = BorderStroke(2.dp, BorderColor)
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            // Gradient fallback
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Brush.linearGradient(colors = gradient))
            )
            // Cover image overlay if available
            if (category.coverImageUrl != null) {
                AsyncImage(
                    model = category.coverImageUrl,
                    contentDescription = category.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Category Settings Sheet
// ---------------------------------------------------------------------------

@Composable
private fun CategorySettingsSheet(
    category: QuoteCategory,
    quotes: List<Quote>,
    isPack: Boolean,
    viewModel: LibraryViewModel,
    onSave: (QuoteCategory) -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit
) {
    val quoteCount = quotes.size
    var name by remember { mutableStateOf(category.name) }
    var coverImageUrl by remember { mutableStateOf(category.coverImageUrl) }
    var showDeleteConfirmation by remember { mutableStateOf(false) }
    var showPhotoSourcePicker by remember { mutableStateOf(false) }
    var showUnsplashSearch by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val galleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        uri?.let {
            scope.launch(Dispatchers.IO) {
                val path = saveCategoryImageFromUri(context, it)
                if (path != null) coverImageUrl = path
            }
        }
    }

    if (showUnsplashSearch) {
        UnsplashSearchContent(
            viewModel = viewModel,
            onSelect = { imageInfo ->
                coverImageUrl = imageInfo.regularURL
                scope.launch(Dispatchers.IO) {
                    viewModel.unsplashService.triggerDownload(imageInfo.downloadURL)
                }
                showUnsplashSearch = false
            },
            onBack = { showUnsplashSearch = false }
        )
    } else {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surfaceContainerLow)
        ) {
            // Top bar — matches iOS inline navigation bar
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp)
                    .padding(top = 6.dp, bottom = 8.dp)
            ) {
                // Leading: Done/Cancel
                TextButton(
                    onClick = {
                        if (!isPack) {
                            onDismiss()
                        } else {
                            onDismiss()
                        }
                    },
                    modifier = Modifier.align(Alignment.CenterStart)
                ) {
                    Text(
                        if (isPack) stringResource(R.string.done) else stringResource(R.string.cancel),
                        color = MaterialTheme.colorScheme.primary
                    )
                }
                // Center: Title
                Text(
                    if (isPack) stringResource(R.string.pack_settings) else stringResource(R.string.category_settings),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.align(Alignment.Center)
                )
                // Trailing: Save (non-pack only)
                if (!isPack) {
                    TextButton(
                        onClick = {
                            val trimmed = name.trim()
                            if (trimmed.isNotEmpty()) {
                                onSave(category.copy(name = trimmed, coverImageUrl = coverImageUrl))
                            }
                        },
                        enabled = name.isNotBlank(),
                        modifier = Modifier.align(Alignment.CenterEnd)
                    ) {
                        Text(
                            stringResource(R.string.save),
                            fontWeight = FontWeight.SemiBold,
                            color = if (name.isNotBlank()) MaterialTheme.colorScheme.primary
                                    else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // Scrollable content with grouped sections
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp)
                    .padding(bottom = 24.dp)
            ) {
                if (!isPack) {
                    // Name section
                    SettingsSectionHeader(stringResource(R.string.name_header))
                    Card(
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        OutlinedTextField(
                            value = name,
                            onValueChange = { name = it },
                            singleLine = true,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(4.dp),
                            colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
                                unfocusedBorderColor = androidx.compose.ui.graphics.Color.Transparent,
                                focusedBorderColor = androidx.compose.ui.graphics.Color.Transparent
                            )
                        )
                    }

                    Spacer(Modifier.height(20.dp))

                    // Cover Photo section
                    SettingsSectionHeader(stringResource(R.string.cover_photo_header))
                    CoverPhotoSection(
                        coverImageUrl = coverImageUrl,
                        onAddPhoto = { showPhotoSourcePicker = true },
                        onRemovePhoto = { coverImageUrl = null }
                    )

                    Spacer(Modifier.height(20.dp))
                }

                // Download as PDF section
                if (quotes.isNotEmpty()) {
                    // Collect every language available across the pack:
                    //   primaryLanguage of each quote (or "en" fallback) + all translation keys.
                    val availableLanguages: List<String> = remember(quotes) {
                        val set = linkedSetOf<String>()
                        quotes.forEach { q ->
                            set.add(q.primaryLanguage ?: "en")
                            q.translations?.keys?.forEach { set.add(it) }
                        }
                        set.toList()
                    }
                    var showPdfLanguagePicker by remember { mutableStateOf(false) }

                    Spacer(Modifier.height(if (!isPack) 0.dp else 8.dp))
                    Card(
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    if (availableLanguages.size > 1) {
                                        showPdfLanguagePicker = true
                                    } else {
                                        val lang = availableLanguages.firstOrNull()
                                        scope.launch(Dispatchers.IO) {
                                            generateAndSharePdf(context, category.name, quotes, lang)
                                        }
                                    }
                                }
                                .padding(horizontal = 16.dp, vertical = 14.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Download,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(22.dp)
                            )
                            Spacer(Modifier.width(12.dp))
                            Text(
                                stringResource(R.string.download_as_pdf),
                                style = MaterialTheme.typography.bodyLarge,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                    Spacer(Modifier.height(20.dp))

                    if (showPdfLanguagePicker) {
                        AlertDialog(
                            onDismissRequest = { showPdfLanguagePicker = false },
                            title = { Text(stringResource(R.string.choose_pdf_language)) },
                            text = {
                                Column {
                                    availableLanguages.forEach { lang ->
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .clickable {
                                                    showPdfLanguagePicker = false
                                                    scope.launch(Dispatchers.IO) {
                                                        generateAndSharePdf(context, category.name, quotes, lang)
                                                    }
                                                }
                                                .padding(vertical = 12.dp)
                                        ) {
                                            Text(
                                                pdfLanguageDisplayName(lang),
                                                style = MaterialTheme.typography.bodyLarge
                                            )
                                        }
                                    }
                                }
                            },
                            confirmButton = {
                                TextButton(onClick = { showPdfLanguagePicker = false }) {
                                    Text(stringResource(R.string.cancel))
                                }
                            }
                        )
                    }
                }

                // Delete / Remove section
                Card(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { showDeleteConfirmation = true }
                            .padding(horizontal = 16.dp, vertical = 14.dp)
                    ) {
                        Icon(
                            painter = painterResource(R.drawable.icon_trash),
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error,
                            modifier = Modifier.size(22.dp)
                        )
                        Spacer(Modifier.width(12.dp))
                        Text(
                            if (isPack) stringResource(R.string.remove_pack) else stringResource(R.string.delete_category),
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                }

                if (isPack) {
                    val quotesWord = if (quoteCount == 1) stringResource(R.string.quote_singular) else stringResource(R.string.quote_plural)
                    Text(
                        stringResource(R.string.remove_pack_message, quoteCount, quotesWord),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 6.dp)
                    )
                }
            }
        }
    }

    if (showPhotoSourcePicker) {
        PhotoSourcePickerDialog(
            onGallery = {
                showPhotoSourcePicker = false
                galleryLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
            onUnsplash = {
                showPhotoSourcePicker = false
                showUnsplashSearch = true
            },
            onDismiss = { showPhotoSourcePicker = false }
        )
    }

    if (showDeleteConfirmation) {
        val quotesWord = if (quoteCount == 1) stringResource(R.string.quote_singular) else stringResource(R.string.quote_plural)
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = {
                Text(if (isPack) stringResource(R.string.remove_name, category.name) else stringResource(R.string.delete_name, category.name))
            },
            text = {
                Text(
                    if (isPack) stringResource(R.string.remove_pack_message, quoteCount, quotesWord)
                    else if (quoteCount > 0) stringResource(R.string.delete_category_message, quoteCount, quotesWord)
                    else stringResource(R.string.category_no_quotes)
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteConfirmation = false
                    onDelete()
                }) {
                    Text(
                        if (isPack) stringResource(R.string.remove) else stringResource(R.string.delete),
                        color = MaterialTheme.colorScheme.error
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmation = false }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeableQuoteRow(
    onDelete: () -> Unit,
    onEdit: () -> Unit,
    content: @Composable () -> Unit
) {
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            when (value) {
                SwipeToDismissBoxValue.EndToStart -> {
                    onDelete()
                    false
                }
                SwipeToDismissBoxValue.StartToEnd -> {
                    onEdit()
                    false
                }
                else -> false
            }
        }
    )

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            val direction = dismissState.dismissDirection

            Box(modifier = Modifier.fillMaxSize()) {
                // Edit background (left side, orange)
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color(0xFFFF9800))
                        .padding(start = 20.dp),
                    contentAlignment = Alignment.CenterStart
                ) {
                    Icon(
                        Icons.Default.Edit,
                        contentDescription = stringResource(R.string.edit),
                        tint = Color.White
                    )
                }

                // Delete background (right side, red)
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(MaterialTheme.colorScheme.error)
                        .padding(end = 20.dp),
                    contentAlignment = Alignment.CenterEnd
                ) {
                    Icon(
                        painter = painterResource(R.drawable.icon_trash),
                        contentDescription = stringResource(R.string.delete),
                        tint = Color.White,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }
        }
    ) {
        Box(
            modifier = Modifier.background(MaterialTheme.colorScheme.surface)
        ) {
            content()
        }
    }
}

@Composable
private fun QuoteListRow(
    quote: Quote,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        // Title
        Text(
            text = quote.displayTitle,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        // Preview text (hidden if title matches the start of text)
        if (!quote.titleMatchesPreview) {
            Spacer(Modifier.height(2.dp))
            Text(
                text = quote.preview,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }

        Spacer(Modifier.height(6.dp))

        // Bottom row: mastery badge + chunk badge + stats + word count
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            MasteryBadge(level = quote.masteryLevel)

            // Chunk badge for split quotes
            if (quote.isSplit) {
                val chunkCount = quote.chunks?.size ?: 0
                Spacer(Modifier.width(6.dp))
                Text(
                    text = stringResource(R.string.parts_format, chunkCount),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = IndigoColor,
                    modifier = Modifier
                        .background(
                            IndigoColor.copy(alpha = 0.12f),
                            RoundedCornerShape(6.dp)
                        )
                        .padding(horizontal = 6.dp, vertical = 3.dp)
                )
            }

            if (quote.practiceCount > 0) {
                Spacer(Modifier.width(6.dp))
                Text(
                    text = stringResource(R.string.attempts_accuracy_format, quote.practiceCount, (quote.bestAccuracy * 100).toInt()),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant,
                            RoundedCornerShape(8.dp)
                        )
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }

            Spacer(Modifier.weight(1f))

            Text(
                text = stringResource(R.string.words_format, quote.wordCount),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun NewCategorySheet(
    viewModel: LibraryViewModel,
    onSave: (String, String?) -> Unit,
    onDismiss: () -> Unit
) {
    var name by remember { mutableStateOf("") }
    var coverImageUrl by remember { mutableStateOf<String?>(null) }
    var showPhotoSourcePicker by remember { mutableStateOf(false) }
    var showUnsplashSearch by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val galleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        uri?.let {
            scope.launch(Dispatchers.IO) {
                val path = saveCategoryImageFromUri(context, it)
                if (path != null) coverImageUrl = path
            }
        }
    }

    if (showUnsplashSearch) {
        UnsplashSearchContent(
            viewModel = viewModel,
            onSelect = { imageInfo ->
                coverImageUrl = imageInfo.regularURL
                scope.launch(Dispatchers.IO) {
                    viewModel.unsplashService.triggerDownload(imageInfo.downloadURL)
                }
                showUnsplashSearch = false
            },
            onBack = { showUnsplashSearch = false }
        )
    } else {
        val pillShape = RoundedCornerShape(50)
        val pillColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)
        val fieldShape = RoundedCornerShape(12.dp)
        val fieldColors = TextFieldDefaults.colors(
            unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            unfocusedIndicatorColor = Color.Transparent,
            focusedIndicatorColor = Color.Transparent
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.93f)
                .padding(horizontal = 20.dp)
        ) {
            Spacer(Modifier.height(12.dp))

            // Header bar — Cancel / Title / Save (matches Quote Pack Request)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier.background(pillColor, pillShape)
                ) {
                    Text(stringResource(R.string.cancel), style = MaterialTheme.typography.bodyLarge)
                }
                Text(
                    stringResource(R.string.new_category),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                TextButton(
                    onClick = { onSave(name.trim(), coverImageUrl) },
                    enabled = name.isNotBlank(),
                    modifier = Modifier.background(pillColor, pillShape)
                ) {
                    Text(stringResource(R.string.save), style = MaterialTheme.typography.bodyLarge)
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Cover photo section
                CoverPhotoSection(
                    coverImageUrl = coverImageUrl,
                    onAddPhoto = { showPhotoSourcePicker = true },
                    onRemovePhoto = { coverImageUrl = null }
                )

                TextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(stringResource(R.string.category_name_label)) },
                    singleLine = true,
                    shape = fieldShape,
                    colors = fieldColors,
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(8.dp))
            }
        }
    }

    if (showPhotoSourcePicker) {
        PhotoSourcePickerDialog(
            onGallery = {
                showPhotoSourcePicker = false
                galleryLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
            onUnsplash = {
                showPhotoSourcePicker = false
                showUnsplashSearch = true
            },
            onDismiss = { showPhotoSourcePicker = false }
        )
    }
}

// ---------------------------------------------------------------------------
// Cover Photo Section
// ---------------------------------------------------------------------------

@Composable
private fun CoverPhotoSection(
    coverImageUrl: String?,
    onAddPhoto: () -> Unit,
    onRemovePhoto: () -> Unit
) {
    if (coverImageUrl != null) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .clickable(onClick = onAddPhoto)
        ) {
            AsyncImage(
                model = if (coverImageUrl.startsWith("/")) Uri.fromFile(File(coverImageUrl)) else coverImageUrl,
                contentDescription = stringResource(R.string.cover_photo),
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
            )
            // Remove button
            Icon(
                Icons.Default.Close,
                contentDescription = stringResource(R.string.remove),
                tint = Color.White,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(8.dp)
                    .size(24.dp)
                    .background(Color.Black.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
                    .clickable { onRemovePhoto() }
                    .padding(4.dp)
            )
        }
    } else {
        // Dashed-border placeholder
        val borderColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .clip(RoundedCornerShape(12.dp))
                .dashedBorder(2.dp, borderColor, 12.dp)
                .clickable(onClick = onAddPhoto),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    Icons.Default.AddPhotoAlternate,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(32.dp)
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    stringResource(R.string.add_cover_photo),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

/** Draws a dashed border using Canvas. */
private fun Modifier.dashedBorder(
    width: androidx.compose.ui.unit.Dp,
    color: Color,
    cornerRadius: androidx.compose.ui.unit.Dp
) = this.then(
    Modifier.drawBehind {
        val strokeWidth = width.toPx()
        val rx = cornerRadius.toPx()
        drawRoundRect(
            color = color,
            style = androidx.compose.ui.graphics.drawscope.Stroke(
                width = strokeWidth,
                pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(
                    floatArrayOf(10f, 8f), 0f
                )
            ),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(rx, rx)
        )
    }
)

// ---------------------------------------------------------------------------
// Photo Source Picker Dialog
// ---------------------------------------------------------------------------

@Composable
private fun PhotoSourcePickerDialog(
    onGallery: () -> Unit,
    onUnsplash: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.cover_photo)) },
        text = {
            Column {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onGallery)
                        .padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text("🖼️", style = MaterialTheme.typography.titleMedium)
                    Text(stringResource(R.string.choose_from_gallery), style = MaterialTheme.typography.bodyLarge)
                }
                HorizontalDivider()
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onUnsplash)
                        .padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text("🔍", style = MaterialTheme.typography.titleMedium)
                    Text(stringResource(R.string.search_online), style = MaterialTheme.typography.bodyLarge)
                }
            }
        },
        confirmButton = {},
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        }
    )
}

// ---------------------------------------------------------------------------
// Unsplash Search Content
// ---------------------------------------------------------------------------

@Composable
private fun UnsplashSearchContent(
    viewModel: LibraryViewModel,
    onSelect: (UnsplashImageInfo) -> Unit,
    onBack: () -> Unit
) {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<UnsplashImageInfo>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(top = 16.dp, bottom = 24.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = stringResource(R.string.back),
                modifier = Modifier
                    .size(24.dp)
                    .clickable(onClick = onBack),
                tint = MaterialTheme.colorScheme.primary
            )
            Text(
                stringResource(R.string.search_online),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(Modifier.height(12.dp))

        // Search field
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { Text(stringResource(R.string.search_photos)) },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )

        // Trigger search
        LaunchedEffect(query) {
            if (query.length >= 2) {
                kotlinx.coroutines.delay(500L)
                isLoading = true
                results = try {
                    viewModel.unsplashService.searchPhotos(query)
                } catch (_: Exception) {
                    emptyList()
                }
                isLoading = false
            } else {
                results = emptyList()
            }
        }

        Spacer(Modifier.height(12.dp))

        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else if (results.isEmpty() && query.length >= 2) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    stringResource(R.string.no_photos_found),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            // 2-column grid of results
            val gridHeight = ((results.size + 1) / 2) * 200
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(gridHeight.dp.coerceAtMost(500.dp)),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(results, key = { it.regularURL }) { photo ->
                    UnsplashPhotoCard(photo = photo, onClick = { onSelect(photo) })
                }
            }
        }
    }
}

@Composable
private fun UnsplashPhotoCard(
    photo: UnsplashImageInfo,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(8.dp)
    ) {
        Box {
            AsyncImage(
                model = photo.smallURL,
                contentDescription = stringResource(R.string.photo_by, photo.photographerName),
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(0.75f)
            )
            // Photographer attribution overlay at bottom
            Box(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .fillMaxWidth()
                    .background(Color.Black.copy(alpha = 0.5f))
                    .padding(horizontal = 6.dp, vertical = 4.dp)
            ) {
                Text(
                    text = photo.photographerName,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Utility: Save gallery image to internal storage
// ---------------------------------------------------------------------------

private fun saveCategoryImageFromUri(context: android.content.Context, uri: Uri): String? {
    return try {
        val dir = File(context.filesDir, "category_images")
        dir.mkdirs()
        val file = File(dir, "${UUID.randomUUID()}.jpg")
        context.contentResolver.openInputStream(uri)?.use { input ->
            file.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        file.absolutePath
    } catch (_: Exception) {
        null
    }
}

@Composable
private fun SettingsSectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 4.dp, bottom = 6.dp)
    )
}

private fun pdfLanguageDisplayName(code: String): String {
    val locale = Locale(code)
    return locale.getDisplayLanguage(Locale.getDefault())
        .replaceFirstChar { it.uppercase() }
        .ifEmpty { code.uppercase() }
}

/** Returns (title, text) in the requested language, falling back to the quote's primary fields. */
private fun localizedTitleText(quote: Quote, languageCode: String?): Pair<String, String> {
    if (languageCode == null) return quote.title to quote.text
    val primary = quote.primaryLanguage ?: "en"
    if (languageCode == primary) return quote.title to quote.text
    val translation = quote.translations?.get(languageCode)
    return if (translation != null) translation.title to translation.text
        else quote.title to quote.text
}

private fun generateAndSharePdf(
    context: android.content.Context,
    packName: String,
    quotes: List<Quote>,
    languageCode: String? = null
) {
    val pageWidth = 595  // A4 width in points
    val pageHeight = 842 // A4 height in points
    val margin = 50f
    val usableWidth = pageWidth - margin * 2

    val titlePaint = Paint().apply {
        textSize = 24f
        isFakeBoldText = true
        isAntiAlias = true
    }
    val quoteTitlePaint = Paint().apply {
        textSize = 14f
        isFakeBoldText = true
        isAntiAlias = true
    }
    val bodyPaint = Paint().apply {
        textSize = 12f
        isAntiAlias = true
    }
    val footerPaint = Paint().apply {
        textSize = 10f
        isAntiAlias = true
        color = android.graphics.Color.GRAY
    }

    val document = PdfDocument()
    var pageNumber = 1
    var pageInfo = PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create()
    var page = document.startPage(pageInfo)
    var canvas = page.canvas
    var y = margin + 10f

    for ((index, quote) in quotes.withIndex()) {
        val (locTitle, locText) = localizedTitleText(quote, languageCode)
        // Estimate space needed for this quote
        val titleLines = wrapText(locTitle, bodyPaint, usableWidth)
        val bodyLines = wrapText(locText, bodyPaint, usableWidth)
        val neededHeight = 24f + titleLines.size * 18f + bodyLines.size * 18f + 24f

        // Start new page if not enough room
        if (y + neededHeight > pageHeight - margin) {
            // Footer
            canvas.drawText("$packName — Page $pageNumber", margin, pageHeight - 30f, footerPaint)
            document.finishPage(page)
            pageNumber++
            pageInfo = PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create()
            page = document.startPage(pageInfo)
            canvas = page.canvas
            y = margin + 10f
        }

        // Quote number + title
        canvas.drawText("${index + 1}. $locTitle", margin, y, quoteTitlePaint)
        y += 20f

        // Quote body — word-wrapped
        for (line in bodyLines) {
            canvas.drawText(line, margin, y, bodyPaint)
            y += 18f
        }

        y += 16f // spacing between quotes
    }

    // Footer on last page
    canvas.drawText("$packName — Page $pageNumber", margin, pageHeight - 30f, footerPaint)
    document.finishPage(page)

    // Save to Downloads via MediaStore
    val cleanName = packName.replace(Regex("[^a-zA-Z0-9 ]"), "").trim()
    val fileName = if (languageCode != null) "$cleanName ($languageCode).pdf" else "$cleanName.pdf"
    val contentValues = ContentValues().apply {
        put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
        put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
    }
    val resolver = context.contentResolver
    val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
    if (uri != null) {
        resolver.openOutputStream(uri)?.use { document.writeTo(it) }
        document.close()

        // Show notification to open the PDF
        val channelId = "pdf_downloads"
        val notificationManager = context.getSystemService(android.content.Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Downloads", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "PDF download notifications"
            }
            notificationManager.createNotificationChannel(channel)
        }
        val openIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/pdf")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_clock)
            .setContentTitle(context.getString(R.string.pdf_downloaded))
            .setContentText(context.getString(R.string.pdf_saved_to_downloads, fileName))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(fileName.hashCode(), notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS permission not granted — toast is enough
        }

        android.os.Handler(android.os.Looper.getMainLooper()).post {
            Toast.makeText(context, context.getString(R.string.pdf_saved_toast), Toast.LENGTH_SHORT).show()
            // Open the PDF immediately
            try {
                context.startActivity(openIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } catch (_: Exception) {
                // No PDF viewer installed — notification and toast are enough
            }
        }
    } else {
        document.close()
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            Toast.makeText(context, context.getString(R.string.pdf_save_failed), Toast.LENGTH_SHORT).show()
        }
    }
}

private fun wrapText(text: String, paint: Paint, maxWidth: Float): List<String> {
    val words = text.split(" ")
    val lines = mutableListOf<String>()
    var currentLine = ""
    for (word in words) {
        val testLine = if (currentLine.isEmpty()) word else "$currentLine $word"
        if (paint.measureText(testLine) <= maxWidth) {
            currentLine = testLine
        } else {
            if (currentLine.isNotEmpty()) lines.add(currentLine)
            currentLine = word
        }
    }
    if (currentLine.isNotEmpty()) lines.add(currentLine)
    return lines
}
