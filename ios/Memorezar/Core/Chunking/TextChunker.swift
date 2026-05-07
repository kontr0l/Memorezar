import Foundation

/// Splits text into roughly equal chunks at natural punctuation boundaries
enum TextChunker {

    /// Split text into one chunk per paragraph (separated by blank lines, or by
    /// single newlines if the text has no blank-line separators). Each returned
    /// chunk is the trimmed paragraph text. Empty paragraphs are skipped.
    static func splitByParagraphs(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Prefer blank-line separators (a paragraph break in prose). If the
        // source has no blank lines, fall back to single newlines so a quote
        // formatted with one-line-per-stanza still splits sensibly.
        let blankLineSeparated = trimmed.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if blankLineSeparated.count > 1 {
            return blankLineSeparated
        }

        let lineSeparated = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lineSeparated.isEmpty ? [trimmed] : lineSeparated
    }

    /// Number of paragraph-style chunks `splitByParagraphs` would produce.
    static func paragraphCount(_ text: String) -> Int {
        return splitByParagraphs(text).count
    }

    /// Split text into `count` chunks, breaking at punctuation boundaries when possible.
    /// Falls back to word boundaries if there aren't enough punctuation breaks.
    static func split(_ text: String, into count: Int) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard count > 1, !trimmed.isEmpty else { return [trimmed] }

        // Find all punctuation break points.
        // A break point is the index right after punctuation + trailing whitespace.
        let breakPoints = findBreakPoints(in: trimmed)

        let punctuationChunks: [String]?
        if breakPoints.count >= count - 1 {
            punctuationChunks = splitAtBreakPoints(text: trimmed, breakPoints: breakPoints, count: count)
        } else if !breakPoints.isEmpty {
            punctuationChunks = splitAtAllBreakPoints(text: trimmed, breakPoints: breakPoints)
        } else {
            punctuationChunks = nil
        }

        // Validate: punctuation-based result must have the requested chunk count
        // and every chunk must have ≥3 words. Otherwise the user ends up with a
        // 1-word chunk like "Beware," because punctuation clusters at one end.
        // Fall back to even word-boundary splitting in that case.
        if let chunks = punctuationChunks,
           chunks.count == count,
           chunks.allSatisfy({ wordCount(of: $0) >= 3 }) {
            return chunks
        }

        return splitAtWordBoundaries(text: trimmed, count: count)
    }

    private static func wordCount(of text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    // MARK: - Break Point Detection

    /// Find character indices where a new chunk could start (right after punctuation + whitespace)
    private static func findBreakPoints(in text: String) -> [Int] {
        let punctuation: Set<Character> = [".", ",", ";", ":", "!", "?", "\u{2014}"] // includes em-dash
        var points: [Int] = []
        let chars = Array(text)

        var i = 0
        while i < chars.count {
            if punctuation.contains(chars[i]) || chars[i].isNewline {
                // Skip past the punctuation and any trailing whitespace
                var j = i + 1
                while j < chars.count && (chars[j].isWhitespace || chars[j].isNewline) {
                    j += 1
                }
                // Only add if there's text after the break
                if j < chars.count {
                    points.append(j)
                }
                i = j
            } else {
                i += 1
            }
        }

        return points
    }

    // MARK: - Splitting Strategies

    /// Greedily pick the break point closest to each ideal boundary, removing
    /// already-chosen candidates so two ideals can't collapse onto the same break.
    private static func splitAtBreakPoints(text: String, breakPoints: [Int], count: Int) -> [String] {
        let idealSize = Double(text.count) / Double(count)
        var remaining = breakPoints
        var selectedBreaks: [Int] = []

        for i in 1..<count {
            if remaining.isEmpty { break }
            let idealPos = Int(idealSize * Double(i))
            guard let closest = remaining.min(by: { abs($0 - idealPos) < abs($1 - idealPos) }) else { break }
            selectedBreaks.append(closest)
            if let idx = remaining.firstIndex(of: closest) { remaining.remove(at: idx) }
        }

        selectedBreaks.sort()
        return extractChunks(text: text, breaks: selectedBreaks)
    }

    /// Use all available break points (fewer than count-1)
    private static func splitAtAllBreakPoints(text: String, breakPoints: [Int]) -> [String] {
        return extractChunks(text: text, breaks: breakPoints)
    }

    /// Split at word boundaries when no punctuation is available
    private static func splitAtWordBoundaries(text: String, count: Int) -> [String] {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count >= count else {
            // Fewer words than chunks — each word is its own chunk
            return words.map(String.init)
        }

        let wordsPerChunk = Double(words.count) / Double(count)
        var chunks: [String] = []
        var startIdx = 0

        for i in 0..<count {
            let endIdx: Int
            if i == count - 1 {
                endIdx = words.count
            } else {
                endIdx = Int(round(wordsPerChunk * Double(i + 1)))
            }
            let chunk = words[startIdx..<endIdx].joined(separator: " ")
            chunks.append(chunk)
            startIdx = endIdx
        }

        return chunks
    }

    // MARK: - Helpers

    /// Extract trimmed substrings from text given sorted break indices
    private static func extractChunks(text: String, breaks: [Int]) -> [String] {
        var chunks: [String] = []
        let chars = Array(text)
        var start = 0

        for bp in breaks {
            let chunk = String(chars[start..<bp]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                chunks.append(chunk)
            }
            start = bp
        }

        // Last chunk
        let last = String(chars[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty {
            chunks.append(last)
        }

        return chunks
    }
}
