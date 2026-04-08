package com.memorezar.app.data.models

data class TipDefinition(
    val id: String,
    val content: String,
    val requiredTipId: String? = null
) {
    companion object {
        val addOwnQuote = TipDefinition("tip.addOwnQuote", "Add your\nown quote")
        val addCategory = TipDefinition("tip.addCategory", "Add your own\ncategory")
        val browsePacks = TipDefinition("tip.browsePacks", "Explore curated packs\nof quotes to add\nto your library", requiredTipId = "tip.addOwnQuote")
        val splitLongQuote = TipDefinition("tip.splitLongQuote", "Try splitting into smaller chunks")
        val recitationIntro = TipDefinition("tip.recitationIntro", "")
    }
}
