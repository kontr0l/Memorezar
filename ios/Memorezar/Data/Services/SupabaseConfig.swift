import Foundation

/// Configuration for Supabase REST API access
/// Admin: fill in projectURL and anonKey after creating your Supabase project
enum SupabaseConfig {
    // MARK: - Credentials (fill these in)

    static let projectURL = "https://tcaaozzijpgbaqzpnahl.supabase.co"
    static let anonKey = "sb_publishable_Cm0aEtK1Uv9-F7GIiU_15A_AgGH2ALL"

    // MARK: - Endpoints

    static var recordingsURL: URL {
        URL(string: "\(projectURL)/rest/v1/recordings")!
    }

    static var flagsURL: URL {
        URL(string: "\(projectURL)/rest/v1/flags")!
    }

    static var equivalencesURL: URL {
        URL(string: "\(projectURL)/rest/v1/equivalences")!
    }

    static var storageURL: URL {
        URL(string: "\(projectURL)/storage/v1/object/recordings")!
    }

    static func publicFileURL(path: String) -> URL {
        URL(string: "\(projectURL)/storage/v1/object/public/recordings/\(path)")!
    }

    // MARK: - Headers

    static var headers: [String: String] {
        let token = AuthService.shared.accessToken ?? anonKey
        return [
            "apikey": anonKey,
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
    }

    /// Whether credentials have been configured (not placeholder values)
    static var isConfigured: Bool {
        !projectURL.contains("YOUR_PROJECT_ID") && !anonKey.contains("YOUR_ANON_KEY")
    }
}
