package com.memorezar.app.core.chunking

import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Splits text into chunks at natural break points (punctuation, newlines)
 * or word boundaries when no punctuation is available.
 */
object TextChunker {

    private val PUNCTUATION = setOf('.', ',', ';', ':', '!', '?', '\u2014')

    /**
     * Split text into one chunk per paragraph (separated by blank lines, or by
     * single newlines if the text has no blank-line separators). Returns the
     * trimmed paragraphs; empty paragraphs are skipped.
     */
    fun splitByParagraphs(text: String): List<String> {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return emptyList()

        val blankLineSeparated = trimmed.split(Regex("\\n\\s*\\n"))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (blankLineSeparated.size > 1) return blankLineSeparated

        val lineSeparated = trimmed.split(Regex("\\r?\\n"))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        return if (lineSeparated.isEmpty()) listOf(trimmed) else lineSeparated
    }

    /** Number of paragraph-style chunks `splitByParagraphs` would produce. */
    fun paragraphCount(text: String): Int = splitByParagraphs(text).size

    fun split(text: String, count: Int): List<String> {
        val trimmed = text.trim()
        if (count <= 1 || trimmed.isEmpty()) return listOf(trimmed)

        val breakPoints = findBreakPoints(trimmed)

        val punctuationChunks: List<String>? = when {
            breakPoints.size >= count - 1 -> splitAtBreakPoints(trimmed, breakPoints, count)
            breakPoints.isNotEmpty() -> splitAtAllBreakPoints(trimmed, breakPoints)
            else -> null
        }

        // Validate: punctuation-based result must have the requested chunk count
        // and every chunk must have ≥3 words. Otherwise the user ends up with a
        // 1-word chunk like "Beware," because punctuation clusters at one end.
        // Fall back to even word-boundary splitting in that case.
        if (punctuationChunks != null
            && punctuationChunks.size == count
            && punctuationChunks.all { wordCount(it) >= 3 }
        ) {
            return punctuationChunks
        }

        return splitAtWordBoundaries(trimmed, count)
    }

    private fun wordCount(text: String): Int =
        text.split(Regex("\\s+")).count { it.isNotEmpty() }

    private fun findBreakPoints(text: String): List<Int> {
        val points = mutableListOf<Int>()
        val chars = text.toCharArray()
        var i = 0
        while (i < chars.size) {
            if (chars[i] in PUNCTUATION || chars[i] == '\n' || chars[i] == '\r') {
                var j = i + 1
                while (j < chars.size && (chars[j].isWhitespace() || chars[j] == '\n' || chars[j] == '\r')) {
                    j++
                }
                if (j < chars.size) {
                    points.add(j)
                }
                i = j
            } else {
                i++
            }
        }
        return points
    }

    private fun splitAtBreakPoints(text: String, breakPoints: List<Int>, count: Int): List<String> {
        val idealSize = text.length.toDouble() / count.toDouble()
        val remaining = breakPoints.toMutableList()
        val selectedBreaks = mutableListOf<Int>()

        // Pick a distinct breakpoint for each ideal position. Exclude already-chosen
        // candidates so two ideals can't collapse onto the same break.
        for (i in 1 until count) {
            if (remaining.isEmpty()) break
            val idealPos = (idealSize * i).toInt()
            val closest = remaining.minByOrNull { abs(it - idealPos) } ?: break
            selectedBreaks.add(closest)
            remaining.remove(closest)
        }

        // Not enough distinct punctuation breaks — fall back to word boundaries so we
        // still produce the requested number of chunks with reasonable sizes.
        if (selectedBreaks.size < count - 1) {
            return splitAtWordBoundaries(text, count)
        }

        selectedBreaks.sort()
        return extractChunks(text, selectedBreaks)
    }

    private fun splitAtAllBreakPoints(text: String, breakPoints: List<Int>): List<String> {
        return extractChunks(text, breakPoints)
    }

    private fun splitAtWordBoundaries(text: String, count: Int): List<String> {
        val words = text.split(Regex("\\s+")).filter { it.isNotEmpty() }
        if (words.size < count) return words

        val wordsPerChunk = words.size.toDouble() / count.toDouble()
        val chunks = mutableListOf<String>()
        var startIdx = 0

        for (i in 0 until count) {
            val endIdx = if (i == count - 1) words.size else (wordsPerChunk * (i + 1)).roundToInt()
            chunks.add(words.subList(startIdx, endIdx).joinToString(" "))
            startIdx = endIdx
        }
        return chunks
    }

    private fun extractChunks(text: String, breaks: List<Int>): List<String> {
        val chunks = mutableListOf<String>()
        var start = 0

        for (bp in breaks) {
            val chunk = text.substring(start, bp).trim()
            if (chunk.isNotEmpty()) {
                chunks.add(chunk)
            }
            start = bp
        }

        val last = text.substring(start).trim()
        if (last.isNotEmpty()) {
            chunks.add(last)
        }
        return chunks
    }
}
