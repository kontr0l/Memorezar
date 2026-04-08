package com.memorezar.app.data.services

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.memorezar.app.core.alert.SoundTheme
import com.memorezar.app.data.models.SuggestionPack
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "PurchaseService"
private const val INSTALL_DATE_KEY = "memorezar_first_install"

/**
 * Manages Pro subscriptions and feature gating via RevenueCat.
 *
 * NOTE: RevenueCat Android SDK integration is stubbed here.
 * To activate, add the RevenueCat dependency and uncomment the SDK calls.
 * The entitlement/feature gating logic is fully implemented.
 */
@Singleton
class PurchaseService @Inject constructor(
    @ApplicationContext private val appContext: Context
) {
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences("memorezar_purchases", Context.MODE_PRIVATE)

    private val _isPro = MutableStateFlow(false)
    val isPro: StateFlow<Boolean> = _isPro.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    val installDate: Date by lazy {
        val stored = prefs.getLong(INSTALL_DATE_KEY, 0L)
        if (stored > 0) {
            Date(stored)
        } else {
            val now = Date()
            prefs.edit().putLong(INSTALL_DATE_KEY, now.time).apply()
            now
        }
    }

    // Early adopter: currently everyone gets full access
    val isEarlyAdopter: Boolean get() = true  // earlyAdopterCutoff = distantFuture

    val hasFullAccess: Boolean get() = _isPro.value || isEarlyAdopter

    // MARK: - Configuration

    fun configure() {
        // TODO: Initialize RevenueCat SDK
        // Purchases.configure(PurchasesConfiguration.Builder(appContext, RevenueCatConfig.API_KEY).build())
        // refreshCustomerInfo()
        // fetchOfferings()

        // Record install date on first launch
        installDate // triggers lazy init
        Log.d(TAG, "PurchaseService configured, installDate=$installDate")
    }

    // MARK: - User Identity

    fun identifyUser(userId: String) {
        // TODO: Purchases.sharedInstance.logIn(userId) { ... }
        Log.d(TAG, "Identifying user: $userId")
    }

    fun logOutUser() {
        // TODO: Purchases.sharedInstance.logOut()
        _isPro.value = false
        Log.d(TAG, "User logged out from RevenueCat")
    }

    // MARK: - Purchases

    suspend fun purchasePro(activity: Activity) {
        // TODO: Implement RevenueCat purchase flow
        // val offerings = Purchases.sharedInstance.getOfferings()
        // val package = offerings.current?.availablePackages?.firstOrNull()
        // Purchases.sharedInstance.purchase(PurchaseParams.Builder(activity, package).build())
        Log.d(TAG, "Purchase flow not yet implemented")
    }

    suspend fun restorePurchases() {
        // TODO: Purchases.sharedInstance.restorePurchases()
        Log.d(TAG, "Restore purchases not yet implemented")
    }

    // MARK: - Feature Gating

    fun canAddCustomQuote(currentCount: Int): Boolean {
        if (hasFullAccess) return true
        return currentCount < 20
    }

    fun canAddRecording(currentCount: Int): Boolean {
        if (hasFullAccess) return true
        return currentCount < 3
    }

    val canUseTTS: Boolean get() = hasFullAccess

    fun canUseSoundTheme(theme: SoundTheme): Boolean {
        if (hasFullAccess) return true
        return theme == SoundTheme.DEFAULT
    }

    fun canAccessPack(pack: SuggestionPack): Boolean {
        if (hasFullAccess) return true
        return pack.isFree
    }

    // MARK: - Internal

    private fun refreshCustomerInfo() {
        // TODO: Purchases.sharedInstance.getCustomerInfo { info, error ->
        //     _isPro.value = info?.entitlements?.get(RevenueCatConfig.PRO_ENTITLEMENT_ID)?.isActive == true
        // }
    }
}
