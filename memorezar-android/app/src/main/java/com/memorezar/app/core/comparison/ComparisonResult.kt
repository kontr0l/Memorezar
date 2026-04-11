package com.memorezar.app.core.comparison

/** Result of comparing a spoken word against the expected word */
data class ComparisonResult(
    val isMatch: Boolean,
    val expectedWord: String,
    val spokenWord: String,
    val normalizedExpected: String,
    val normalizedSpoken: String,
    val position: Int,
    val confidence: Float = 0f,
    val matchType: MatchType = MatchType.MISMATCH,
    /** Positions that were skipped when look-ahead jumped ahead (should be marked as mistakes) */
    val skippedPositions: List<Int> = emptyList()
)
