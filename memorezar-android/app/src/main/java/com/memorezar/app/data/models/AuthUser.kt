package com.memorezar.app.data.models

import kotlinx.serialization.Serializable

@Serializable
data class AuthUser(
    val id: String,
    val email: String? = null,
    val displayName: String? = null
)
