import Foundation

/// Async service for fetching photos from the Unsplash API
final class UnsplashService {
    static let shared = UnsplashService()
    private init() {}

    // Free tier: 50 requests/hour
    private let accessKey = "7YzF0aG-BRdz4vAQBXSIEfOvYbaC4hIC5Eu7-lmfxwc"
    private let baseURL = "https://api.unsplash.com"
    private let session = URLSession.shared

    // MARK: - Public API

    /// Fetch a single random photo, optionally filtered by query
    func fetchRandomPhoto(query: String? = nil) async throws -> UnsplashImageInfo {
        var components = URLComponents(string: "\(baseURL)/photos/random")!
        var queryItems = [URLQueryItem(name: "orientation", value: "portrait")]
        if let query = query {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }
        components.queryItems = queryItems

        let data = try await performRequest(url: components.url!)
        let photo = try JSONDecoder().decode(UnsplashPhoto.self, from: data)
        return photo.toImageInfo()
    }

    /// Search photos by query with pagination
    func searchPhotos(query: String, page: Int = 1) async throws -> [UnsplashImageInfo] {
        var components = URLComponents(string: "\(baseURL)/search/photos")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "20"),
            URLQueryItem(name: "orientation", value: "portrait"),
        ]

        let data = try await performRequest(url: components.url!)
        let response = try JSONDecoder().decode(UnsplashSearchResponse.self, from: data)
        return response.results.map { $0.toImageInfo() }
    }

    /// Trigger a download event per Unsplash API TOS
    func triggerDownload(url: String) async {
        guard let downloadURL = URL(string: url) else { return }
        var request = URLRequest(url: downloadURL)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
    }

    // MARK: - Private

    private func performRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UnsplashError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 403 {
                throw UnsplashError.rateLimited
            }
            throw UnsplashError.httpError(httpResponse.statusCode)
        }

        return data
    }
}

// MARK: - Error Types

enum UnsplashError: Error, LocalizedError {
    case invalidResponse
    case rateLimited
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Unsplash"
        case .rateLimited: return "Unsplash rate limit reached. Try again later."
        case .httpError(let code): return "Unsplash API error (HTTP \(code))"
        }
    }
}

// MARK: - API Response Models

private struct UnsplashPhoto: Decodable {
    let urls: UnsplashURLs
    let user: UnsplashUser
    let links: UnsplashLinks

    func toImageInfo() -> UnsplashImageInfo {
        UnsplashImageInfo(
            regularURL: urls.regular,
            smallURL: urls.small,
            photographerName: user.name,
            photographerURL: user.links.html,
            downloadURL: links.download_location
        )
    }
}

private struct UnsplashURLs: Decodable {
    let regular: String
    let small: String
}

private struct UnsplashUser: Decodable {
    let name: String
    let links: UnsplashUserLinks
}

private struct UnsplashUserLinks: Decodable {
    let html: String
}

private struct UnsplashLinks: Decodable {
    let download_location: String
}

private struct UnsplashSearchResponse: Decodable {
    let results: [UnsplashPhoto]
}
