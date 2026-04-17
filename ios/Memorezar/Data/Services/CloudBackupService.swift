import Foundation
import Combine
import os

/// System-log channel for CloudBackup messages. Unlike plain `print()`,
/// these show up in Console.app and `log show/stream` with subsystem
/// "com.memorezar.app" and category "CloudBackup".
private let backupLog = Logger(subsystem: "com.memorezar.app", category: "CloudBackup")

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
    /// Legacy device-wide key — no longer written to. Cleaned up on first
    /// sign-in after upgrade so it can't haunt the next signed-in user.
    private let legacyLastBackupKey = "memorezar_last_backup_date"
    /// Per-user key prefix. The footer's "last backed up X ago" must be scoped
    /// to the specific user_id — otherwise User A's timestamp shows up when
    /// User B signs in on the same device.
    private let lastBackupKeyPrefix = "memorezar_last_backup_date_"
    private func lastBackupKey(for userId: String) -> String {
        "\(lastBackupKeyPrefix)\(userId)"
    }

    private let session = URLSession.shared

    // MARK: - Weak references to stores (set during app init)

    weak var quoteStore: QuoteStore?
    weak var settingsStore: SettingsStore?
    weak var userEquivalencesStore: UserEquivalencesStore?
    weak var tutorialStore: TutorialStore?
    weak var localRecordingStore: LocalRecordingStore?

    private init() {
        // Clean up the legacy device-wide key — any future reads should come
        // from the per-user key via onSignIn().
        UserDefaults.standard.removeObject(forKey: legacyLastBackupKey)

        // Observe auth changes. Do NOT use .dropFirst(): if the user was
        // already signed in before this service subscribed (cold-launch restore
        // from Keychain), that's the emission we need. We handle BOTH sign-in
        // and sign-out here so lastBackupDate/cloudBackupDate/cloudBackupExists
        // never leak between users on the same device.
        AuthService.shared.$currentUser
            .removeDuplicates(by: { $0?.id == $1?.id })
            .sink { [weak self] user in
                guard let self else { return }
                if let userId = user?.id {
                    Task { await self.onSignIn(userId: userId) }
                } else {
                    Task { await self.onSignOut() }
                }
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

            // 2. Upload local recording audio files (private bucket, owner-only RLS).
            //    Empty manifest if localRecordingStore isn't wired or user has no recordings.
            let currentLocals = localRecordingStore?.recordings ?? []
            let recordingManifest = await uploadRecordingAudioFiles(recordings: currentLocals)

            // 3. Build payload
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
                categoryImageManifest: imageManifest,
                localRecordings: currentLocals,
                recordingAudioManifest: recordingManifest
            )

            // 3. Encode
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let payloadData = try encoder.encode(payload)

            // 4. UPSERT to Supabase
            try await upsertBackup(payloadData)

            let now = Date()
            lastBackupDate = now
            cloudBackupDate = now
            cloudBackupExists = true
            if let userId = AuthService.shared.currentUser?.id {
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastBackupKey(for: userId))
            }
            backupState = .idle
            print("[CloudBackup] Backup complete for user \(AuthService.shared.currentUser?.id ?? "?")")
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
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[CloudBackup] Check HTTP \(code) — leaving local state untouched")
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
            // NOTE: we used to also clear `lastBackupDate` here when the result
            // was empty, but "200 OK + 0 rows" can mean either "no backup" OR
            // "RLS filtered our own row" OR "different provider user_id". All
            // three return 0 rows indistinguishably. Clearing UserDefaults in
            // those cases nuked the user's "last backed up X ago" footer
            // immediately after a successful backup — wrong and scary. The
            // Restore row is hidden when cloudBackupExists=false, which is the
            // actionable UI concern; the footer can stay honest about local
            // write history.
            print("[CloudBackup] Check result: exists=\(exists), rows=\(rows.count)")
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

        // 5. Download category images from user-images backup bucket
        backupLog.info("Category image manifest has \(payload.categoryImageManifest.count) entries")
        await downloadCategoryImages(manifest: payload.categoryImageManifest)

        // 5b. Validate: fix .local(filename) entries where file is missing
        let fixedCount = quoteStore.fixMissingCoverImageFiles(imagesDirectory: categoryImagesDirectory)
        if fixedCount > 0 {
            backupLog.info("Fixed \(fixedCount) categories with missing image files → .none")
        }



        // 6. Restore local recordings: wipe on-disk files first, then replace
        //    metadata, then download audio files. Order matters — we don't
        //    want a partial state where metadata references a file we haven't
        //    downloaded yet, or leftover files from pre-restore state.
        if let localRecordingStore {
            localRecordingStore.wipeAllAudioFiles()
            localRecordingStore.replaceAll(payload.localRecordings)
            await downloadRecordingAudioFiles(manifest: payload.recordingAudioManifest)
        }

        isRestoring = false
        backupState = .idle
        print("[CloudBackup] Restore complete")
    }

    // MARK: - Sign-In Handler

    private func onSignIn(userId: String) async {
        // Load this user's last-backup timestamp from their per-user UserDefaults
        // key. nil if this user hasn't backed up on this device yet.
        let restoredDate: Date? = UserDefaults.standard
            .object(forKey: lastBackupKey(for: userId))
            .flatMap { $0 as? Double }
            .map { Date(timeIntervalSince1970: $0) }
        await MainActor.run {
            lastBackupDate = restoredDate
            // Reset cloud-side state; checkForCloudBackup will populate it.
            cloudBackupDate = nil
            cloudBackupExists = false
        }
        // Check if a cloud backup exists so the Restore row shows/hides correctly.
        _ = await checkForCloudBackup()
    }

    @MainActor
    private func onSignOut() async {
        // Clear every bit of in-memory backup state so nothing from the
        // previous user leaks into the next sign-in.
        lastBackupDate = nil
        cloudBackupDate = nil
        cloudBackupExists = false
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

    // MARK: - Recording Audio Upload/Download (Back Up Now / Restore)

    /// Upload every local recording's .m4a to the private `recording-backups`
    /// bucket at `<user_id>/<local_recording_id>.m4a`. Idempotent via
    /// `x-upsert: true` — safe to run on every Back Up Now.
    /// Returns the manifest to embed in the backup payload.
    private func uploadRecordingAudioFiles(recordings: [LocalRecording]) async -> [RecordingAudioEntry] {
        guard let userId = AuthService.shared.currentUser?.id,
              let token = AuthService.shared.accessToken,
              let store = localRecordingStore else {
            backupLog.info("Audio upload skipped: userId=\(AuthService.shared.currentUser?.id ?? "nil", privacy: .public) hasToken=\(AuthService.shared.accessToken != nil, privacy: .public) storeWired=\(self.localRecordingStore != nil, privacy: .public)")
            return []
        }
        backupLog.info("Audio upload starting: \(recordings.count, privacy: .public) recordings for user=\(userId, privacy: .public)")

        var manifest: [RecordingAudioEntry] = []
        var missingFiles = 0

        for recording in recordings {
            let localURL = store.audioFileURL(for: recording)
            guard let audioData = try? Data(contentsOf: localURL) else {
                missingFiles += 1
                continue
            }

            let remotePath = "\(userId)/\(recording.id.uuidString).m4a"
            let uploadURL = SupabaseConfig.recordingBackupsStorageURL.appendingPathComponent(remotePath)

            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
            request.setValue("true", forHTTPHeaderField: "x-upsert")
            request.httpBody = audioData

            do {
                let (respData, response) = try await session.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                if (200...299).contains(code) {
                    manifest.append(RecordingAudioEntry(
                        recordingId: recording.id.uuidString,
                        localFileName: recording.localFileName,
                        remoteStoragePath: remotePath
                    ))
                } else {
                    let body = String(data: respData, encoding: .utf8) ?? "no body"
                    backupLog.error("Audio upload HTTP \(code, privacy: .public) for \(recording.localFileName, privacy: .public) — body: \(body, privacy: .public)")
                }
            } catch {
                backupLog.error("Audio upload threw for \(recording.localFileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        backupLog.info("Audio upload done: uploaded=\(manifest.count, privacy: .public) / total=\(recordings.count, privacy: .public) (missingOnDisk=\(missingFiles, privacy: .public))")
        return manifest
    }

    /// Download each audio file referenced in the manifest back into
    /// Documents/recordings/<localFileName>.m4a. Skipped files won't
    /// crash the restore — the metadata entry will just have no audio
    /// until the user re-records or backs up again.
    private func downloadRecordingAudioFiles(manifest: [RecordingAudioEntry]) async {
        guard let token = AuthService.shared.accessToken,
              let store = localRecordingStore else {
            backupLog.info("Audio download skipped: hasToken=\(AuthService.shared.accessToken != nil, privacy: .public) storeWired=\(self.localRecordingStore != nil, privacy: .public)")
            return
        }
        backupLog.info("Audio download starting: \(manifest.count, privacy: .public) files in manifest")

        var successes = 0
        for entry in manifest {
            let downloadURL = SupabaseConfig.recordingBackupsStorageURL.appendingPathComponent(entry.remoteStoragePath)
            var request = URLRequest(url: downloadURL)
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await session.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard (200...299).contains(code) else {
                    let body = String(data: data, encoding: .utf8) ?? "no body"
                    backupLog.error("Audio download HTTP \(code, privacy: .public) for \(entry.localFileName, privacy: .public) — url=\(downloadURL.absoluteString, privacy: .public) body=\(body, privacy: .public)")
                    continue
                }
                if store.writeAudioFile(data: data, localFileName: entry.localFileName) {
                    successes += 1
                }
            } catch {
                backupLog.error("Audio download threw for \(entry.localFileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        backupLog.info("Audio download done: wrote=\(successes, privacy: .public) / total=\(manifest.count, privacy: .public)")
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
