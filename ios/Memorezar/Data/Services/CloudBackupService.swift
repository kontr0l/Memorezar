import Foundation
import Combine

/// Backs up all user data to Supabase as a single JSONB snapshot
/// and restores it on a new device when the user signs in.
final class CloudBackupService: ObservableObject {
    static let shared = CloudBackupService()

    // MARK: - Published State

    enum BackupState: Equatable {
        case idle
        case backingUp
        case restoring
        case error(String)
    }

    @Published var backupState: BackupState = .idle
    @Published var lastBackupDate: Date?
    @Published var cloudBackupExists = false

    /// The cloud backup metadata, populated after sign-in check.
    var cloudBackupDate: Date?

    // MARK: - Private

    /// Prevents backup from re-triggering during a restore.
    private(set) var isRestoring = false

    private var debounceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let lastBackupKey = "memorezar_last_backup_date"
    private let session = URLSession.shared

    // MARK: - Weak references to stores (set during app init)

    weak var quoteStore: QuoteStore?
    weak var settingsStore: SettingsStore?
    weak var userEquivalencesStore: UserEquivalencesStore?
    weak var tutorialStore: TutorialStore?

    private init() {
        // Restore last backup date
        if let interval = UserDefaults.standard.object(forKey: lastBackupKey) as? Double {
            lastBackupDate = Date(timeIntervalSince1970: interval)
        }

        // Observe sign-in events
        AuthService.shared.$currentUser
            .dropFirst() // skip initial nil
            .removeDuplicates(by: { $0?.id == $1?.id })
            .sink { [weak self] user in
                guard let self, user != nil else { return }
                Task { await self.onSignIn() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Schedule Backup (called by stores)

    /// Debounced backup trigger. Waits 5 seconds after the last call before uploading.
    func scheduleBackup() {
        guard AuthService.shared.isSignedIn, !isRestoring else { return }

        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            guard !Task.isCancelled, let self else { return }
            await self.performBackup()
        }
    }

    // MARK: - Backup

    @MainActor
    func performBackup() async {
        guard AuthService.shared.isSignedIn else { return }
        guard let quoteStore, let settingsStore,
              let userEquivalencesStore, let tutorialStore else {
            print("[CloudBackup] Stores not wired — skipping backup")
            return
        }

        backupState = .backingUp

        do {
            // 1. Upload category images
            let imageManifest = await uploadCategoryImages(categories: quoteStore.categories)

            // 2. Build payload
            let payload = BackupPayload(
                backupVersion: BackupPayload.currentVersion,
                createdAt: Date(),
                quotes: quoteStore.quotes,
                sessions: quoteStore.sessions,
                categories: quoteStore.categories,
                packVersions: quoteStore.installedPackVersions,
                settings: settingsStore.settings,
                userEquivalences: userEquivalencesStore.equivalences.mapValues { Array($0) },
                completedTips: Array(tutorialStore.completedTips),
                hasCompletedOnboarding: tutorialStore.hasCompletedOnboarding,
                categoryImageManifest: imageManifest
            )

            // 3. Encode
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let payloadData = try encoder.encode(payload)

            // 4. UPSERT to Supabase
            try await upsertBackup(payloadData)

            lastBackupDate = Date()
            cloudBackupExists = true
            UserDefaults.standard.set(lastBackupDate!.timeIntervalSince1970, forKey: lastBackupKey)
            backupState = .idle
            print("[CloudBackup] Backup complete")
        } catch {
            print("[CloudBackup] Backup failed: \(error.localizedDescription)")
            backupState = .error(error.localizedDescription)
        }
    }

    // MARK: - Restore

    /// Check if a cloud backup exists for the current user.
    func checkForCloudBackup() async -> Bool {
        guard let token = AuthService.shared.accessToken else { return false }

        var urlComponents = URLComponents(url: SupabaseConfig.userBackupsURL, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "select", value: "updated_at"),
            URLQueryItem(name: "user_id", value: "eq.\(AuthService.shared.currentUser?.id ?? "")")
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        applyHeaders(&request, token: token)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            let rows = try JSONDecoder().decode([[String: String]].self, from: data)
            if let dateStr = rows.first?["updated_at"] {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                cloudBackupDate = formatter.date(from: dateStr)
            }
            let exists = !rows.isEmpty
            await MainActor.run { cloudBackupExists = exists }
            return exists
        } catch {
            print("[CloudBackup] Check failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Download and decode the cloud backup.
    func fetchBackupPayload() async throws -> BackupPayload {
        guard let token = AuthService.shared.accessToken,
              let userId = AuthService.shared.currentUser?.id else {
            throw BackupError.notSignedIn
        }

        var urlComponents = URLComponents(url: SupabaseConfig.userBackupsURL, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "select", value: "data"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)")
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        applyHeaders(&request, token: token)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BackupError.restoreFailed
        }

        // Response is an array of rows; we want the first row's "data" field
        struct Row: Codable { let data: BackupPayload }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rows = try decoder.decode([Row].self, from: data)

        guard let payload = rows.first?.data else {
            throw BackupError.restoreFailed
        }
        return payload
    }

    /// Apply a backup payload to all local stores.
    @MainActor
    func applyRestore(_ payload: BackupPayload) async {
        guard let quoteStore, let settingsStore,
              let userEquivalencesStore, let tutorialStore else { return }

        isRestoring = true
        backupState = .restoring

        // 1. Restore quotes, sessions, categories
        quoteStore.restoreFromBackup(
            quotes: payload.quotes,
            sessions: payload.sessions,
            categories: payload.categories,
            packVersions: payload.packVersions
        )

        // 2. Restore settings
        settingsStore.settings = payload.settings

        // 3. Restore user equivalences
        let equivalenceSets = payload.userEquivalences.mapValues { Set($0) }
        userEquivalencesStore.restoreFromBackup(equivalences: equivalenceSets)

        // 4. Restore tutorial state
        tutorialStore.restoreFromBackup(
            completedTips: Set(payload.completedTips),
            hasCompletedOnboarding: payload.hasCompletedOnboarding
        )

        // 5. Download category images
        await downloadCategoryImages(manifest: payload.categoryImageManifest)

        isRestoring = false
        backupState = .idle
        print("[CloudBackup] Restore complete")
    }

    // MARK: - Sign-In Handler

    private func onSignIn() async {
        // Check if a cloud backup exists so the Restore button is enabled/disabled correctly.
        // No auto-prompt — user must manually tap "Restore from Backup" if they want it.
        _ = await checkForCloudBackup()
    }

    // MARK: - Supabase REST Helpers

    private func upsertBackup(_ payloadData: Data) async throws {
        guard let token = AuthService.shared.accessToken,
              let userId = AuthService.shared.currentUser?.id else {
            throw BackupError.notSignedIn
        }

        // Build the row: { user_id, data, backup_version, updated_at }
        // We wrap the encoded payload inside a row object
        let payloadJSON = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] ?? [:]
        let row: [String: Any] = [
            "user_id": userId,
            "data": payloadJSON,
            "backup_version": BackupPayload.currentVersion,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]

        let body = try JSONSerialization.data(withJSONObject: row)

        var urlComponents = URLComponents(url: SupabaseConfig.userBackupsURL, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id")]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        applyHeaders(&request, token: token)
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: responseData, encoding: .utf8) ?? "no body"
            print("[CloudBackup] UPSERT failed (\(statusCode)): \(body)")
            throw BackupError.backupFailed
        }
    }

    private func applyHeaders(_ request: inout URLRequest, token: String) {
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    // MARK: - Category Image Upload/Download

    private func uploadCategoryImages(categories: [QuoteCategory]) async -> [CategoryImageEntry] {
        guard let userId = AuthService.shared.currentUser?.id,
              let token = AuthService.shared.accessToken else { return [] }

        var manifest: [CategoryImageEntry] = []
        let imagesDir = categoryImagesDirectory

        for category in categories {
            guard case .local(let filename) = category.imageSource else { continue }
            let localURL = imagesDir.appendingPathComponent(filename)
            guard let imageData = try? Data(contentsOf: localURL) else { continue }

            let remotePath = "\(userId)/\(filename)"
            let uploadURL = SupabaseConfig.userImagesStorageURL.appendingPathComponent(remotePath)

            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            request.setValue("true", forHTTPHeaderField: "x-upsert")
            request.httpBody = imageData

            do {
                let (_, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    manifest.append(CategoryImageEntry(
                        categoryId: category.id.uuidString,
                        localFilename: filename,
                        remoteStoragePath: remotePath
                    ))
                }
            } catch {
                print("[CloudBackup] Failed to upload image \(filename): \(error.localizedDescription)")
            }
        }

        return manifest
    }

    private func downloadCategoryImages(manifest: [CategoryImageEntry]) async {
        let imagesDir = categoryImagesDirectory

        for entry in manifest {
            let publicURL = SupabaseConfig.publicUserImageURL(path: entry.remoteStoragePath)
            let localURL = imagesDir.appendingPathComponent(entry.localFilename)

            // Skip if already exists locally
            if FileManager.default.fileExists(atPath: localURL.path) { continue }

            do {
                let (data, response) = try await session.data(from: publicURL)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    continue
                }
                try data.write(to: localURL)
            } catch {
                print("[CloudBackup] Failed to download image \(entry.localFilename): \(error.localizedDescription)")
            }
        }
    }

    private var categoryImagesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("category_images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case notSignedIn
    case backupFailed
    case restoreFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Not signed in"
        case .backupFailed: return "Backup failed"
        case .restoreFailed: return "Restore failed"
        }
    }
}
