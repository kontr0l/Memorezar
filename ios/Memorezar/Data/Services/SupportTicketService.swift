import Foundation
import UIKit

enum SupportReason: String, CaseIterable, Identifiable {
    case featureRequest = "feature_request"
    case quotePackRequest = "quote_pack_request"
    case bugReport = "bug_report"
    case awesome = "awesome"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .featureRequest: return String(localized: "Feature Request")
        case .quotePackRequest: return String(localized: "Quote Pack Request")
        case .bugReport: return String(localized: "Bug Report")
        case .awesome: return String(localized: "Hey You're Awesome")
        case .other: return String(localized: "Other")
        }
    }
}

class SupportTicketService {
    static let shared = SupportTicketService()
    private init() {}

    private let session = URLSession.shared

    func submitTicket(reason: SupportReason, message: String, email: String) async throws {
        guard SupabaseConfig.isConfigured else { return }

        var request = URLRequest(url: SupabaseConfig.supportTicketsURL)
        request.httpMethod = "POST"
        for (key, value) in SupabaseConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        var body: [String: Any] = [
            "reason": reason.rawValue,
            "message": message,
            "email": email,
            "app_version": appVersion,
            "device_info": deviceInfo
        ]

        if let userId = AuthService.shared.currentUser?.id {
            body["user_id"] = userId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "SupportTicketService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to submit ticket (status \(statusCode))"])
        }
    }

    private var appVersion: String {
        "v70.7"
    }

    private var deviceInfo: String {
        let device = UIDevice.current
        return "\(device.model), iOS \(device.systemVersion)"
    }
}
