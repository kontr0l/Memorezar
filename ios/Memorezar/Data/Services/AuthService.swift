import Foundation
import AuthenticationServices
import Combine

/// Handles authentication with Supabase via Apple, Google, and email/password
class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: AuthUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    var isSignedIn: Bool { currentUser != nil }

    var accessToken: String? {
        KeychainHelper.loadString(key: "access_token")
    }

    private var refreshToken: String? {
        KeychainHelper.loadString(key: "refresh_token")
    }

    private var refreshTimer: Timer?
    private let session = URLSession.shared

    private override init() {
        super.init()
    }

    // MARK: - Session Restore

    func restoreSession() {
        guard let accessToken = accessToken else { return }

        // Decode user from stored data
        if let userData = KeychainHelper.load(key: "user_data"),
           let user = try? JSONDecoder().decode(AuthUser.self, from: userData) {
            currentUser = user
            startRefreshTimer()

            // Silently refresh if token might be stale
            Task {
                await refreshTokenIfNeeded()
            }
        } else {
            // Have token but no user data — try to refresh
            Task {
                await refreshTokenIfNeeded()
            }
        }
    }

    // MARK: - Email/Password

    func signUpWithEmail(email: String, password: String, name: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": ["display_name": name]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            // Some Supabase configs require email confirmation
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let accessToken = json?["access_token"] as? String {
                try handleAuthResponse(json: json!, displayName: name)
            } else {
                // Email confirmation required
                throw AuthError.confirmationRequired
            }
        } else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = errorJson?["msg"] as? String
                ?? errorJson?["error_description"] as? String
                ?? "Sign up failed"
            throw AuthError.serverError(msg)
        }
    }

    func signInWithEmail(email: String, password: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        if (200...299).contains(httpResponse.statusCode) {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AuthError.invalidResponse
            }
            try handleAuthResponse(json: json)
        } else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = errorJson?["msg"] as? String
                ?? errorJson?["error_description"] as? String
                ?? "Invalid email or password"
            throw AuthError.serverError(msg)
        }
    }

    // MARK: - Apple Sign-In

    func signInWithApple(idToken: String, nonce: String?) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=id_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = [
            "provider": "apple",
            "id_token": idToken
        ]
        if let nonce = nonce {
            body["nonce"] = nonce
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        if (200...299).contains(httpResponse.statusCode) {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AuthError.invalidResponse
            }
            try handleAuthResponse(json: json)
        } else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = errorJson?["msg"] as? String
                ?? errorJson?["error_description"] as? String
                ?? "Apple sign-in failed"
            throw AuthError.serverError(msg)
        }
    }

    // MARK: - Google Sign-In (via ASWebAuthenticationSession)

    @MainActor
    func signInWithGoogle(anchor: ASPresentationAnchor) async throws {
        let redirectURI = "com.memorezar.app://callback"
        let authURL = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/authorize?provider=google&redirect_to=\(redirectURI)")!

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.memorezar.app"
            ) { url, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: AuthError.networkError)
                    }
                    return
                }
                guard let url = url else {
                    continuation.resume(throwing: AuthError.invalidResponse)
                    return
                }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        // Parse tokens from callback URL fragment (Supabase returns them in the hash)
        guard let fragment = callbackURL.fragment else {
            throw AuthError.invalidResponse
        }

        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                params[String(parts[0])] = String(parts[1]).removingPercentEncoding ?? String(parts[1])
            }
        }

        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else {
            throw AuthError.invalidResponse
        }

        // Store tokens
        KeychainHelper.save(key: "access_token", string: accessToken)
        KeychainHelper.save(key: "refresh_token", string: refreshToken)

        // Fetch user info from the token
        let user = try await fetchUser(accessToken: accessToken)
        await MainActor.run {
            self.currentUser = user
            self.startRefreshTimer()
        }
        if let userData = try? JSONEncoder().encode(user) {
            KeychainHelper.save(key: "user_data", data: userData)
        }
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainHelper.delete(key: "access_token")
        KeychainHelper.delete(key: "refresh_token")
        KeychainHelper.delete(key: "user_data")
        refreshTimer?.invalidate()
        refreshTimer = nil
        currentUser = nil
        errorMessage = nil
    }

    // MARK: - Token Refresh

    func refreshTokenIfNeeded() async {
        guard let refreshToken = refreshToken else { return }

        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["refresh_token": refreshToken]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // Refresh failed — sign out
                await MainActor.run { self.signOut() }
                return
            }
            try handleAuthResponse(json: json)
        } catch {
            print("[AuthService] Token refresh failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func handleAuthResponse(json: [String: Any], displayName: String? = nil) throws {
        guard let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String else {
            throw AuthError.invalidResponse
        }

        KeychainHelper.save(key: "access_token", string: accessToken)
        KeychainHelper.save(key: "refresh_token", string: refreshToken)

        // Extract user from response
        let userJson = json["user"] as? [String: Any]
        let userId = userJson?["id"] as? String ?? ""
        let email = userJson?["email"] as? String
        let userMeta = userJson?["user_metadata"] as? [String: Any]
        let name = displayName
            ?? userMeta?["display_name"] as? String
            ?? userMeta?["full_name"] as? String
            ?? userMeta?["name"] as? String

        let user = AuthUser(id: userId, email: email, displayName: name)

        if let userData = try? JSONEncoder().encode(user) {
            KeychainHelper.save(key: "user_data", data: userData)
        }

        DispatchQueue.main.async {
            self.currentUser = user
            self.startRefreshTimer()
        }
    }

    private func fetchUser(accessToken: String) async throws -> AuthUser {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/user")!
        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.invalidResponse
        }

        let userId = json["id"] as? String ?? ""
        let email = json["email"] as? String
        let userMeta = json["user_metadata"] as? [String: Any]
        let name = userMeta?["display_name"] as? String
            ?? userMeta?["full_name"] as? String
            ?? userMeta?["name"] as? String

        return AuthUser(id: userId, email: email, displayName: name)
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        // Refresh every 50 minutes (Supabase tokens expire in 1 hour)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 50 * 60, repeats: true) { [weak self] _ in
            Task { await self?.refreshTokenIfNeeded() }
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case networkError
    case invalidResponse
    case serverError(String)
    case confirmationRequired
    case cancelled

    var errorDescription: String? {
        switch self {
        case .networkError: return "Network error. Check your connection."
        case .invalidResponse: return "Unexpected server response."
        case .serverError(let msg): return msg
        case .confirmationRequired: return "Check your email to confirm your account."
        case .cancelled: return nil
        }
    }
}
