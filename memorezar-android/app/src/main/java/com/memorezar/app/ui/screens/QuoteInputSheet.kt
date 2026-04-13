package com.memorezar.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
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

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp)
            .padding(top = 16.dp, bottom = 24.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
        ) {
            Text(
                if (editQuote != null) stringResource(R.string.edit_quote) else stringResource(R.string.add_quote),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Bold
            )
            Icon(
                Icons.Default.Close,
                contentDescription = stringResource(R.string.close),
                modifier = Modifier
                    .size(28.dp)
                    .clickable { onDismiss() },
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Spacer(Modifier.height(16.dp))

        // Title
        OutlinedTextField(
            value = title,
            onValueChange = { title = it },
            label = { Text(stringResource(R.string.title)) },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        Spacer(Modifier.height(12.dp))

        // Category picker
        ExposedDropdownMenuBox(
            expanded = categoryExpanded,
            onExpandedChange = { categoryExpanded = it }
        ) {
            OutlinedTextField(
                value = categories.firstOrNull { it.id == selectedCategoryId }?.name ?: "",
                onValueChange = {},
                readOnly = true,
                label = { Text(stringResource(R.string.category)) },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = categoryExpanded) },
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

        Spacer(Modifier.height(12.dp))

        // Text
        OutlinedTextField(
            value = text,
            onValueChange = { text = it },
            label = { Text(stringResource(R.string.quote_text)) },
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 120.dp),
            maxLines = 10
        )

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            Text(
                stringResource(R.string.words_format, wordCount),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Spacer(Modifier.height(12.dp))

        // Word preview
        if (text.isNotBlank()) {
            Text(stringResource(R.string.preview), style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.height(4.dp))
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

        Spacer(Modifier.height(16.dp))

        // Tips for new quotes
        if (editQuote == null) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                TipRow("\uD83D\uDCA1", stringResource(R.string.tip_short_quotes))
                TipRow("➡\uFE0F", stringResource(R.string.tip_longer_texts))
                TipRow("\uD83D\uDD04", stringResource(R.string.tip_practice_regularly))
            }
            Spacer(Modifier.height(16.dp))
        }

        // Save button
        Button(
            onClick = {
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
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = isValid
        ) {
            Text(if (editQuote != null) stringResource(R.string.save_changes) else stringResource(R.string.add_quote))
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
