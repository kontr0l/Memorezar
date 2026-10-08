import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
    alias(libs.plugins.triplet.play)
}

// Release signing credentials come from local.properties (gitignored) so keystore
// passwords never land in the repo. Required keys:
//   MEMOREZAR_KEYSTORE_FILE     = absolute path to the .jks
//   MEMOREZAR_KEYSTORE_PASSWORD = store password
//   MEMOREZAR_KEY_ALIAS         = key alias inside the store
//   MEMOREZAR_KEY_PASSWORD      = key password
val keystoreProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseSigning = listOf(
    "MEMOREZAR_KEYSTORE_FILE",
    "MEMOREZAR_KEYSTORE_PASSWORD",
    "MEMOREZAR_KEY_ALIAS",
    "MEMOREZAR_KEY_PASSWORD",
).all { keystoreProps.getProperty(it)?.isNotBlank() == true }

// Play Store publishing credentials, same gitignored source as the keystore:
//   MEMOREZAR_PLAY_CREDENTIALS = absolute path to the service-account JSON
// The service account needs "Release to production" + "Manage production
// releases" granted on this app in Play Console → Users and permissions.
// Without the property the plugin still loads; only the publish tasks fail.
val playCredentialsPath: String? = keystoreProps.getProperty("MEMOREZAR_PLAY_CREDENTIALS")
    ?.takeIf { it.isNotBlank() }

play {
    playCredentialsPath?.let { serviceAccountCredentials.set(file(it)) }
    track.set("production")
    // COMPLETED = 100% rollout rather than staged. Every new install currently
    // hits the onboarding lockout (KNOWN_ISSUES TUTORIAL-002), so a staged
    // rollout would knowingly leave a slice of users stranded.
    releaseStatus.set(com.github.triplet.gradle.androidpublisher.ReleaseStatus.COMPLETED)
    defaultToAppBundles.set(true)
}

android {
    namespace = "com.memorezar.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.memorezar.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 4
        versionName = "1.3"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProps.getProperty("MEMOREZAR_KEYSTORE_FILE"))
                storePassword = keystoreProps.getProperty("MEMOREZAR_KEYSTORE_PASSWORD")
                keyAlias = keystoreProps.getProperty("MEMOREZAR_KEY_ALIAS")
                keyPassword = keystoreProps.getProperty("MEMOREZAR_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    // Compose BOM
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    implementation(libs.compose.animation)
    debugImplementation(libs.compose.ui.tooling)

    // AndroidX
    implementation(libs.activity.compose)
    implementation(libs.core.ktx)
    implementation(libs.lifecycle.runtime)
    implementation(libs.lifecycle.viewmodel)
    implementation(libs.navigation.compose)
    implementation(libs.datastore.preferences)
    implementation(libs.security.crypto)
    implementation("androidx.browser:browser:1.8.0")

    // Hilt DI
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)

    // Ktor HTTP client
    implementation(libs.ktor.client.core)
    implementation(libs.ktor.client.okhttp)
    implementation(libs.ktor.client.content.negotiation)
    implementation(libs.ktor.serialization.json)

    // Serialization
    implementation(libs.kotlinx.serialization.json)

    // Coroutines
    implementation(libs.kotlinx.coroutines.android)

    // Image loading
    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)

    // Testing
    testImplementation(libs.junit)
    testImplementation(libs.kotlin.test)
}
