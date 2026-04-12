package com.memorezar.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.memorezar.app.data.models.MasteryLevel

@Composable
fun MasteryBadge(level: MasteryLevel, modifier: Modifier = Modifier) {
    if (level == MasteryLevel.NONE) return

    val (color, icon, label) = when (level) {
        MasteryLevel.LEARNING -> Triple(Color(0xFF34C759), "🌱", "Learning")
        MasteryLevel.ADVANCING -> Triple(Color(0xFFFF6D00), "💡", "Advancing")
        MasteryLevel.PROFICIENT -> Triple(Color(0xFF5856D6), "✨", "Proficient")
        MasteryLevel.MASTERED -> Triple(Color(0xFFFFC107), "👑", "Mastered")
        else -> return
    }

    Row(
        modifier = modifier
            .background(
                color = color.copy(alpha = 0.15f),
                shape = RoundedCornerShape(4.dp)
            )
            .padding(horizontal = 6.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = icon, style = MaterialTheme.typography.labelSmall)
        Text(
            text = " $label",
            style = MaterialTheme.typography.labelSmall,
            color = color
        )
    }
}
