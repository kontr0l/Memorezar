# Known Issues - Memorezar

This document tracks known issues, bugs, workarounds, and ongoing investigations. AI assistants should consult this file at the start of every session and update it with relevant findings from conversations.

---

## Active Issues

### Speech Recognition

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| SPEECH-001 | investigating | Duplicate word sends on transcript revision cause phantom mistakes | Debounce fix implemented - testing |

#### SPEECH-001: Partial Word Revisions Cause Cascading Mistakes

**Severity:** Critical
**Affects:** iOS app
**Files:**
- `ios/Memorezar/Core/Speech/SpeechRecognitionService.swift` (lines 225-233) - sends revisions
- Comparator - advances position on mismatch

**Symptoms:**
- User says ONE word correctly, but gets multiple mistakes counted
- Example: Saying "Juxtaposition" → 4 mistakes (word never matches because position advances)
- Each partial transcription is compared against a DIFFERENT expected word

**Root Cause (CORRECTED ANALYSIS - Feb 2026):**

The problem is more nuanced than initially documented. After analyzing the actual code:

**What happens with default settings (`requireCorrectWord = true`):**
1. **Speech service sends every partial transcription** (lines 225-233) as the recognizer refines output
2. **Comparator does NOT advance position on mismatch** - with default options, position only advances on MATCH
3. **BUT each partial triggers a mismatch alert** at the SAME position
4. **Compound buffer only helps for TRUE prefixes** - "Juxta" is a prefix of "juxtaposition", but "Just" and "Jax" are NOT

**Actual flow when saying "Juxtaposition" (expected word at pos 0):**
```
[SPEECH] → SEND: "Just"
[COMPARE] pos=0 | "just" != "juxtaposition"
         → NOT a prefix (juxtaposition doesn't start with "just")
         → MISMATCH → Alert #1

[SPEECH] → SEND (revision): "Jax"
[COMPARE] pos=0 | "jax" != "juxtaposition"
         → NOT a prefix
         → MISMATCH → Alert #2 (same position!)

[SPEECH] → SEND (revision): "Juxta"
[COMPARE] pos=0 | "juxta" is prefix of "juxtaposition"
         → BUFFERED (no alert)

[SPEECH] → SEND (revision): "Juxtaposition"
[COMPARE] pos=0 | Revision of buffered word detected
         → Buffer cleared, "juxtaposition" == "juxtaposition"
         → MATCH → pos advances to 1
```

**Key Insight:** The problem is NOT position advancing incorrectly. The problem is:
1. Speech recognition's intermediate guesses ("Just", "Jax") don't look like prefixes of the target word
2. The comparator correctly identifies them as mismatches (they ARE different words)
3. Each mismatch triggers an alert, even though they're all attempts at the SAME word
4. User hears 2+ error alerts for speaking ONE word correctly

**Why previous logs showed position advancing:** The earlier documented logs may have been from testing with `requireCorrectWord = false`, or were illustrative examples rather than actual output.

**Potential Fixes (updated):**
1. **Fuzzy prefix matching** - Treat "Just" as potential prefix of "Juxtaposition" using phonetic/edit distance
2. **Debounce revisions** - Don't send a word until N ms have passed without revision
3. **Track revision state** - Pass revision flag to comparator, which suppresses alerts for revisions
4. **Confidence threshold** - Only compare words above a confidence threshold
5. **"Settling" detection** - Buffer ALL words until they haven't changed for N ms

### Word Comparison

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| - | - | No issues logged yet | - |

### Alert System

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| - | - | No issues logged yet | - |

### UI/UX

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| - | - | No issues logged yet | - |

---

## Resolved Issues

Track issues that have been fixed for historical reference.

| Issue | Resolution Date | Description | Solution |
|-------|-----------------|-------------|----------|
| - | - | No resolved issues yet | - |

---

## Investigation Notes

Document ongoing investigations, hypotheses, and debugging sessions.

### Current Investigations

**SPEECH-001 Investigation (Feb 2026) - FIX IMPLEMENTED**
- Initial theory about count drop was WRONG - logs show no count drop occurs
- Second theory about "position advancing on mismatch" was also INCOMPLETE
- With `requireCorrectWord = true` (default), position does NOT advance on mismatch
- The REAL problem: partial transcriptions ("Just", "Jax") aren't prefixes of target ("juxtaposition")
- Each partial is treated as a wrong word → multiple alerts for ONE correctly-spoken word
- The compound buffer DOES help when a partial IS a prefix (e.g., "Juxta" → buffered)

**Fix implemented (Feb 2026):** Debounce mechanism for word revisions
- Added `pendingWord` and `pendingWordTimer` to track pending revisions
- When a revision is detected, wait 150ms before sending to comparator
- If another revision arrives within 150ms, restart the timer
- Pending word is flushed immediately when: new word arrives, result is final, or recognition stops
- This adds ~150ms latency to revised words but prevents multiple alerts for one word
- See `scheduleRevisionSend()` and `flushPendingWord()` in SpeechRecognitionService.swift

### Past Investigation Findings

**Feb 16, 2026 - Duplicate Word Bug Analysis (CORRECTED x2)**

**Hypothesis 1:** Count drop handler doesn't update `lastProcessedWord`.
**WRONG** - Logs proved this isn't the issue.

**Hypothesis 2:** Comparator advances position on each mismatch.
**INCOMPLETE** - With `requireCorrectWord = true` (default), position does NOT advance on mismatch.

**Actual problem (verified via code analysis):**
- Speech recognizer sends partial transcriptions: "Just" → "Jax" → "Juxta" → "Juxtaposition"
- Word count stays at 1 throughout (NO count drop)
- Revision detection code (lines 225-233) fires on each change, sending to comparator
- Comparator stays at position 0 (doesn't advance) but generates MISMATCH for each partial
- Each MISMATCH triggers an alert → user hears 2+ alerts for ONE word
- Only "Juxta" gets buffered (it's an actual prefix); "Just"/"Jax" are not prefixes

The reverted fix (commit 6f9e9b5) addressed count drops, which is a DIFFERENT scenario.
The `requireCorrectWord` option prevents position advancing but doesn't prevent multiple alerts.

---

## Conversation Insights

Key learnings and decisions from development conversations that may be relevant to future work.

### Technical Decisions

*No decisions logged yet*

### Debugging Discoveries

**iOS Speech Recognizer Sends Partial Transcriptions (Feb 2026)**
The iOS speech recognizer continuously refines its transcription as it processes audio. For a word like "Juxtaposition", it may send: "Just" → "Jax" → "Juxta" → "Juxtaposition". This is expected behavior from the recognizer, but the app's revision detection code (lines 225-233) forwards EACH of these to the comparator.

**Comparator Position Behavior (Feb 2026 - CORRECTED)**
With `requireCorrectWord = true` (the default in `ComparatorOptions`), the comparator does NOT advance position on mismatch - only on match. Setting `requireCorrectWord = false` would cause position to advance on mismatch (for skip detection). The multi-alert problem occurs because EACH partial transcription triggers a separate MISMATCH result and alert, even though position stays the same.

**Log Analysis is Essential (Feb 2026)**
Initial theory based on code reading was completely wrong. The actual bug flow was only revealed by examining console logs. Always request/check logs before proposing fixes.

### Performance Observations

*No observations logged yet*

---

## How to Use This Document

### For AI Assistants

1. **Read this file at the start of every session** to understand current issues
2. **Update this file** when:
   - A new bug is discovered during conversation
   - An existing issue is resolved
   - Important debugging insights are found
   - Technical decisions are made that affect known issues
3. **Reference issue IDs** when discussing related problems
4. **Move resolved issues** to the Resolved Issues section with solution details

### Issue Status Values

- `open` - Issue is confirmed and unresolved
- `investigating` - Actively being debugged
- `blocked` - Waiting on external factor
- `resolved` - Fixed (move to Resolved Issues section)

### Adding New Issues

Use this format:
```markdown
| ISSUE-XXX | open | Brief description | Workaround if any |
```

---

*Last Updated: February 2026*
