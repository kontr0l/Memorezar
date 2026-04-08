package com.memorezar.app.ui.theme

import androidx.compose.ui.graphics.Color

// Brand colors — Indigo primary, matching iOS app
val IndigoLight = Color(0xFF818CF8)   // indigo-400, primary in dark mode
val IndigoDark = Color(0xFF4F46E5)    // indigo-600, primary in light mode
val IndigoContainer = Color(0xFFE0E7FF) // indigo-100, primaryContainer light
val OnIndigoContainer = Color(0xFF312E81) // indigo-900, onPrimaryContainer light
val IndigoContainerDark = Color(0xFF3730A3) // indigo-800, primaryContainer dark
val OnIndigoContainerDark = Color(0xFFC7D2FE) // indigo-200, onPrimaryContainer dark

// Secondary — Purple accent (used in gradients on iOS)
val PurpleLight = Color(0xFFA78BFA)   // purple-400
val PurpleDark = Color(0xFF7C3AED)    // purple-600
val PurpleContainer = Color(0xFFEDE9FE) // purple-100
val OnPurpleContainer = Color(0xFF4C1D95) // purple-900
val PurpleContainerDark = Color(0xFF5B21B6) // purple-800
val OnPurpleContainerDark = Color(0xFFDDD6FE) // purple-200

// Tertiary — Teal (complementary accent)
val TealLight = Color(0xFF5EEAD4)
val TealDark = Color(0xFF0D9488)

// Semantic colors used across the app
val MistakeFlash = Color(0x4DFF0000)       // 30% red overlay for visual flash
val MistakeFlashDark = Color(0x66FF3333)   // slightly brighter for dark mode
val CorrectGreen = Color(0xFF4CAF50)
val CorrectGreenDark = Color(0xFF81C784)
val MismatchRed = Color(0xFFE53935)
val MismatchRedDark = Color(0xFFEF5350)
val PendingYellow = Color(0xFFFFC107)
val PendingYellowDark = Color(0xFFFFD54F)

// Mastery badge colors
val MasteryLearning = Color(0xFF9CA3AF)      // gray
val MasteryFamiliar = Color(0xFF60A5FA)      // blue
val MasteryProficient = Color(0xFF818CF8)    // indigo
val MasteryMastered = Color(0xFFFBBF24)      // gold
