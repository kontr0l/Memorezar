package com.memorezar.app.data.services

import android.util.Log
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.http.isSuccess
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "UnsplashService"
private const val BASE_URL = "https://api.unsplash.com"
private const val ACCESS_KEY = "7YzF0aG-BRdz4vAQBXSIEfOvYbaC4hIC5Eu7-lmfxwc"

// Response models

data class UnsplashImageInfo(
    val regularURL: String,
    val smallURL: String,
    val photographerName: String,
    val photographerURL: String,
    val downloadURL: String
)

@Serializable
private data class UnsplashUrls(
    val regular: String = "",
    val small: String = ""
)

@Serializable
private data class UnsplashUserLinks(
    val html: String = ""
)

@Serializable
private data class UnsplashUser(
    val name: String = "",
    val links: UnsplashUserLinks = UnsplashUserLinks()
)

@Serializable
private data class UnsplashPhotoLinks(
    @SerialName("download_location") val downloadLocation: String = ""
)

@Serializable
private data class UnsplashPhoto(
    val urls: UnsplashUrls = UnsplashUrls(),
    val user: UnsplashUser = UnsplashUser(),
    val links: UnsplashPhotoLinks = UnsplashPhotoLinks()
)

@Serializable
private data class UnsplashSearchResponse(
    val results: List<UnsplashPhoto> = emptyList()
)

// Errors

sealed class UnsplashError(override val message: String) : Exception(message) {
    object RateLimited : UnsplashError("Unsplash rate limit exceeded")
    data class HttpError(val statusCode: Int) : UnsplashError("Unsplash HTTP $statusCode")
    object InvalidResponse : UnsplashError("Invalid Unsplash response")
}

@Singleton
class UnsplashService @Inject constructor(
    private val httpClient: HttpClient
) {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun fetchRandomPhoto(query: String? = null): UnsplashImageInfo {
        val url = buildString {
            append("$BASE_URL/photos/random?orientation=portrait")
            if (!query.isNullOrBlank()) append("&query=$query")
        }

        val response = httpClient.get(url) {
            header("Authorization", "Client-ID $ACCESS_KEY")
        }

        if (response.status.value == 403) throw UnsplashError.RateLimited
        if (!response.status.isSuccess()) throw UnsplashError.HttpError(response.status.value)

        val body: String = response.body()
        val photo = json.decodeFromString<UnsplashPhoto>(body)
        return photo.toImageInfo()
    }

    suspend fun searchPhotos(query: String, page: Int = 1): List<UnsplashImageInfo> {
        val url = "$BASE_URL/search/photos?query=$query&page=$page&per_page=20&orientation=portrait"

        val response = httpClient.get(url) {
            header("Authorization", "Client-ID $ACCESS_KEY")
        }

        if (response.status.value == 403) throw UnsplashError.RateLimited
        if (!response.status.isSuccess()) throw UnsplashError.HttpError(response.status.value)

        val body: String = response.body()
        val searchResponse = json.decodeFromString<UnsplashSearchResponse>(body)
        return searchResponse.results.map { it.toImageInfo() }
    }

    /** Trigger download event per Unsplash ToS (fire-and-forget). */
    suspend fun triggerDownload(url: String) {
        try {
            httpClient.get(url) {
                header("Authorization", "Client-ID $ACCESS_KEY")
            }
        } catch (_: Exception) { }
    }

    private fun UnsplashPhoto.toImageInfo() = UnsplashImageInfo(
        regularURL = urls.regular,
        smallURL = urls.small,
        photographerName = user.name,
        photographerURL = user.links.html,
        downloadURL = links.downloadLocation
    )
}
