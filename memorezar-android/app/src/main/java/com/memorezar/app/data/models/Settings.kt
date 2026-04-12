package com.memorezar.app.data.models

import com.memorezar.app.core.alert.SoundTheme
import kotlinx.serialization.Serializable

@Serializable
enum class WordVisibility(val displayName: String, val description: String) {
    SHOW_ALL("Show All Words", "All words visible"),
    HIDE_UNTIL_SPOKEN("Hide Until Spoken", "Words appear after speaking"),
    PARTIAL("Partial Reveal", "Show percentage of words")
}

@Serializable
enum class FontSize(val pointSize: Float, val displayName: String) {
    MEDIUM(18f, "Normal"),
    EXTRA_LARGE(28f, "Large")
}

@Serializable
enum class AppTheme(val displayName: String) {
    LIGHT("Light"),
    DARK("Dark")
}

@Serializable
data class AppSettings(
    // Alert settings
    val audioAlertEnabled: Boolean = true,
    val visualAlertEnabled: Boolean = true,
    val hapticAlertEnabled: Boolean = true,
    val soundTheme: SoundTheme = SoundTheme.DEFAULT,

    // Display settings
    val showWordHighlighting: Boolean = true,
    val showProgressBar: Boolean = true,
    val fontSize: FontSize = FontSize.MEDIUM,
    val theme: AppTheme = AppTheme.LIGHT,
    val wordVisibility: WordVisibility = WordVisibility.SHOW_ALL,
    val wordRevealPercentage: Double = 0.0,
    val defaultMemorizationMode: MemorizationMode = MemorizationMode.VOICE,
    val firstLetterModeEnabled: Boolean = false
) {
    companion object {
        val Default = AppSettings()
    }
}
