package com.memorezar.app.ui.screens

import android.net.Uri
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
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AddPhotoAlternate
import androidx.compose.material.icons.filled.Close
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
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
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
import java.io.File
import java.util.UUID

private val gradientPalettes = listOf(
    listOf(Color(0xFF5C6BC0), Color(0xFF3949AB)),
    listOf(Color(0xFF26A69A), Color(0xFF00897B)),
    listOf(Color(0xFFEF5350), Color(0xFFE53935)),
    listOf(Color(0xFFAB47BC), Color(0xFF8E24AA)),
    listOf(Color(0xFF42A5F5), Color(0xFF1E88E5)),
    listOf(Color(0xFFFF7043), Color(0xFFE64A19)),
    listOf(Color(0xFF66BB6A), Color(0xFF43A047)),
    listOf(Color(0xFFEC407A), Color(0xFFD81B60)),
    listOf(Color(0xFF5C6BC0), Color(0xFF283593)),
    listOf(Color(0xFF78909C), Color(0xFF546E7A)),
    listOf(Color(0xFFFFA726), Color(0xFFF57C00)),
    listOf(Color(0xFF8D6E63), Color(0xFF6D4C41))
)

private val BorderColor = Color(0xFF777777)
private val IndigoColor = Color(0xFF5C6BC0)

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun QuoteLibraryScreen(
    onNavigateToRecitation: (String) -> Unit,
    onNavigateToQuoteInput: () -> Unit,
    onNavigateToQuoteInputForCategory: (String) -> Unit = {},
    onEditQuote: (Quote) -> Unit = {},
    tutorialStore: TutorialStore? = null,
    modifier: Modifier = Modifier,
    viewModel: LibraryViewModel = hiltViewModel()
) {
    val categories by viewModel.categories.collectAsState()
    val quotes by viewModel.quotes.collectAsState()
    var selectedCategory by remember { mutableStateOf<QuoteCategory?>(null) }
    var categoryToDelete by remember { mutableStateOf<QuoteCategory?>(null) }
    var showNewCategorySheet by remember { mutableStateOf(false) }

    // Auto-navigate into a newly added pack category
    val pendingNav by viewModel.quoteStore.pendingCategoryNavigation.collectAsState()
    LaunchedEffect(pendingNav) {
        pendingNav?.let { category ->
            selectedCategory = category
            viewModel.quoteStore.pendingCategoryNavigation.value = null
        }
    }

    if (selectedCategory != null) {
        CategoryDetailScreen(
            category = selectedCategory!!,
            quotes = quotes.filter { it.categoryId == selectedCategory!!.id }
                .sortedBy { it.sortOrder },
            isPack = selectedCategory!!.sourcePackId != null,
            viewModel = viewModel,
            onBack = { selectedCategory = null },
            onQuoteClick = { onNavigateToRecitation(it.id) },
            onDeleteQuote = { viewModel.deleteQuote(it) },
            onAddQuote = { onNavigateToQuoteInputForCategory(selectedCategory!!.id) },
            onEditQuote = onEditQuote,
            onUpdateCategory = { updated ->
                viewModel.updateCategory(updated)
                selectedCategory = updated
            },
            onDeleteCategory = { viewModel.deleteCategory(it) }
        )
    } else {
        Column(
            modifier = modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
        ) {
            // Header: "Library" + AddQuote icon
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Library",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                IconButton(onClick = onNavigateToQuoteInput) {
                    Icon(
                        painter = painterResource(R.drawable.icon_addquote),
                        contentDescription = "Add Quote",
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
                            onClick = { selectedCategory = category },
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
                                        if (category.sourcePackId != null) "Remove Pack" else "Delete Category",
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
                            text = TipDefinition.addCategory.content,
                            visible = tutorialStore?.shouldShowTip(TipDefinition.addCategory) == true,
                            wiggle = true
                        ) {
                            Icon(
                                painter = painterResource(R.drawable.icon_addfolder),
                                contentDescription = "New Category",
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
        AlertDialog(
            onDismissRequest = { categoryToDelete = null },
            title = {
                Text(if (isPack) "Remove ${cat.name}?" else "Delete ${cat.name}?")
            },
            text = {
                Text(
                    if (isPack) "This will remove the pack and its $count ${if (count == 1) "quote" else "quotes"}. You can re-add it anytime from Browse."
                    else if (count > 0) "This will permanently delete $count ${if (count == 1) "quote" else "quotes"} in this category."
                    else "This category has no quotes."
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteCategory(cat)
                    categoryToDelete = null
                }) {
                    Text(
                        if (isPack) "Remove" else "Delete",
                        color = MaterialTheme.colorScheme.error
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { categoryToDelete = null }) { Text("Cancel") }
            }
        )
    }

    // New Category bottom sheet
    if (showNewCategorySheet) {
        ModalBottomSheet(
            onDismissRequest = { showNewCategorySheet = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
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
                    text = "$quoteCount ${if (quoteCount == 1) "quote" else "quotes"}",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CategoryDetailScreen(
    category: QuoteCategory,
    quotes: List<Quote>,
    isPack: Boolean,
    viewModel: LibraryViewModel,
    onBack: () -> Unit,
    onQuoteClick: (Quote) -> Unit,
    onDeleteQuote: (Quote) -> Unit,
    onAddQuote: () -> Unit,
    onEditQuote: (Quote) -> Unit,
    onUpdateCategory: (QuoteCategory) -> Unit = {},
    onDeleteCategory: (QuoteCategory) -> Unit = {}
) {
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { },
                navigationIcon = {
                    Row(
                        modifier = Modifier
                            .clickable(onClick = onBack)
                            .padding(start = 4.dp, end = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            modifier = Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.primary
                        )
                        Text(
                            "Library",
                            color = MaterialTheme.colorScheme.primary,
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                },
                actions = {
                    if (!isPack) {
                        IconButton(onClick = onAddQuote) {
                            Icon(
                                painter = painterResource(R.drawable.icon_addquote),
                                contentDescription = "Add Quote",
                                tint = Color.Unspecified,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(bottom = 16.dp)
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
                            onUpdateCategory(category.copy(name = trimmed))
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
                                    text = "No quotes in this category",
                                    style = MaterialTheme.typography.titleMedium
                                )
                                Spacer(Modifier.height(4.dp))
                                Text(
                                    text = if (isPack) "This pack appears to be empty"
                                    else "Add a new quote to get started",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
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
                                Text("No results found", style = MaterialTheme.typography.titleMedium)
                                Text(
                                    "Try a different search term",
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
    }

    quoteToDelete?.let { q ->
        AlertDialog(
            onDismissRequest = { quoteToDelete = null },
            title = { Text("Delete Quote") },
            text = { Text("Delete \"${q.title}\"?") },
            confirmButton = {
                TextButton(onClick = {
                    onDeleteQuote(q)
                    quoteToDelete = null
                }) { Text("Delete", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { quoteToDelete = null }) { Text("Cancel") }
            }
        )
    }

    // Category Settings bottom sheet
    if (showCategorySettings) {
        ModalBottomSheet(
            onDismissRequest = { showCategorySettings = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ) {
            CategorySettingsSheet(
                category = category,
                quoteCount = quotes.size,
                isPack = isPack,
                viewModel = viewModel,
                onSave = { updatedCategory ->
                    onUpdateCategory(updatedCategory)
                    showCategorySettings = false
                },
                onDelete = {
                    onDeleteCategory(category)
                    showCategorySettings = false
                    onBack()
                },
                onDismiss = { showCategorySettings = false }
            )
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
                                "Search in ${category.name}...",
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
    quoteCount: Int,
    isPack: Boolean,
    viewModel: LibraryViewModel,
    onSave: (QuoteCategory) -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit
) {
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
                .verticalScroll(rememberScrollState())
                .padding(24.dp)
        ) {
            Text(
                if (isPack) "Pack Settings" else "Category Settings",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )

            Spacer(Modifier.height(20.dp))

            if (!isPack) {
                // Cover photo section
                CoverPhotoSection(
                    coverImageUrl = coverImageUrl,
                    onAddPhoto = { showPhotoSourcePicker = true },
                    onRemovePhoto = { coverImageUrl = null }
                )

                Spacer(Modifier.height(20.dp))

                // Category name field
                Text(
                    "Name",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(Modifier.height(4.dp))
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(20.dp))
            }

            // Delete / Remove button
            TextButton(
                onClick = { showDeleteConfirmation = true },
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        painter = painterResource(R.drawable.icon_trash),
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(20.dp)
                    )
                    Text(
                        if (isPack) "Remove Pack" else "Delete Category",
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }

            if (isPack) {
                Text(
                    "This will remove the pack and its $quoteCount ${if (quoteCount == 1) "quote" else "quotes"}. You can re-add it anytime from Browse.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }

            Spacer(Modifier.height(16.dp))

            // Action buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                TextButton(onClick = onDismiss) {
                    Text(if (isPack) "Done" else "Cancel")
                }
                if (!isPack) {
                    Spacer(Modifier.width(8.dp))
                    TextButton(
                        onClick = {
                            val trimmed = name.trim()
                            if (trimmed.isNotEmpty()) {
                                onSave(category.copy(name = trimmed, coverImageUrl = coverImageUrl))
                            }
                        },
                        enabled = name.isNotBlank()
                    ) { Text("Save") }
                }
            }

            Spacer(Modifier.height(16.dp))
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
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = {
                Text(if (isPack) "Remove ${category.name}?" else "Delete ${category.name}?")
            },
            text = {
                Text(
                    if (isPack) "This will remove the pack and its $quoteCount ${if (quoteCount == 1) "quote" else "quotes"}. You can re-add it anytime from Browse."
                    else if (quoteCount > 0) "This will permanently delete $quoteCount ${if (quoteCount == 1) "quote" else "quotes"} in this category."
                    else "This category has no quotes."
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteConfirmation = false
                    onDelete()
                }) {
                    Text(
                        if (isPack) "Remove" else "Delete",
                        color = MaterialTheme.colorScheme.error
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmation = false }) { Text("Cancel") }
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
                        contentDescription = "Edit",
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
                        contentDescription = "Delete",
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
                    text = "$chunkCount parts",
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
                    text = "\uD83C\uDFAF ${quote.practiceCount} attempts ${(quote.bestAccuracy * 100).toInt()}%",
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
                text = "${quote.wordCount} words",
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
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(24.dp)
        ) {
            Text(
                "New Category",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )

            Spacer(Modifier.height(16.dp))

            // Cover photo section
            CoverPhotoSection(
                coverImageUrl = coverImageUrl,
                onAddPhoto = { showPhotoSourcePicker = true },
                onRemovePhoto = { coverImageUrl = null }
            )

            Spacer(Modifier.height(16.dp))

            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Category Name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(20.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                TextButton(onClick = onDismiss) { Text("Cancel") }
                Spacer(Modifier.width(8.dp))
                TextButton(
                    onClick = { onSave(name.trim(), coverImageUrl) },
                    enabled = name.isNotBlank()
                ) { Text("Save") }
            }
            Spacer(Modifier.height(16.dp))
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
                contentDescription = "Cover photo",
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
            )
            // Remove button
            Icon(
                Icons.Default.Close,
                contentDescription = "Remove photo",
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
                    "Add Cover Photo",
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
        title = { Text("Cover Photo") },
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
                    Text("Photo Library", style = MaterialTheme.typography.bodyLarge)
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
                    Text("Search Unsplash", style = MaterialTheme.typography.bodyLarge)
                }
            }
        },
        confirmButton = {},
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
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
                contentDescription = "Back",
                modifier = Modifier
                    .size(24.dp)
                    .clickable(onClick = onBack),
                tint = MaterialTheme.colorScheme.primary
            )
            Text(
                "Search Unsplash",
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
            placeholder = { Text("Search photos...") },
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
                    "No photos found",
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
                contentDescription = "Photo by ${photo.photographerName}",
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
