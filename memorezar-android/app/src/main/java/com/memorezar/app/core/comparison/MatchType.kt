package com.memorezar.app.core.comparison

import kotlinx.serialization.Serializable

/** How a match was determined */
@Serializable
enum class MatchType {
    EXACT,
    USER_EQUIVALENCE,
    COMMUNITY_EQUIVALENCE,
    HOMOPHONE,
    CONTRACTION,
    OLD_ENGLISH,
    PHONETIC,
    ALTERNATIVE_MATCH,
    FUZZY,
    MISMATCH
}
