package com.memorezar.app.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.Locale

@Serializable
data class SuggestionQuote(
    val title: String,
    val text: String,
    val translations: Map<String, TranslatedQuote>? = null
) {
    fun localizedTitle(lang: String): String =
        translations?.get(lang)?.title ?: title

    fun localizedText(lang: String): String =
        translations?.get(lang)?.text ?: text
}

@Serializable
data class TranslatedPack(
    val name: String,
    val description: String
)

@Serializable
data class SuggestionPack(
    val id: String,
    val name: String,
    val description: String,
    @SerialName("cover_search_query")
    val coverSearchQuery: String,
    @SerialName("cover_url")
    val coverURL: String? = null,
    val version: Int = 1,
    val translations: Map<String, TranslatedPack>? = null,
    @SerialName("is_free")
    val isFree: Boolean = true,
    val quotes: List<SuggestionQuote> = emptyList()
) {
    fun localizedName(lang: String): String =
        translations?.get(lang)?.name ?: name

    fun localizedDescription(lang: String): String =
        translations?.get(lang)?.description ?: description
}

object LanguageHelper {
    val preferredLanguageCode: String
        get() = Locale.getDefault().language
}
