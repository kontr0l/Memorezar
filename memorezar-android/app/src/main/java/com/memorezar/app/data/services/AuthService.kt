package com.memorezar.app.data.services

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.memorezar.app.data.models.AuthUser
import dagger.hilt.android.qualifiers.ApplicationContext
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.get
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "AuthService"
private const val REFRESH_INTERVAL_MS = 50 * 60 * 1000L // 50 minutes

@Singleton
class AuthService @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val httpClient: HttpClient
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val json = Json { ignoreUnknownKeys = true }

    private val _currentUser = MutableStateFlow<AuthUser?>(null)
    val currentUser: StateFlow<AuthUser?> = _currentUser.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    val isSignedIn: Boolean get() = _currentUser.value != null

    val accessToken: String? get() = securePrefs.getString("access_token", null)
    private val refreshToken: String? get() = securePrefs.getString("refresh_token", null)

    private var refreshJob: Job? = null

    // Encrypted storage (replaces iOS Keychain)
    private val securePrefs: SharedPreferences by lazy {
        val masterKey = MasterKey.Builder(appContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        try {
            EncryptedSharedPreferences.create(
                appContext,
                "memorezar_secure_prefs",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (_: Exception) {
            // Corrupted prefs (e.g. after uninstall/reinstall with stale KeyStore key)
            appContext.getSharedPreferences("memorezar_secure_prefs", Context.MODE_PRIVATE).edit().clear().apply()
            val prefsFile = java.io.File(appContext.filesDir.parent, "shared_prefs/memorezar_secure_prefs.xml")
            prefsFile.delete()
            EncryptedSharedPreferences.create(
                appContext,
                "memorezar_secure_prefs",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        }
    }

    // MARK: - Session Restore

    fun restoreSession() {
        val token = accessToken ?: return
        val userData = securePrefs.getString("user_data", null)
        if (userData != null) {
            try {
                _currentUser.value = json.decodeFromString<AuthUser>(userData)
                startRefreshTimer()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to decode stored user: ${e.message}")
            }
        }
        // Silently refresh
        scope.launch { refreshTokenIfNeeded() }
    }

    // MARK: - Email/Password

    suspend fun signUpWithEmail(email: String, password: String, name: String) {
        _isLoading.value = true
        _errorMessage.value = null
        try {
            val response: HttpResponse = httpClient.post("${SupabaseConfig.PROJECT_URL}/auth/v1/signup") {
                header("apikey", SupabaseConfig.ANON_KEY)
                contentType(ContentType.Application.Json)
                setBody("""{"email":"$email","password":"$password","data":{"display_name":"$name"}}""")
            }
            if (response.status.isSuccess()) {
                val body: String = response.body()
                val jsonObj = json.parseToJsonElement(body).jsonObject
                if (jsonObj.containsKey("access_token")) {
                    handleAuthResponse(jsonObj, displayName = name)
                } else {
                    throw AuthError.ConfirmationRequired
                }
            } else {
                val errorMsg = parseErrorMessage(response) ?: "Sign up failed"
                throw AuthError.ServerError(errorMsg)
            }
        } catch (e: AuthError) {
            _errorMessage.value = e.message
            throw e
        } catch (e: Exception) {
            _errorMessage.value = "Network error. Check your connection."
            throw AuthError.NetworkError
        } finally {
            _isLoading.value = false
        }
    }

    suspend fun signInWithEmail(email: String, password: String) {
        _isLoading.value = true
        _errorMessage.value = null
        try {
            val response: HttpResponse = httpClient.post(
                "${SupabaseConfig.PROJECT_URL}/auth/v1/token?grant_type=password"
            ) {
                header("apikey", SupabaseConfig.ANON_KEY)
                contentType(ContentType.Application.Json)
                setBody("""{"email":"$email","password":"$password"}""")
            }
            if (response.status.isSuccess()) {
                val body: String = response.body()
                handleAuthResponse(json.parseToJsonElement(body).jsonObject)
            } else {
                val errorMsg = parseErrorMessage(response) ?: "Invalid email or password"
                throw AuthError.ServerError(errorMsg)
            }
        } catch (e: AuthError) {
            _errorMessage.value = e.message
            throw e
        } catch (e: Exception) {
            _errorMessage.value = "Network error. Check your connection."
            throw AuthError.NetworkError
        } finally {
            _isLoading.value = false
        }
    }

    // MARK: - Apple Sign-In (via Supabase id_token)

    suspend fun signInWithApple(idToken: String, nonce: String?) {
        _isLoading.value = true
        _errorMessage.value = null
        try {
            val bodyStr = buildString {
                append("""{"provider":"apple","id_token":"$idToken"""")
                if (nonce != null) append(""","nonce":"$nonce"""")
                append("}")
            }
            val response: HttpResponse = httpClient.post(
                "${SupabaseConfig.PROJECT_URL}/auth/v1/token?grant_type=id_token"
            ) {
                header("apikey", SupabaseConfig.ANON_KEY)
                contentType(ContentType.Application.Json)
                setBody(bodyStr)
            }
            if (response.status.isSuccess()) {
                val body: String = response.body()
                handleAuthResponse(json.parseToJsonElement(body).jsonObject)
            } else {
                val errorMsg = parseErrorMessage(response) ?: "Apple sign-in failed"
                throw AuthError.ServerError(errorMsg)
            }
        } catch (e: AuthError) {
            _errorMessage.value = e.message
            throw e
        } catch (e: Exception) {
            _errorMessage.value = "Network error. Check your connection."
            throw AuthError.NetworkError
        } finally {
            _isLoading.value = false
        }
    }

    // MARK: - Google Sign-In (via OAuth redirect)
    // On Android, Google Sign-In uses Credential Manager.
    // The callback URL fragment parsing is the same.

    suspend fun handleOAuthCallback(fragment: String) {
        val params = mutableMapOf<String, String>()
        for (pair in fragment.split("&")) {
            val parts = pair.split("=", limit = 2)
            if (parts.size == 2) {
                params[parts[0]] = java.net.URLDecoder.decode(parts[1], "UTF-8")
            }
        }

        val token = params["access_token"] ?: throw AuthError.InvalidResponse
        val refresh = params["refresh_token"] ?: throw AuthError.InvalidResponse

        securePrefs.edit()
            .putString("access_token", token)
            .putString("refresh_token", refresh)
            .apply()

        val user = fetchUser(token)
        _currentUser.value = user
        saveUserData(user)
        startRefreshTimer()
    }

    fun getGoogleOAuthURL(): String {
        val redirectURI = "com.memorezar.app://callback"
        return "${SupabaseConfig.PROJECT_URL}/auth/v1/authorize?provider=google&redirect_to=$redirectURI"
    }

    // MARK: - Sign Out

    fun signOut() {
        securePrefs.edit()
            .remove("access_token")
            .remove("refresh_token")
            .remove("user_data")
            .apply()
        refreshJob?.cancel()
        refreshJob = null
        _currentUser.value = null
        _errorMessage.value = null
    }

    // MARK: - Token Refresh

    suspend fun refreshTokenIfNeeded() {
        val token = refreshToken ?: return
        try {
            val response: HttpResponse = httpClient.post(
                "${SupabaseConfig.PROJECT_URL}/auth/v1/token?grant_type=refresh_token"
            ) {
                header("apikey", SupabaseConfig.ANON_KEY)
                contentType(ContentType.Application.Json)
                setBody("""{"refresh_token":"$token"}""")
            }
            if (response.status.isSuccess()) {
                val body: String = response.body()
                handleAuthResponse(json.parseToJsonElement(body).jsonObject)
            } else {
                // Refresh failed — sign out
                signOut()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Token refresh failed: ${e.message}")
        }
    }

    // MARK: - Account Deletion

    /**
     * Calls the `delete-user-account` Edge Function with the current user's
     * JWT. Returns null on success, an error string on failure. The function
     * cascade-deletes recordings (rows + audio files), user_backups,
     * support_tickets, and the auth.users row.
     */
    suspend fun deleteAccountOnServer(): String? {
        val token = accessToken ?: return "Not signed in"
        return try {
            val response: HttpResponse = httpClient.post(
                "${SupabaseConfig.PROJECT_URL}/functions/v1/delete-user-account"
            ) {
                header("apikey", SupabaseConfig.ANON_KEY)
                header("Authorization", "Bearer $token")
                contentType(ContentType.Application.Json)
                setBody("{}")
            }
            if (response.status.isSuccess()) {
                null
            } else {
                val body: String = try { response.body() } catch (_: Exception) { "" }
                "HTTP ${response.status.value}: $body"
            }
        } catch (e: Exception) {
            e.message ?: "Unknown error"
        }
    }

    // MARK: - Helpers

    /** Build standard Supabase headers with current auth token. */
    fun headers(): Map<String, String> {
        val token = accessToken ?: SupabaseConfig.ANON_KEY
        return mapOf(
            "apikey" to SupabaseConfig.ANON_KEY,
            "Authorization" to "Bearer $token",
            "Content-Type" to "application/json"
        )
    }

    private fun handleAuthResponse(jsonObj: JsonObject, displayName: String? = null) {
        val tokenStr = jsonObj["access_token"]?.jsonPrimitive?.content ?: throw AuthError.InvalidResponse
        val refreshStr = jsonObj["refresh_token"]?.jsonPrimitive?.content ?: throw AuthError.InvalidResponse

        securePrefs.edit()
            .putString("access_token", tokenStr)
            .putString("refresh_token", refreshStr)
            .apply()

        val userObj = jsonObj["user"]?.jsonObject
        val userId = userObj?.get("id")?.jsonPrimitive?.content ?: ""
        val email = userObj?.get("email")?.jsonPrimitive?.content
        val meta = userObj?.get("user_metadata")?.jsonObject
        val name = displayName
            ?: meta?.get("display_name")?.jsonPrimitive?.content
            ?: meta?.get("full_name")?.jsonPrimitive?.content
            ?: meta?.get("name")?.jsonPrimitive?.content

        val user = AuthUser(id = userId, email = email, displayName = name)
        saveUserData(user)
        _currentUser.value = user
        startRefreshTimer()
    }

    private suspend fun fetchUser(accessToken: String): AuthUser {
        val response: HttpResponse = httpClient.get("${SupabaseConfig.PROJECT_URL}/auth/v1/user") {
            header("apikey", SupabaseConfig.ANON_KEY)
            header("Authorization", "Bearer $accessToken")
        }
        if (!response.status.isSuccess()) throw AuthError.InvalidResponse

        val body: String = response.body()
        val jsonObj = json.parseToJsonElement(body).jsonObject
        val userId = jsonObj["id"]?.jsonPrimitive?.content ?: ""
        val email = jsonObj["email"]?.jsonPrimitive?.content
        val meta = jsonObj["user_metadata"]?.jsonObject
        val name = meta?.get("display_name")?.jsonPrimitive?.content
            ?: meta?.get("full_name")?.jsonPrimitive?.content
            ?: meta?.get("name")?.jsonPrimitive?.content

        return AuthUser(id = userId, email = email, displayName = name)
    }

    private fun saveUserData(user: AuthUser) {
        val encoded = json.encodeToString(AuthUser.serializer(), user)
        securePrefs.edit().putString("user_data", encoded).apply()
    }

    private fun startRefreshTimer() {
        refreshJob?.cancel()
        refreshJob = scope.launch {
            while (true) {
                delay(REFRESH_INTERVAL_MS)
                refreshTokenIfNeeded()
            }
        }
    }

    private suspend fun parseErrorMessage(response: HttpResponse): String? {
        return try {
            val body: String = response.body()
            val obj = json.parseToJsonElement(body).jsonObject
            obj["msg"]?.jsonPrimitive?.content
                ?: obj["error_description"]?.jsonPrimitive?.content
        } catch (_: Exception) {
            null
        }
    }
}

// MARK: - Errors

sealed class AuthError(override val message: String) : Exception(message) {
    object NetworkError : AuthError("Network error. Check your connection.")
    object InvalidResponse : AuthError("Unexpected server response.")
    data class ServerError(val msg: String) : AuthError(msg)
    object ConfirmationRequired : AuthError("Check your email to confirm your account.")
    object Cancelled : AuthError("Sign-in was cancelled.")
}
