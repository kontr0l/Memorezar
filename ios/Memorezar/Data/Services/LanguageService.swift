import Foundation
import SwiftUI

/// Fetches language display config (colors) from Supabase.
/// Falls back to hardcoded defaults if offline.
final class LanguageService: ObservableObject {
    static let shared = LanguageService()

    @Published private(set) var languages: [String: LanguageConfig] = LanguageService.defaults

    private var languagesURL: URL {
        URL(string: "\(SupabaseConfig.projectURL)/rest/v1/languages?select=*")!
    }

    struct LanguageConfig {
        let displayName: String
        let color: Color
        let textColor: Color
    }

    private static let defaults: [String: LanguageConfig] = [
        "en": LanguageConfig(displayName: "English", color: .blue, textColor: .white),
        "es": LanguageConfig(displayName: "Spanish", color: .yellow, textColor: .black),
        "fr": LanguageConfig(displayName: "French", color: .red, textColor: .white),
        "it": LanguageConfig(displayName: "Italian", color: .green, textColor: .black),
        "de": LanguageConfig(displayName: "German", color: .orange, textColor: .black),
        "pt": LanguageConfig(displayName: "Portuguese", color: .green, textColor: .black),
        "ar": LanguageConfig(displayName: "Arabic", color: .green, textColor: .white),
    ]

    func fetchLanguages() async {
        var request = URLRequest(url: languagesURL)
        request.timeoutInterval = 10
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            let rows = try JSONDecoder().decode([RemoteLanguageRow].self, from: data)
            var built: [String: LanguageConfig] = [:]
            for row in rows {
                built[row.code] = LanguageConfig(
                    displayName: row.display_name,
                    color: Color(hex: row.color),
                    textColor: Color(hex: row.text_color)
                )
            }
            let finalLanguages = built
            await MainActor.run {
                self.languages = finalLanguages
            }
        } catch {
            print("[LanguageService] Fetch failed: \(error.localizedDescription)")
        }
    }

    func color(for code: String) -> Color {
        languages[code]?.color ?? .indigo
    }

    func textColor(for code: String) -> Color {
        languages[code]?.textColor ?? .white
    }
}

private struct RemoteLanguageRow: Codable {
    let code: String
    let display_name: String
    let color: String
    let text_color: String
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
