import Foundation
import CryptoKit

/// REST client for Supabase recordings API
class RecordingService {
    static let shared = RecordingService()
    private init() {}

    private let session = URLSession.shared

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // Try with fractional seconds first, then without
            if let date = formatter.date(from: str) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }()

    // MARK: - Text Hashing

    /// Normalize quote text and produce a SHA256 hash for cross-device matching
    func hashQuoteText(_ text: String) -> String {
        let normalized = text
            .lowercased()
            .components(separatedBy: .punctuationCharacters).joined()
            .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Fetch Recordings

    /// Fetch recordings matching a quote text hash. Returns empty array on any error.
    func fetchRecordings(forHash hash: String) async -> [Recording] {
        guard SupabaseConfig.isConfigured else { return [] }

        var components = URLComponents(url: SupabaseConfig.recordingsURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "quote_text_hash", value: "eq.\(hash)"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, _) = try await session.data(for: request)
            return try decoder.decode([Recording].self, from: data)
        } catch {
            print("[RecordingService] fetchRecordings error: \(error)")
            return []
        }
    }

    /// Fetch just the count of recordings for a quote hash
    func fetchRecordingCount(forHash hash: String) async -> Int {
        guard SupabaseConfig.isConfigured else { return 0 }

        var components = URLComponents(url: SupabaseConfig.recordingsURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "quote_text_hash", value: "eq.\(hash)"),
            URLQueryItem(name: "select", value: "id")
        ]

        guard let url = components.url else { return 0 }

        var request = URLRequest(url: url)
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("exact", forHTTPHeaderField: "Prefer")

        do {
            let (data, response) = try await session.data(for: request)
            // Try to get count from content-range header first
            if let httpResponse = response as? HTTPURLResponse,
               let range = httpResponse.value(forHTTPHeaderField: "content-range"),
               let countStr = range.split(separator: "/").last,
               let count = Int(countStr) {
                return count
            }
            // Fall back to counting decoded array
            let ids = try decoder.decode([[String: UUID]].self, from: data)
            return ids.count
        } catch {
            print("[RecordingService] fetchRecordingCount error: \(error)")
            return 0
        }
    }

    // MARK: - Upload Audio

    /// Upload audio data to Supabase Storage, returns the file path
    func uploadAudio(data: Data) async throws -> String {
        let fileName = "\(UUID().uuidString).m4a"
        let url = SupabaseConfig.storageURL.appendingPathComponent(fileName)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let token = AuthService.shared.accessToken ?? SupabaseConfig.anonKey
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RecordingError.uploadFailed
        }

        return fileName
    }

    // MARK: - Create Metadata Row

    /// Insert a recording metadata row into Supabase
    func createRecording(
        quoteTextHash: String,
        quoteTitle: String,
        uploaderName: String,
        filePath: String,
        durationSeconds: Double?,
        language: String = "en"
    ) async throws -> Recording {
        var request = URLRequest(url: SupabaseConfig.recordingsURL)
        request.httpMethod = "POST"
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        // Use upsert when signed in (handles one-recording-per-user-per-quote-per-language)
        if AuthService.shared.isSignedIn {
            request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        } else {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }

        var body: [String: Any] = [
            "quote_text_hash": quoteTextHash,
            "quote_title": quoteTitle,
            "uploader_name": uploaderName.isEmpty ? "Anonymous" : uploaderName,
            "file_path": filePath,
            "language": language
        ]
        if let duration = durationSeconds {
            body["duration_seconds"] = duration
        }
        if let userId = AuthService.shared.currentUser?.id {
            body["user_id"] = userId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RecordingError.createFailed
        }

        let recordings = try decoder.decode([Recording].self, from: data)
        guard let recording = recordings.first else {
            throw RecordingError.createFailed
        }
        return recording
    }

    /// Delete a community recording (DB row + audio file in storage).
    /// Requires the current user to own the recording — RLS enforces this
    /// server-side. The audio file in Supabase Storage is best-effort: if the
    /// DB delete succeeds but the file delete fails, the row is gone so the
    /// recording is effectively unshared.
    func deleteRecording(id: UUID, filePath: String?) async throws {
        guard SupabaseConfig.isConfigured,
              let token = AuthService.shared.accessToken else {
            throw RecordingError.createFailed
        }

        // 1. Delete the DB row
        var components = URLComponents(url: SupabaseConfig.recordingsURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
        guard let url = components.url else { throw RecordingError.createFailed }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[RecordingService] DELETE row failed status=\(code)")
            throw RecordingError.createFailed
        }

        // 2. Best-effort delete the audio file from storage. If this fails the
        // row is already gone, so the recording is unshared either way.
        if let filePath = filePath, !filePath.isEmpty {
            let storageURL = SupabaseConfig.storageURL.appendingPathComponent(filePath)
            var fileRequest = URLRequest(url: storageURL)
            fileRequest.httpMethod = "DELETE"
            fileRequest.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            fileRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (_, fileResponse) = try await session.data(for: fileRequest)
                if let http = fileResponse as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    print("[RecordingService] Storage DELETE returned status=\(http.statusCode) — row already gone, continuing")
                }
            } catch {
                print("[RecordingService] Storage DELETE threw \(error) — row already gone, continuing")
            }
        }
    }

    /// Check if the current user already has a recording for this quote+language
    func fetchMyRecording(forHash hash: String, language: String) async -> Recording? {
        guard SupabaseConfig.isConfigured,
              let userId = AuthService.shared.currentUser?.id else { return nil }

        var components = URLComponents(url: SupabaseConfig.recordingsURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "quote_text_hash", value: "eq.\(hash)"),
            URLQueryItem(name: "language", value: "eq.\(language)"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, _) = try await session.data(for: request)
            let recordings = try decoder.decode([Recording].self, from: data)
            return recordings.first
        } catch {
            print("[RecordingService] fetchMyRecording error: \(error)")
            return nil
        }
    }

    // MARK: - Flag Recording

    /// Flag a recording as inappropriate
    func flagRecording(recordingId: UUID, reason: String) async throws {
        guard SupabaseConfig.isConfigured else { throw RecordingError.flagFailed }

        var request = URLRequest(url: SupabaseConfig.flagsURL)
        request.httpMethod = "POST"
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let body: [String: Any] = [
            "recording_id": recordingId.uuidString,
            "reason": reason
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RecordingError.flagFailed
        }
    }

    // MARK: - Download Audio

    /// Download audio data from public storage URL
    func downloadAudio(filePath: String) async throws -> Data {
        let url = SupabaseConfig.publicFileURL(path: filePath)
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RecordingError.downloadFailed
        }

        return data
    }
}

enum RecordingError: LocalizedError {
    case uploadFailed
    case createFailed
    case downloadFailed
    case flagFailed

    var errorDescription: String? {
        switch self {
        case .uploadFailed: return "Failed to upload audio"
        case .createFailed: return "Failed to save recording"
        case .downloadFailed: return "Failed to download audio"
        case .flagFailed: return "Failed to flag recording"
        }
    }
}
