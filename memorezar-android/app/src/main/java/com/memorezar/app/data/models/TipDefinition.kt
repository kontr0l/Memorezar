package com.memorezar.app.data.models

import androidx.annotation.StringRes
import com.memorezar.app.R

data class TipDefinition(
    val id: String,
    @StringRes val contentRes: Int,
    val requiredTipId: String? = null
) {
    companion object {
        val addOwnQuote = TipDefinition("tip.addOwnQuote", R.string.tip_add_own_quote)
        val addCategory = TipDefinition("tip.addCategory", R.string.tip_add_category)
        val browsePacks = TipDefinition("tip.browsePacks", R.string.tip_browse_packs, requiredTipId = "tip.addOwnQuote")
        val splitLongQuote = TipDefinition("tip.splitLongQuote", R.string.tip_split_long_quote)
        val recitationIntro = TipDefinition("tip.recitationIntro", 0)
    }
}
