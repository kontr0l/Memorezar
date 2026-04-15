package com.memorezar.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.memorezar.app.R
import com.memorezar.app.data.storage.QuoteStore
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StreakDetailScreen(
    quoteStore: QuoteStore,
    onBack: () -> Unit,
    bottomNavHeight: Dp = 0.dp
) {
    val sessions by quoteStore.sessions.collectAsState()

    val streak = quoteStore.dailyStreak
    val totalDays = sessions.map { startOfDay(it.completedAt) }.toSet().size
    val sessionsThisWeek = run {
        val cal = Calendar.getInstance()
        cal.set(Calendar.DAY_OF_WEEK, cal.firstDayOfWeek)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        sessions.count { it.completedAt >= cal.timeInMillis }
    }

    // Last 30 days stats
    val last30Days = buildList {
        val cal = Calendar.getInstance()
        repeat(30) {
            val dayStart = startOfDay(cal.timeInMillis)
            val daySessions = sessions.filter { startOfDay(it.completedAt) == dayStart }
            add(
                DayStat(
                    date = Date(dayStart),
                    sessionCount = daySessions.size,
                    totalDuration = daySessions.sumOf { it.duration }
                )
            )
            cal.add(Calendar.DAY_OF_YEAR, -1)
        }
    }

    Scaffold(
        modifier = Modifier.padding(bottom = bottomNavHeight),
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.streak)) },
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
                    Text("\uD83D\uDD25", style = MaterialTheme.typography.headlineMedium)
                }
                Spacer(Modifier.height(12.dp))
                Text(
                    text = "$streak",
                    style = MaterialTheme.typography.displayMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFFFF5722)
                )
                Text(
                    stringResource(R.string.current_streak),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // Stats cards
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                StatBox(stringResource(R.string.total_days), "$totalDays", Modifier.weight(1f))
                StatBox(stringResource(R.string.this_week), "$sessionsThisWeek", Modifier.weight(1f))
            }

            // Practice History
            if (last30Days.any { it.sessionCount > 0 }) {
                Text(stringResource(R.string.last_30_days), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Card {
                    Column {
                        last30Days.forEachIndexed { index, day ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                if (day.sessionCount > 0) {
                                    Icon(
                                        Icons.Default.Check,
                                        contentDescription = stringResource(R.string.practiced),
                                        tint = Color(0xFF34C759),
                                        modifier = Modifier.size(20.dp)
                                    )
                                } else {
                                    Box(modifier = Modifier.size(20.dp))
                                }
                                Spacer(Modifier.padding(start = 12.dp))
                                Text(
                                    text = dateFormat.format(day.date),
                                    style = MaterialTheme.typography.bodyMedium,
                                    modifier = Modifier.weight(1f)
                                )
                                if (day.sessionCount > 0) {
                                    Text(
                                        stringResource(R.string.sessions_format, day.sessionCount),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                            if (index < last30Days.lastIndex) {
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

@Composable
private fun StatBox(label: String, value: String, modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

private data class DayStat(
    val date: Date,
    val sessionCount: Int,
    val totalDuration: Long
)

private val dateFormat = SimpleDateFormat("EEE, MMM d", Locale.getDefault())

private fun startOfDay(millis: Long): Long {
    val cal = Calendar.getInstance()
    cal.timeInMillis = millis
    cal.set(Calendar.HOUR_OF_DAY, 0)
    cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)
    return cal.timeInMillis
}
