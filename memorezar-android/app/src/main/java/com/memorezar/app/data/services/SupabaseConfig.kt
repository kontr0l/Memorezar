package com.memorezar.app.data.services

object SupabaseConfig {
    const val PROJECT_URL = "https://tcaaozzijpgbaqzpnahl.supabase.co"
    const val ANON_KEY = "sb_publishable_Cm0aEtK1Uv9-F7GIiU_15A_AgGH2ALL"

    // REST endpoints
    const val RECORDINGS_URL = "$PROJECT_URL/rest/v1/recordings"
    const val FLAGS_URL = "$PROJECT_URL/rest/v1/flags"
    const val EQUIVALENCES_URL = "$PROJECT_URL/rest/v1/equivalences"
    const val SUPPORT_TICKETS_URL = "$PROJECT_URL/rest/v1/support_tickets"
    const val PACKS_URL = "$PROJECT_URL/rest/v1/suggestion_packs"

    // Storage
    const val STORAGE_URL = "$PROJECT_URL/storage/v1/object/recordings"

    /** Private bucket for per-user audio backups. Owner-only RLS — files at
     *  <user_id>/<local_recording_id>.m4a. Used by CloudBackupService on
     *  Back Up Now / Restore. NOT for community recordings. */
    const val RECORDING_BACKUPS_URL = "$PROJECT_URL/storage/v1/object/recording-backups"

    fun publicFileURL(path: String): String =
        "$PROJECT_URL/storage/v1/object/public/recordings/$path"

    // Edge Functions
    const val TTS_URL = "$PROJECT_URL/functions/v1/tts"

    val isConfigured: Boolean
        get() = !PROJECT_URL.contains("YOUR_PROJECT_ID") && !ANON_KEY.contains("YOUR_ANON_KEY")
}
