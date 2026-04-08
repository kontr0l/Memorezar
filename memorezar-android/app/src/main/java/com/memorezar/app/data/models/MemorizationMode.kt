package com.memorezar.app.data.models

import kotlinx.serialization.Serializable

@Serializable
enum class MemorizationMode(val displayName: String, val icon: String) {
    VOICE("Voice", "mic"),
    FIRST_LETTER("First Letter", "text_format"),
    MULTIPLE_CHOICE("Multiple Choice", "grid_view"),
    TYPING("Typing", "keyboard"),
    AUDIO("Audio", "music_note");

    companion object {
        val settingsOptions = listOf(VOICE, TYPING, MULTIPLE_CHOICE, AUDIO)
    }
}
