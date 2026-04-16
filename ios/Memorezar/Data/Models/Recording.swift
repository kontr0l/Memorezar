import Foundation

/// A community audio recording of a quote
struct Recording: Identifiable, Codable {
    let id: UUID
    let quoteTextHash: String
    let quoteTitle: String
    let uploaderName: String
    let filePath: String
    let durationSeconds: Double?
    let createdAt: Date
    let language: String
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case quoteTextHash = "quote_text_hash"
        case quoteTitle = "quote_title"
        case uploaderName = "uploader_name"
        case filePath = "file_path"
        case durationSeconds = "duration_seconds"
        case createdAt = "created_at"
        case language
        case userId = "user_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        quoteTextHash = try container.decode(String.self, forKey: .quoteTextHash)
        quoteTitle = try container.decode(String.self, forKey: .quoteTitle)
        uploaderName = try container.decode(String.self, forKey: .uploaderName)
        filePath = try container.decode(String.self, forKey: .filePath)
        durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? "en"
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
    }
}

/// A locally-stored audio recording (private or saved from community)
struct LocalRecording: Identifiable, Codable {
    let id: UUID
    let quoteTextHash: String
    let quoteTitle: String
    let localFileName: String      // filename in Documents/recordings/
    let durationSeconds: Double
    let createdAt: Date
    var isFavorite: Bool           // true if saved from community
    var sourceRecordingId: UUID?   // original community recording ID
    var uploaderName: String?      // original uploader name (from community)
    var name: String?              // user-provided name for the recording
    var quoteId: UUID?             // parent quote ID (for cross-language lookup)
    var language: String            // language code when recorded
    /// If this local has been published to the community, this is the id
    /// of that community row. nil = private/local-only. Set on successful
    /// upload, cleared on unshare/replace/delete. Authoritative — no more
    /// guessing via user_id+language heuristics.
    var communityRecordingId: UUID?

    init(
        id: UUID = UUID(),
        quoteTextHash: String,
        quoteTitle: String,
        localFileName: String,
        durationSeconds: Double,
        createdAt: Date = Date(),
        isFavorite: Bool = false,
        sourceRecordingId: UUID? = nil,
        uploaderName: String? = nil,
        name: String? = nil,
        quoteId: UUID? = nil,
        language: String = "en",
        communityRecordingId: UUID? = nil
    ) {
        self.id = id
        self.quoteTextHash = quoteTextHash
        self.quoteTitle = quoteTitle
        self.localFileName = localFileName
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.sourceRecordingId = sourceRecordingId
        self.uploaderName = uploaderName
        self.name = name
        self.quoteId = quoteId
        self.language = language
        self.communityRecordingId = communityRecordingId
    }

    // Backward-compatible decoding: old recordings without language default to "en",
    // and older recordings without communityRecordingId default to nil (reconciled
    // later by RecitationScreen when the community list loads).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        quoteTextHash = try container.decode(String.self, forKey: .quoteTextHash)
        quoteTitle = try container.decode(String.self, forKey: .quoteTitle)
        localFileName = try container.decode(String.self, forKey: .localFileName)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        sourceRecordingId = try container.decodeIfPresent(UUID.self, forKey: .sourceRecordingId)
        uploaderName = try container.decodeIfPresent(String.self, forKey: .uploaderName)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        quoteId = try container.decodeIfPresent(UUID.self, forKey: .quoteId)
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? "en"
        communityRecordingId = try container.decodeIfPresent(UUID.self, forKey: .communityRecordingId)
    }
}

/// Unified source for playback — wraps either a local or community recording
enum PlaybackSource: Identifiable {
    case local(LocalRecording)
    case community(Recording)

    var id: UUID {
        switch self {
        case .local(let r): return r.id
        case .community(let r): return r.id
        }
    }

    var name: String {
        switch self {
        case .local(let r):
            return r.isFavorite ? (r.uploaderName ?? "Community") : (r.name ?? "Your recording")
        case .community(let r):
            return r.uploaderName
        }
    }

    var duration: Double {
        switch self {
        case .local(let r): return r.durationSeconds
        case .community(let r): return r.durationSeconds ?? 0
        }
    }

    /// Whether this source is a community recording (including saved/favorited ones)
    var isCommunity: Bool {
        switch self {
        case .community: return true
        case .local(let r): return r.sourceRecordingId != nil
        }
    }

    var communityRecording: Recording? {
        if case .community(let r) = self { return r }
        return nil
    }

    var localRecording: LocalRecording? {
        if case .local(let r) = self { return r }
        return nil
    }
}
