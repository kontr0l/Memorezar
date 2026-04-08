package com.memorezar.app.data.services

import android.content.Context
import android.os.Build
import dagger.hilt.android.qualifiers.ApplicationContext
import io.ktor.client.HttpClient
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import javax.inject.Inject
import javax.inject.Singleton

enum class SupportReason(val apiValue: String) {
    FEATURE_REQUEST("feature_request"),
    QUOTE_PACK_REQUEST("quote_pack_request"),
    BUG_REPORT("bug_report"),
    AWESOME("awesome"),
    OTHER("other")
}

@Singleton
class SupportTicketService @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val httpClient: HttpClient,
    private val authService: AuthService
) {
    suspend fun submitTicket(reason: SupportReason, message: String, email: String) {
        val deviceInfo = "${Build.MANUFACTURER} ${Build.MODEL}, Android ${Build.VERSION.RELEASE}"
        val userId = authService.currentUser.value?.id

        val body = buildString {
            append("{")
            append(""""reason":"${reason.apiValue}",""")
            append(""""message":"${message.replace("\"", "\\\"")}",""")
            append(""""email":"${email.replace("\"", "\\\"")}",""")
            append(""""app_version":"v1.0",""")
            append(""""device_info":"$deviceInfo"""")
            if (!userId.isNullOrEmpty()) {
                append(""","user_id":"$userId"""")
            }
            append("}")
        }

        val response = httpClient.post(SupabaseConfig.SUPPORT_TICKETS_URL) {
            for ((k, v) in authService.headers()) header(k, v)
            header("Prefer", "return=minimal")
            contentType(ContentType.Application.Json)
            setBody(body)
        }

        if (!response.status.isSuccess()) {
            throw Exception("Failed to submit support ticket (${response.status.value})")
        }
    }
}
