import SwiftUI
import AuthenticationServices
import CryptoKit

/// Authentication sheet with Apple, Google, and email sign-in
struct AuthSheet: View {
    /// Email/password signup is hidden for v1 launch — Supabase's default SMTP is
    /// rate-limited and unreliable. Flip to `true` once custom SMTP is configured.
    static let emailAuthEnabled = false

    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentNonce: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.indigo)
                        Text(isSignUp ? String(localized: "Create Account") : String(localized: "Sign In"))
                            .font(.title2.bold())
                        Text("Sign in to share recordings with the community")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // Apple Sign-In
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)

                    // Google Sign-In
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 10) {
                            GoogleGLogo(size: 20)
                            Text("Sign in with Google")
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    // Email form hidden for v1 launch — custom SMTP not yet configured.
                    // Re-enable by flipping `emailAuthEnabled` to true.
                    if Self.emailAuthEnabled {
                        // Divider
                        HStack {
                            Rectangle().frame(height: 1).foregroundColor(Color(.separator))
                            Text("or").font(.footnote).foregroundColor(.secondary)
                            Rectangle().frame(height: 1).foregroundColor(Color(.separator))
                        }

                        // Email form
                        VStack(spacing: 12) {
                            if isSignUp {
                                TextField("Name", text: $displayName)
                                    .textContentType(.name)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                            }

                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)

                            SecureField("Password", text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                        }

                        // Error message
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        // Submit button
                        Button {
                            isSignUp ? signUp() : signInWithEmail()
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? String(localized: "Create Account") : String(localized: "Sign In"))
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty || (isSignUp && displayName.isEmpty))

                        // Toggle sign-in / sign-up
                        Button {
                            withAnimation { isSignUp.toggle() }
                            errorMessage = nil
                        } label: {
                            Text(isSignUp ? String(localized: "Already have an account? Sign In") : String(localized: "Don't have an account? Sign Up"))
                                .font(.footnote)
                                .foregroundColor(.indigo)
                        }
                    } else if let errorMessage {
                        // Preserve error display when email flow is off (e.g. OAuth failures)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .disabled(isLoading)
            .onChange(of: authService.isSignedIn) { _, signedIn in
                if signedIn { dismiss() }
            }
        }
    }

    // MARK: - Email Actions

    private func signInWithEmail() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authService.signInWithEmail(email: email, password: password)
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func signUp() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authService.signUpWithEmail(email: email, password: password, name: displayName)
            } catch AuthError.confirmationRequired {
                await MainActor.run {
                    errorMessage = String(localized: "Check your email to confirm your account, then sign in.")
                    isSignUp = false
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Apple Sign-In

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                errorMessage = String(localized: "Could not get Apple ID token.")
                return
            }
            isLoading = true
            errorMessage = nil
            Task {
                do {
                    try await authService.signInWithApple(idToken: tokenString, nonce: currentNonce)
                } catch {
                    await MainActor.run { errorMessage = error.localizedDescription }
                }
                await MainActor.run { isLoading = false }
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Google Sign-In

    private func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                guard let scene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = await scene.windows.first else {
                    throw AuthError.networkError
                }
                try await authService.signInWithGoogle(anchor: window)
            } catch AuthError.cancelled {
                // User cancelled — no error
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce: \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Google G Logo

/// Simple branded "G" in Google's primary blue. Swap for the official
/// multi-color PNG (Assets.xcassets/GoogleG.imageset) when you're ready.
struct GoogleGLogo: View {
    var size: CGFloat = 20

    var body: some View {
        Text("G")
            .font(.system(size: size * 1.1, weight: .bold, design: .default))
            .foregroundColor(Color(red: 66/255, green: 133/255, blue: 244/255))
            .frame(width: size, height: size)
    }
}
