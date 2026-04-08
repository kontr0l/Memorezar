package com.memorezar.app.ui.viewmodels

import androidx.lifecycle.ViewModel
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.models.QuoteCategory
import com.memorezar.app.data.services.UnsplashImageInfo
import com.memorezar.app.data.services.UnsplashService
import com.memorezar.app.data.storage.QuoteStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

@HiltViewModel
class LibraryViewModel @Inject constructor(
    val quoteStore: QuoteStore,
    val unsplashService: UnsplashService
) : ViewModel() {

    val categories: StateFlow<List<QuoteCategory>> = quoteStore.categories
    val quotes: StateFlow<List<Quote>> = quoteStore.quotes

    fun quotesInCategory(categoryId: String): List<Quote> = quoteStore.quotesInCategory(categoryId)

    fun addQuote(quote: Quote) = quoteStore.addQuote(quote)
    fun updateQuote(quote: Quote) = quoteStore.updateQuote(quote)
    fun deleteQuote(quote: Quote) = quoteStore.deleteQuote(quote)

    fun addCategory(category: QuoteCategory) = quoteStore.addCategory(category)
    fun updateCategory(category: QuoteCategory) = quoteStore.updateCategory(category)
    fun deleteCategory(category: QuoteCategory) = quoteStore.deleteCategory(category)

    fun nextGradientIndex(): Int = quoteStore.nextAvailableGradientIndex()
}
