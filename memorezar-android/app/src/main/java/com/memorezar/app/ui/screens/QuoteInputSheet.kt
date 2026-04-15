package com.memorezar.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.memorezar.app.R
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.models.QuoteCategory
import com.memorezar.app.data.storage.QuoteStore

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun QuoteInputSheet(
    quoteStore: QuoteStore,
    editQuote: Quote? = null,
    initialCategoryId: String? = null,
    onDismiss: () -> Unit
) {
    val allCategories by quoteStore.categories.collectAsState()
    // Filter out pack categories — users can only add quotes to their own categories
    val categories = remember(allCategories) {
        allCategories.filter { it.sourcePackId == null }
    }

    var title by remember { mutableStateOf(editQuote?.title ?: "") }
    var text by remember { mutableStateOf(editQuote?.text ?: "") }
    var selectedCategoryId by remember {
        mutableStateOf(
            editQuote?.categoryId
                ?: initialCategoryId
                ?: categories.firstOrNull()?.id
                ?: ""
        )
    }
    var categoryExpanded by remember { mutableStateOf(false) }

    val isValid = title.isNotBlank() && text.isNotBlank() && selectedCategoryId.isNotBlank()
    val wordCount = text.trim().split("\\s+".toRegex()).filter { it.isNotBlank() }.size

    val pillShape = RoundedCornerShape(50)
    val pillColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)
    val fieldShape = RoundedCornerShape(12.dp)
    val fieldColors = TextFieldDefaults.colors(
        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        unfocusedIndicatorColor = Color.Transparent,
        focusedIndicatorColor = Color.Transparent
    )

    val saveQuote: () -> Unit = {
        if (editQuote != null) {
            quoteStore.updateQuote(
                editQuote.copy(
                    title = title.trim(),
                    text = text.trim(),
                    categoryId = selectedCategoryId
                )
            )
        } else {
            quoteStore.addQuote(
                Quote(
                    title = title.trim(),
                    text = text.trim(),
                    categoryId = selectedCategoryId
                )
            )
        }
        onDismiss()
    }

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
                if (editQuote != null) stringResource(R.string.edit_quote) else stringResource(R.string.add_quote),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            TextButton(
                onClick = saveQuote,
                enabled = isValid,
                modifier = Modifier.background(pillColor, pillShape)
            ) {
                Text(stringResource(R.string.save), style = MaterialTheme.typography.bodyLarge)
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Title
            TextField(
                value = title,
                onValueChange = { title = it },
                label = { Text(stringResource(R.string.title)) },
                singleLine = true,
                shape = fieldShape,
                colors = fieldColors,
                modifier = Modifier.fillMaxWidth()
            )

            // Category picker
            ExposedDropdownMenuBox(
                expanded = categoryExpanded,
                onExpandedChange = { categoryExpanded = it }
            ) {
                TextField(
                    value = categories.firstOrNull { it.id == selectedCategoryId }?.name ?: "",
                    onValueChange = {},
                    readOnly = true,
                    label = { Text(stringResource(R.string.category)) },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = categoryExpanded) },
                    shape = fieldShape,
                    colors = fieldColors,
                    modifier = Modifier
                        .fillMaxWidth()
                        .menuAnchor()
                )
                ExposedDropdownMenu(
                    expanded = categoryExpanded,
                    onDismissRequest = { categoryExpanded = false }
                ) {
                    categories.forEach { category ->
                        DropdownMenuItem(
                            text = { Text(category.name) },
                            onClick = {
                                selectedCategoryId = category.id
                                categoryExpanded = false
                            }
                        )
                    }
                }
            }

            // Text
            TextField(
                value = text,
                onValueChange = { text = it },
                label = { Text(stringResource(R.string.quote_text)) },
                shape = fieldShape,
                colors = fieldColors,
                maxLines = 10,
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 120.dp)
            )

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                Text(
                    stringResource(R.string.words_format, wordCount),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // Word preview
            if (text.isNotBlank()) {
                Text(stringResource(R.string.preview), style = MaterialTheme.typography.titleSmall)
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    text.trim().split("\\s+".toRegex()).take(20).forEach { word ->
                        Surface(
                            shape = RoundedCornerShape(4.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant
                        ) {
                            Text(
                                text = word,
                                style = MaterialTheme.typography.bodySmall,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    }
                }
            }

            // Tips for new quotes
            if (editQuote == null) {
                Spacer(Modifier.height(4.dp))
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    TipRow("\uD83D\uDCA1", stringResource(R.string.tip_short_quotes))
                    TipRow("➡\uFE0F", stringResource(R.string.tip_longer_texts))
                    TipRow("\uD83D\uDD04", stringResource(R.string.tip_practice_regularly))
                }
            }

            Spacer(Modifier.height(16.dp))
        }
    }
}

@Composable
private fun TipRow(icon: String, text: String) {
    Row {
        Text(icon)
        Text(
            text = "  $text",
            style = MaterialTheme.typography.bodySmall,
            fontStyle = FontStyle.Italic,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
