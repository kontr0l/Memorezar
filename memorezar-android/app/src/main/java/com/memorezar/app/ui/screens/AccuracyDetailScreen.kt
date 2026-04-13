package com.memorezar.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.memorezar.app.R
import com.memorezar.app.data.storage.QuoteStore

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccuracyDetailScreen(
    quoteStore: QuoteStore,
    onBack: () -> Unit
) {
    val quotes by quoteStore.quotes.collectAsState()
    val sessions by quoteStore.sessions.collectAsState()

    val avgAccuracy = quoteStore.averageAccuracy
    val improvement = quoteStore.accuracyImprovement

    val practicedQuotes = quotes
        .filter { it.practiceCount > 0 }
        .sortedBy { it.bestAccuracy }

    val recentSessions = sessions
        .sortedByDescending { it.completedAt }
        .take(10)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.accuracy)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back))
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Header
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(Modifier.height(16.dp))
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                    contentAlignment = Alignment.Center
                ) {
                    Text("\uD83C\uDFAF", style = MaterialTheme.typography.headlineMedium)
                }
                Spacer(Modifier.height(12.dp))
                Text(
                    text = "${(avgAccuracy * 100).toInt()}%",
                    style = MaterialTheme.typography.displayMedium,
                    fontWeight = FontWeight.Bold,
                    color = accuracyColor(avgAccuracy)
                )
                Text(
                    stringResource(R.string.overall_accuracy),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                improvement?.let {
                    val sign = if (it >= 0) "+" else ""
                    val arrow = if (it >= 0) "\u2191" else "\u2193"
                    Text(
                        text = "$arrow ${sign}${(it * 100).toInt()}% vs previous",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (it >= 0) Color(0xFF34C759) else Color(0xFFE53935)
                    )
                }
            }

            // Per-Quote Breakdown
            if (practicedQuotes.isNotEmpty()) {
                Text(stringResource(R.string.per_quote_breakdown), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Card {
                    Column {
                        practicedQuotes.forEachIndexed { index, quote ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(quote.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                                    Text(
                                        stringResource(R.string.sessions_format, quote.practiceCount),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                Text(
                                    "${(quote.bestAccuracy * 100).toInt()}%",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = accuracyColor(quote.bestAccuracy)
                                )
                            }
                            if (index < practicedQuotes.lastIndex) {
                                HorizontalDivider()
                            }
                        }
                    }
                }
            }

            // Recent Sessions
            if (recentSessions.isNotEmpty()) {
                Text(stringResource(R.string.recent_sessions), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Card {
                    Column {
                        recentSessions.forEachIndexed { index, session ->
                            val quote = quotes.firstOrNull { it.id == session.quoteId }
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        quote?.title ?: stringResource(R.string.unknown_quote),
                                        style = MaterialTheme.typography.bodyMedium
                                    )
                                    Text(
                                        formatSessionDuration(session.duration),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                Text(
                                    "${(session.accuracy * 100).toInt()}%",
                                    fontWeight = FontWeight.Bold,
                                    color = accuracyColor(session.accuracy)
                                )
                            }
                            if (index < recentSessions.lastIndex) {
                                HorizontalDivider()
                            }
                        }
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
        }
    }
}

private fun accuracyColor(accuracy: Double): Color = when {
    accuracy >= 0.9 -> Color(0xFF34C759)
    accuracy >= 0.7 -> Color(0xFFFFA000)
    else -> Color(0xFFE53935)
}

private fun formatSessionDuration(millis: Long): String {
    val totalSeconds = (millis / 1000).toInt()
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return if (minutes > 0) "${minutes}m ${seconds}s" else "${seconds}s"
}
