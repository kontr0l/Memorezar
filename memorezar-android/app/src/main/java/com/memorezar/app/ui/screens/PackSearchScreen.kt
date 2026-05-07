package com.memorezar.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.memorezar.app.data.models.LanguageHelper
import com.memorezar.app.data.models.SuggestionPack

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PackSearchScreen(
    packs: List<SuggestionPack>,
    onNavigateToPackDetail: (SuggestionPack) -> Unit,
    onBack: () -> Unit
) {
    val lang = LanguageHelper.preferredLanguageCode
    var searchText by remember { mutableStateOf("") }

    val filteredPacks = remember(packs, searchText) {
        if (searchText.isBlank()) {
            packs
        } else {
            val query = searchText.lowercase()
            packs.filter {
                it.localizedName(lang).lowercase().contains(query) ||
                        it.localizedDescription(lang).lowercase().contains(query)
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Quote Packs") },
                navigationIcon = {
                    // iOS-style back button: chevron in a soft circle, no ripple.
                    Box(
                        modifier = Modifier
                            .padding(start = 4.dp)
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
                            contentDescription = "Back",
                            modifier = Modifier.size(24.dp),
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Pack grid fills the screen. Bottom contentPadding leaves clearance
            // for the floating search bar AND the app's outer bottom-nav bar, so
            // the last row scrolls fully into view above both.
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    top = 16.dp,
                    end = 16.dp,
                    bottom = 180.dp
                ),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(filteredPacks, key = { it.id }) { pack ->
                    PackCard(pack = pack, onClick = { onNavigateToPackDetail(pack) })
                }
            }

            // Floating search bar near the bottom — just the rounded text field,
            // no surrounding surface. Bottom padding tracks max(keyboard, 80dp):
            // it follows the keyboard up/down smoothly, but stops at 80dp on the
            // way down so it never dips into (or under) the outer bottom-nav bar.
            val density = LocalDensity.current
            val imeBottomDp = with(density) {
                WindowInsets.ime.getBottom(density).toDp()
            }
            val bottomPadding = if (imeBottomDp > 80.dp) imeBottomDp else 80.dp
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(bottom = bottomPadding)
            ) {
                OutlinedTextField(
                    value = searchText,
                    onValueChange = { searchText = it },
                    placeholder = { Text("Search quote packs") },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor =
                            MaterialTheme.colorScheme.surface.copy(alpha = 0.85f),
                        unfocusedContainerColor =
                            MaterialTheme.colorScheme.surface.copy(alpha = 0.85f)
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                )
            }
        }
    }
}
