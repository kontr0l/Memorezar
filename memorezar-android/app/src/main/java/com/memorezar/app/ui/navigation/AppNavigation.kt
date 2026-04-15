package com.memorezar.app.ui.navigation

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.memorezar.app.R
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.platform.LocalContext
import com.memorezar.app.core.alert.AlertManager
import com.memorezar.app.data.models.MemorizationMode
import com.memorezar.app.data.models.Quote
import com.memorezar.app.data.models.SuggestionPack
import com.memorezar.app.data.services.AuthService
import com.memorezar.app.data.services.PurchaseService
import com.memorezar.app.data.services.SupportTicketService
import com.memorezar.app.data.storage.QuoteStore
import com.memorezar.app.data.storage.SettingsStore
import com.memorezar.app.data.storage.TutorialStore
import com.memorezar.app.ui.screens.AccuracyDetailScreen
import com.memorezar.app.ui.screens.AuthSheet
import com.memorezar.app.ui.screens.ContactSupportScreen
import com.memorezar.app.ui.screens.HomeScreen
import com.memorezar.app.ui.screens.MasteredQuotesScreen
import com.memorezar.app.ui.screens.OnboardingFlow
import com.memorezar.app.ui.screens.PackDetailScreen
import com.memorezar.app.ui.screens.PackSearchScreen
import com.memorezar.app.ui.screens.PaywallSheet
import com.memorezar.app.ui.screens.QuoteInputSheet
import com.memorezar.app.ui.screens.CategoryDetailScreen
import com.memorezar.app.ui.screens.QuoteLibraryScreen
import com.memorezar.app.ui.screens.RecitationScreen
import com.memorezar.app.data.services.CloudBackupService
import com.memorezar.app.ui.screens.SettingsScreen
import com.memorezar.app.ui.screens.StreakDetailScreen

private data class BottomNavItem(
    val route: String,
    val label: String,
    @DrawableRes val iconRes: Int
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppNavigation(
    quoteStore: QuoteStore,
    settingsStore: SettingsStore,
    tutorialStore: TutorialStore,
    authService: AuthService,
    alertManager: AlertManager,
    purchaseService: PurchaseService,
    supportTicketService: SupportTicketService,
    cloudBackupService: CloudBackupService
) {
    val context = LocalContext.current
    val hasCompletedOnboarding by tutorialStore.hasCompletedOnboarding.collectAsState()

    // Sheet states
    var showQuoteInput by remember { mutableStateOf(false) }
    var quoteInputCategoryId by remember { mutableStateOf<String?>(null) }
    var quoteToEdit by remember { mutableStateOf<Quote?>(null) }
    var showAuthSheet by remember { mutableStateOf(false) }
    var showContactSupport by remember { mutableStateOf(false) }
    var showPaywall by remember { mutableStateOf(false) }

    // Pack detail — hold selected pack in memory to avoid nav-arg serialization
    var selectedPack by remember { mutableStateOf<SuggestionPack?>(null) }
    // Hold all remote packs for search screen
    var allRemotePacks by remember { mutableStateOf<List<SuggestionPack>>(emptyList()) }

    if (!hasCompletedOnboarding) {
        OnboardingFlow(
            quoteStore = quoteStore,
            authService = authService
        ) { mode, firstLetter ->
            val settings = settingsStore.settings.value
            settingsStore.updateSettings(
                settings.copy(
                    defaultMemorizationMode = mode,
                    firstLetterModeEnabled = firstLetter
                )
            )
            tutorialStore.completeOnboarding()
        }
        return
    }

    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    val bottomNavItems = listOf(
        BottomNavItem("home", "Home", R.drawable.icon_home),
        BottomNavItem("library", "Library", R.drawable.icon_library),
        BottomNavItem("settings", "Settings", R.drawable.icon_settings)
    )

    val showBottomBar = currentRoute != null && !currentRoute.startsWith("recitation/")
            && currentRoute != "streak_detail" && currentRoute != "accuracy_detail"
            && currentRoute != "pack_search"
            && currentRoute != "mastered_quotes"

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        bottomBar = {
            if (showBottomBar) {
                androidx.compose.foundation.layout.Column(
                    modifier = Modifier
                        .background(MaterialTheme.colorScheme.surface)
                        // Consume all taps inside the bottom bar so non-icon
                        // areas (padding strip, divider) don't pass clicks through
                        // to content behind the bar.
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null
                        ) { }
                        .windowInsetsPadding(WindowInsets.navigationBars)
                ) {
                    HorizontalDivider()
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Routes that belong to each tab's hierarchy. Bottom-nav icon
                        // stays highlighted and pop-to-root works when the user is
                        // anywhere inside the tab.
                        val homeRoutes = setOf(
                            "home",
                            "pack_detail",
                            "pack_search",
                            "streak_detail",
                            "accuracy_detail",
                            "mastered_quotes"
                        )
                        bottomNavItems.forEach { item ->
                            val selected = when (item.route) {
                                "library" -> currentRoute == "library" ||
                                    currentRoute?.startsWith("category_detail") == true
                                "home" -> currentRoute in homeRoutes
                                else -> navBackStackEntry?.destination?.hierarchy?.any {
                                    it.route == item.route
                                } == true
                            }

                            val interactionSource = remember { MutableInteractionSource() }
                            val isPressed by interactionSource.collectIsPressedAsState()
                            // Subtle press feedback matching iOS Button style — icon dims
                            // near-instantly on touch, then fades back smoothly on release.
                            // No minimum-hold: the instant press-in guarantees the dim is
                            // visible even on quick taps, and a single fade-out prevents
                            // the "double press" look from post-release hold.
                            val pressAlpha by animateFloatAsState(
                                targetValue = if (isPressed) 0.4f else 1f,
                                animationSpec = tween(durationMillis = if (isPressed) 20 else 230),
                                label = "pressAlpha"
                            )
                            val baseAlpha = if (selected) 1f else 0.4f

                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clickable(
                                        interactionSource = interactionSource,
                                        indication = null
                                    ) {
                                        // If we're already inside this tab's hierarchy but not at
                                        // its root (e.g. a category/pack detail), pop back to the
                                        // tab root instead of re-navigating.
                                        if (selected && currentRoute != item.route) {
                                            navController.popBackStack(item.route, false)
                                        } else {
                                            navController.navigate(item.route) {
                                                popUpTo(navController.graph.findStartDestination().id) {
                                                    saveState = true
                                                }
                                                launchSingleTop = true
                                                // Home always starts fresh — don't restore a
                                                // saved sub-route (e.g. pack preview) when the
                                                // user taps Home from another tab.
                                                restoreState = item.route != "home"
                                            }
                                        }
                                    },
                                contentAlignment = Alignment.Center
                            ) {
                                Image(
                                    painter = painterResource(id = item.iconRes),
                                    contentDescription = item.label,
                                    contentScale = ContentScale.Fit,
                                    modifier = Modifier
                                        .height(32.dp)
                                        .alpha(baseAlpha * pressAlpha)
                                )
                            }
                        }
                    }
                }
            }
        }
    ) { padding ->
        // iOS-style navigation transitions: push slides the new screen in from
        // the right; pop slides it back out to the right. Tab switches slide
        // based on the relative tab order so Home→Library→Settings goes right
        // and the reverse goes left (matches how the tabs are laid out).
        val tabOrder = mapOf("home" to 0, "library" to 1, "settings" to 2)
        val slideDuration = 350

        fun AnimatedContentTransitionScope<NavBackStackEntry>.tabDirection(): AnimatedContentTransitionScope.SlideDirection? {
            val fromIdx = tabOrder[initialState.destination.route]
            val toIdx = tabOrder[targetState.destination.route]
            if (fromIdx == null || toIdx == null) return null
            return if (toIdx > fromIdx)
                AnimatedContentTransitionScope.SlideDirection.Left
            else
                AnimatedContentTransitionScope.SlideDirection.Right
        }

        NavHost(
            navController,
            startDestination = "home",
            enterTransition = {
                val dir = tabDirection() ?: AnimatedContentTransitionScope.SlideDirection.Left
                slideIntoContainer(dir, tween(slideDuration))
            },
            exitTransition = {
                val dir = tabDirection() ?: AnimatedContentTransitionScope.SlideDirection.Left
                slideOutOfContainer(dir, tween(slideDuration))
            },
            popEnterTransition = {
                slideIntoContainer(
                    AnimatedContentTransitionScope.SlideDirection.Right,
                    tween(slideDuration)
                )
            },
            popExitTransition = {
                slideOutOfContainer(
                    AnimatedContentTransitionScope.SlideDirection.Right,
                    tween(slideDuration)
                )
            }
        ) {
            composable("home") {
                HomeScreen(
                    onNavigateToRecitation = { navController.navigate("recitation/$it") },
                    onNavigateToQuoteInput = { showQuoteInput = true },
                    tutorialStore = tutorialStore,
                    onNavigateToStreakDetail = { navController.navigate("streak_detail") },
                    onNavigateToAccuracyDetail = { navController.navigate("accuracy_detail") },
                    onNavigateToMasteredQuotes = { navController.navigate("mastered_quotes") },
                    onNavigateToPackDetail = { pack ->
                        selectedPack = pack
                        navController.navigate("pack_detail")
                    },
                    onNavigateToPackSearch = { packs ->
                        allRemotePacks = packs
                        navController.navigate("pack_search")
                    },
                    authService = authService,
                    supportTicketService = supportTicketService,
                    modifier = Modifier.padding(padding)
                )
            }
            composable("library") {
                QuoteLibraryScreen(
                    onNavigateToRecitation = { navController.navigate("recitation/$it") },
                    onNavigateToQuoteInput = { showQuoteInput = true },
                    onNavigateToCategory = { categoryId ->
                        navController.navigate("category_detail/$categoryId")
                    },
                    onNavigateToQuoteInputForCategory = { categoryId ->
                        quoteInputCategoryId = categoryId
                        showQuoteInput = true
                    },
                    onEditQuote = { quote ->
                        quoteToEdit = quote
                        showQuoteInput = true
                    },
                    tutorialStore = tutorialStore,
                    modifier = Modifier.padding(padding)
                )
            }
            composable("category_detail/{categoryId}") { backStackEntry ->
                val categoryId = backStackEntry.arguments?.getString("categoryId") ?: return@composable
                CategoryDetailScreen(
                    categoryId = categoryId,
                    onBack = { navController.popBackStack() },
                    onQuoteClick = { quote -> navController.navigate("recitation/${quote.id}") },
                    onAddQuote = { catId ->
                        quoteInputCategoryId = catId
                        showQuoteInput = true
                    },
                    onEditQuote = { quote ->
                        quoteToEdit = quote
                        showQuoteInput = true
                    }
                )
            }
            composable("settings") {
                SettingsScreen(
                    settingsStore = settingsStore,
                    quoteStore = quoteStore,
                    tutorialStore = tutorialStore,
                    authService = authService,
                    alertManager = alertManager,
                    cloudBackupService = cloudBackupService,
                    onShowAuthSheet = { showAuthSheet = true },
                    onShowContactSupport = { showContactSupport = true },
                    modifier = Modifier.padding(padding)
                )
            }
            composable("recitation/{quoteId}") { backStackEntry ->
                val quoteId = backStackEntry.arguments?.getString("quoteId") ?: return@composable
                RecitationScreen(
                    quoteId = quoteId,
                    quoteStore = quoteStore,
                    settingsStore = settingsStore,
                    authService = authService,
                    onShowAuthSheet = { showAuthSheet = true },
                    onBack = { navController.popBackStack() }
                )
            }
            composable("streak_detail") {
                StreakDetailScreen(
                    quoteStore = quoteStore,
                    onBack = { navController.popBackStack() },
                    bottomNavHeight = padding.calculateBottomPadding()
                )
            }
            composable("accuracy_detail") {
                AccuracyDetailScreen(
                    quoteStore = quoteStore,
                    onBack = { navController.popBackStack() },
                    bottomNavHeight = padding.calculateBottomPadding()
                )
            }
            composable("mastered_quotes") {
                MasteredQuotesScreen(
                    quoteStore = quoteStore,
                    onBack = { navController.popBackStack() },
                    onNavigateToRecitation = { navController.navigate("recitation/$it") },
                    bottomNavHeight = padding.calculateBottomPadding()
                )
            }
            composable("pack_detail") {
                val pack = selectedPack
                if (pack != null) {
                    var isAdded by remember { mutableStateOf(false) }
                    LaunchedEffect(pack.id) {
                        isAdded = quoteStore.isPackAdded(pack.id)
                    }
                    PackDetailScreen(
                        pack = pack,
                        isAdded = isAdded,
                        isPro = purchaseService.hasFullAccess,
                        bottomNavHeight = padding.calculateBottomPadding(),
                        onAddToLibrary = { p ->
                            quoteStore.addSuggestionPack(p)
                            // Pop pack_detail off the stack first, then switch to Library tab
                            navController.popBackStack("home", inclusive = false)
                            navController.navigate("library") {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = false
                            }
                        },
                        onShowPaywall = { showPaywall = true },
                        onBack = { navController.popBackStack() }
                    )
                }
            }
            composable("pack_search") {
                PackSearchScreen(
                    packs = allRemotePacks,
                    onNavigateToPackDetail = { pack ->
                        selectedPack = pack
                        navController.navigate("pack_detail")
                    },
                    onBack = { navController.popBackStack() }
                )
            }
        }
    }

    // Bottom sheets / modals
    if (showQuoteInput) {
        ModalBottomSheet(
            onDismissRequest = {
                showQuoteInput = false
                quoteInputCategoryId = null
                quoteToEdit = null
            },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            dragHandle = null
        ) {
            QuoteInputSheet(
                quoteStore = quoteStore,
                editQuote = quoteToEdit,
                initialCategoryId = quoteInputCategoryId,
                onDismiss = {
                    showQuoteInput = false
                    quoteInputCategoryId = null
                    quoteToEdit = null
                }
            )
        }
    }

    if (showAuthSheet) {
        ModalBottomSheet(
            onDismissRequest = { showAuthSheet = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ) {
            AuthSheet(
                authService = authService,
                onDismiss = { showAuthSheet = false },
                onGoogleSignIn = {
                    val url = authService.getGoogleOAuthURL()
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    context.startActivity(intent)
                }
            )
        }
    }

    if (showContactSupport) {
        ModalBottomSheet(
            onDismissRequest = { showContactSupport = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            dragHandle = null
        ) {
            ContactSupportScreen(
                authService = authService,
                supportTicketService = supportTicketService,
                onDismiss = { showContactSupport = false }
            )
        }
    }

    if (showPaywall) {
        ModalBottomSheet(
            onDismissRequest = { showPaywall = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ) {
            PaywallSheet(
                purchaseService = purchaseService,
                onDismiss = { showPaywall = false }
            )
        }
    }
}
