# Known Issues - Memorezar

This document tracks known issues, bugs, workarounds, and ongoing investigations. AI assistants should consult this file at the start of every session and update it with relevant findings from conversations.

---

## Development Rules

### LOCALIZATION: All user-facing text must be localized

All text that is part of the app UI (buttons, labels, messages, section headers, etc.) **must** be localized. This does not apply to quote pack content, which has its own translation system.

- **iOS:** Use `String(localized:)` or SwiftUI's automatic localization via `Text("...")`. Ensure new strings appear in `Localizable.xcstrings`.
- **Android:** Use string resources (`strings.xml`) or ensure text is wrapped in translation-ready patterns.

### GIT WORKFLOW: Mandatory safeguards on every pull and push

**IMPORTANT:** Multiple devices contribute to this repo. Stale local branches have already caused silent regressions (see GIT-001 below). These three safeguards are **required** on every pull/push:

1. **Always `git pull --rebase` before committing.** This catches stale branches before they become a commit. Do this at the START of every work session, not just before pushing.

2. **Review your own commit before pushing.** Run `git show HEAD --stat` and inspect the numbers. If a file has a suspicious ratio (e.g., large deletions in a commit that's supposed to be a small feature addition), STOP and investigate with `git diff HEAD~1 -- <file>` before pushing.

3. **When resolving conflicts, read BOTH sides carefully before choosing.** Never blindly pick `--ours` or `--theirs` to move on. Use `git diff <commit>:<file>` to compare versions. If the conflict is large, the "other side" often contains teammates' work that would be silently erased.

4. **After `git stash pop` or merge with conflicts, verify file integrity.** Run `wc -l` on every conflicted file before staging. A file that dropped to 0 lines or lost >50% of its content is almost certainly a botched resolution. Never use `sed` to strip conflict markers — it's too easy to over-delete. Resolve manually or with `git checkout --theirs/--ours <file>`.

5. **After staging, run `git diff --cached --stat` and sanity-check the numbers.** Large unexpected deletions (e.g., 540 deletions in a commit about "pack navigation") mean something went wrong. STOP, investigate with `git diff --cached -- <file>`, and fix before committing.

6. **Never `git rebase --skip` without diffing the skipped commit.** A conflicting commit may contain changes that the remote does NOT have — skipping it drops those silently. Before skipping, run `git diff HEAD <commit-hash>` or `git show <commit-hash>` to verify every change in the skipped commit is already present on the remote. If even one hunk is unique, cherry-pick or manually apply it instead of skipping.

For major refactors or multi-device work, use feature branches + PRs so reviewers can catch regressions before they hit main.

---

## Active Issues

### Speech Recognition

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| SPEECH-001 | investigating | Partial word transcriptions cause false errors before word completes | First-word debounce + adaptive settle timer + fuzzy matching |
| SPEECH-002 | investigating | STT splits uncommon words into multiple words (e.g., "encircles" → "In circles") | Fuzzy matching + contextualStrings |
| SPEECH-003 | investigating | STT replaces archaic/uncommon words with common words (e.g., "thine" → "vine", "thy" → "they") | contextualStrings + expanded homophone groups |
| SPEECH-004 | resolved | Long recognition sessions produce transcript corruption (repeating sections) | Proactive session restart every 50s |
| SPEECH-012 | resolved | STT mid-transcript insertion causes missed words and false mismatches | previousWords tracking + restructuring detection |
| SPEECH-013 | resolved | Crash: "Range requires lowerBound <= upperBound" when segments.count < word count | Clamped range in segment debug logging loop |
| SPEECH-014 | resolved | STT word-boundary merge in Spanish causes false mistake (e.g., "veracidad es" → "veracidades") | Revision suffix extraction in processWord |

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

**Fix v2 (Feb 2026): Pending mismatch timer + isRevision flag**

The 150ms debounce was insufficient because:
1. First interim ("Just") bypasses debounce entirely (treated as "new word", not revision)
2. 150ms window too short - "Jug" settles before "Juxta" arrives

New approach: two-layer fix:
- **Layer 1 (Speech):** Increased debounce from 150ms to 200ms. Added `isRevision: Bool` flag to delegate protocol to distinguish new words from revisions.
- **Layer 2 (ViewModel):** Added pending mismatch timer (350ms). Mismatches are deferred instead of triggering alerts immediately. Timer is cancelled on match, restarted on revision/buffer, and fires for real mistakes.

Flow for "juxtaposition" (correctly spoken):
```
"Just" (new)     -> mismatch -> PENDING (start 350ms timer)
"Jug"  (revision) -> mismatch -> PENDING (restart timer)
"Juxta" (revision) -> buffered -> RESET timer (word still refining)
"Juxtaposition"   -> MATCH    -> CANCEL pending -> zero false alerts
```

Edge case handling: if a NEW word (not revision) causes a mismatch at the same position as a pending mismatch, the pending is FIRED first (it was a real mistake from a previous attempt), then the new mismatch becomes pending.

**Fix v2 was insufficient (Feb 2026):** 350ms timer fires BEFORE "Juxta" reaches the ViewModel.
Root cause: "Just" is sent immediately (T=0), but "Juxta" doesn't arrive until ~T=450ms (200ms debounce + recognizer latency). The 350ms timer fires in the gap.

**Fix v3 (Feb 2026):** Two additional changes:
1. **Debounce trailing word on new word path** - "Just" is now debounced at the speech level instead of sent immediately. If "Jax" arrives within 200ms, debounce restarts. "Just" never reaches the ViewModel — only the settled form does. This is the primary fix.
2. **Adaptive settle interval** - Pending mismatch timer now scales with expected word length: 250ms for short words (3-4 chars), up to 700ms for very long words. Formula: `250ms + 40ms * (charCount - 4)`. This is the safety net if a partial slips through the speech debounce.

### Word Comparison

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| COMPARE-001 | resolved | Filler word filter skips words that ARE the expected word (e.g., "so" skipped when pos expects "so") | Check expected word before filtering |

### Alert System

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| - | - | No issues logged yet | - |

### UI/UX

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| UI-001 | resolved | Results screen shows 0 mistakes when look-ahead marks all positions correct | Use mistakes.count instead of totalWords - correctWords |

### Data / Translations

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| DATA-001 | resolved | Ruhi Book 1 pack lost French and Italian translations | Restored from conversation transcript; see details below |

### Git / Workflow

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| GIT-001 | resolved | Stale local branch on second machine silently reverted Android SettingsScreen redesign + Spanish localization when a reading-mode commit was pushed | Restored file from `edd66ff`; safeguards added to Development Rules above |
| GIT-002 | resolved | `git stash pop` conflict resolution emptied iOS SettingsScreen.swift (540 lines deleted) — pushed without catching the loss | Restored from parent commit `c83cce5`; added stash-pop guardrail to GIT WORKFLOW rules |

#### GIT-002: Stash-Pop Conflict Emptied iOS SettingsScreen.swift

**Severity:** High
**Resolved:** 2026-04-17
**File:** `ios/Memorezar/UI/Screens/SettingsScreen.swift`

**What happened:**
During a `git stash pop`, a version-number conflict arose in SettingsScreen.swift. The conflict was resolved with `sed` commands that removed the conflict markers — but a stale file path reference or misapplied sed silently deleted the entire file body, leaving it at 0 lines. The commit (`964d57a`) was pushed with `SettingsScreen.swift | 540 -` in the stat, which should have been caught by the "review before pushing" rule.

**Resolution:**
Restored the full file from parent commit `c83cce5` via `git show HEAD~1:<file>`.

**Lessons (added to GIT WORKFLOW rule above):**
1. Never use `sed` for conflict resolution — too easy to over-delete. Use `git checkout --theirs/--ours <file>` or manually edit in the editor.
2. After `git stash pop` with conflicts, run `wc -l` on every conflicted file to verify it still has content.
3. Existing rule #2 (review `git show HEAD --stat` before pushing) would have caught this — 540 deletions on a "pack navigation" commit is an obvious red flag. **Enforce this rule strictly.**

#### GIT-001: Stale Branch Silently Reverted SettingsScreen.kt

**Severity:** High
**Resolved:** 2026-04-14
**File:** `memorezar-android/app/src/main/java/com/memorezar/app/ui/screens/SettingsScreen.kt`

**What happened:**
Commit `d082997` ("feat: add reading mode to reveal slider") was authored from a Mac whose local copy of SettingsScreen.kt was missing two prior commits: `ff22e15` (icon/card redesign) and `edd66ff` (Spanish localization). When the reading-mode changes were committed and pushed, git also captured the Mac's outdated copy of SettingsScreen.kt alongside the intended RecitationScreen changes — silently erasing ~153 lines of UI work. The commit stat showed **220 insertions vs 373 deletions** on a file that was unrelated to the commit's stated purpose, which should have been a red flag.

A subsequent merge conflict was resolved with `git checkout --ours`, which picked the post-pull (regressed) version rather than the stashed work, compounding the loss.

**Resolution:**
Restored SettingsScreen.kt from commit `edd66ff` (which has the redesign + localization) via `git checkout edd66ff -- <file>`.

**Lessons (now enforced in GIT WORKFLOW rule above):**
1. Always `git pull --rebase` before committing from any device.
2. Run `git show HEAD --stat` before pushing — investigate any file with a suspicious deletions ratio.
3. Never blindly pick `--ours`/`--theirs` in a conflict. Compare both sides first.

#### DATA-001: Ruhi Book 1 Translations Lost During Supabase Migration

**Severity:** Medium
**Resolved:** v35.3 (2026-03-20)
**File:** `ios/Memorezar/Data/Models/SuggestionPack.swift`

**What happened:**
The Ruhi Book 1 pack originally shipped with authentic Spanish, French, and Italian translations (es/fr/it). When packs were moved from bundled data to Supabase (to support remote updates), the bundled fallback was removed. Later, when the Supabase table was found to not exist (HTTP 404), a bundled fallback was recreated — but only with Spanish translations, losing the French and Italian ones.

**Root cause:**
When recreating `SuggestionPack.bundledPacks` as a fallback, the AI assistant did not look up the original translation data before writing the code. It fabricated new Spanish-only translations for all three packs instead of restoring the originals.

**Resolution:**
- Restored the original es/fr/it translations for Ruhi Book 1 from conversation transcript `f2691bf9`
- Removed fabricated Spanish translations from Mark Twain and Einstein packs (originals never had translations)
- Only Ruhi Book 1 should show language badges

**Prevention:**
- When recreating data that previously existed, always search conversation history and git history for the original version first
- Do not fabricate translations — only use authentic, vetted translations
- The Ruhi translations are from official Baha'i Publishing Trust sources and must not be paraphrased or regenerated

---

## Resolved Issues

Track issues that have been fixed for historical reference.

| Issue | Resolution Date | Description | Solution |
|-------|-----------------|-------------|----------|
| NAV-001 | 2026-03-30 | PackSearchView → PackDetailView doesn't load pack on first tap from "See All" | Changed from `NavigationLink(value:)` to inline `NavigationLink { destination }` in PackSearchView, avoiding reliance on parent's `.navigationDestination(for:)` |
| HINT-001 | 2026-03-30 | Tapping visible/revealed words triggers hint animation | Added `isRevealed` check in `isWordTappable` for non-first-letter modes; first-letter mode checks actual letter visibility |
| HINT-002 | 2026-03-30 | Hidden words not revealed on tap in voice/typing modes | Added `flashingWordIndex` check to `wordDisplayMode` for voice/typing/MC/audio modes |
| HINT-003 | 2026-03-30 | Hints broken for short words in typing + first-letter toggle mode | Typing + first-letter toggle now uses word-level visibility (`shouldShowWord`) instead of letter-count check |
| EQUIV-001 | 2026-03-30 | "I said the right word" dispute didn't save equivalence — same false positive recurred every session | `overrideMistake()` now saves to UserEquivalencesStore + reports to EquivalenceService |
| EQUIV-002 | 2026-03-30 | Community equivalences table didn't exist in Supabase | Created `equivalences` table via migration with proper RLS |
| UI-001 | 2026-03-30 | MasteryBadge "Proficient" + "Yesterday" text wrapping in Continue Practicing cards | Changed "Yesterday" to "1d ago" for consistency and fit |

---

## Investigation Notes

Document ongoing investigations, hypotheses, and debugging sessions.

### Current Investigations

**SPEECH-001 Investigation (Feb 2026) - FIX v2 IMPLEMENTED**
- Initial theory about count drop was WRONG - logs show no count drop occurs
- Second theory about "position advancing on mismatch" was also INCOMPLETE
- With `requireCorrectWord = true` (default), position does NOT advance on mismatch
- The REAL problem: partial transcriptions ("Just", "Jug") aren't prefixes of target ("juxtaposition")
- Each partial is treated as a wrong word → multiple alerts for ONE correctly-spoken word
- The compound buffer DOES help when a partial IS a prefix (e.g., "Juxta" → buffered)

**Fix v1 (Feb 2026):** Debounce mechanism for word revisions
- Added `pendingWord` and `pendingWordTimer` to track pending revisions
- When a revision is detected, wait 150ms before sending to comparator
- If another revision arrives within 150ms, restart the timer
- Pending word is flushed immediately when: new word arrives, result is final, or recognition stops
- **INSUFFICIENT:** First word ("Just") bypasses debounce (treated as new, not revision). Also 150ms too short - "Jug" settles before "Juxta" arrives. Result: 2 false alerts for "juxtaposition".

**Fix v2 (Feb 2026):** Pending mismatch timer in ViewModel
- Added `isRevision: Bool` to `SpeechRecognitionDelegate` protocol - speech service marks settled/flushed words as revisions, new words as non-revisions
- Increased speech debounce from 150ms to 200ms
- Added `pendingMismatchResult` and `pendingMismatchTimer` (350ms) in RecitationViewModel
- Mismatches are deferred: timer starts on mismatch, restarts on revision/buffer, cancels on match
- New word (non-revision) mismatch at same position fires the pending mismatch first (handles "wrong word then retry" scenario)
- `speechRecognitionDidEnd` fires any pending mismatch (no more words coming)
- `pause()`/`reset()` cancel pending mismatch
- **INSUFFICIENT:** 350ms timer fires before "Juxta" reaches ViewModel (~450ms gap). See log analysis.

**Fix v3 (Feb 2026):** Debounce trailing new words + adaptive settle interval
- Changed speech service "new word" path: trailing word is now debounced via `scheduleRevisionSend()` instead of sent immediately. Confirmed words (all but trailing) still sent immediately.
- Made pending mismatch settle interval adaptive: scales with expected word length (250ms-700ms). Formula: `250ms + 40ms * (charCount - 4)`.
- Expected result for "juxtaposition": "Just" gets debounced → "Jax" revision restarts debounce → "Juxta" revision restarts → "Juxtaposition" revision restarts → 200ms later sends "Juxtaposition" → MATCH. Zero words sent before final form.
- Files changed: `SpeechRecognitionService.swift`, `RecitationViewModel.swift`, `HomeScreen.swift` (v1.4)

**Fix v4 / SPEECH-002 (Feb 2026):** Fuzzy matching for STT word-splitting errors
- **New issue discovered:** STT splits uncommon words into multiple words. "encircles" → "And circle" → "In circles". The recognizer never produces "encircles" as a single word. No amount of debouncing/timing can fix this.
- Added Levenshtein edit distance function to `WordComparator`
- Added `isFuzzyMatch()` in `checkMatch()` as last-resort matching:
  - Spoken word must be >= 5 chars, expected >= 7 chars
  - Spoken must be >= 75% of expected word's length
  - Levenshtein similarity must be >= 75%
- "circles" vs "encircles": ED=2, similarity=78% → FUZZY MATCH
- "and" vs "encircles": too short, too dissimilar → NOT match
- Increased adaptive timer scale from 40ms to 60ms per char beyond 4 (more time for longer words)
- Files changed: `WordComparator.swift`, `RecitationViewModel.swift`, `HomeScreen.swift` (v1.5)

**Fix v5 / SPEECH-003 (Feb 2026):** contextualStrings for uncommon vocabulary
- **New issue discovered:** STT replaces archaic/uncommon words with common words. "thine" → "vine" consistently. The recognizer doesn't have "thine" in its active vocabulary. Fuzzy matching can't help because "vine" (4 chars) is too short and only 60% similar.
- **Root cause fix:** Use `SFSpeechAudioBufferRecognitionRequest.contextualStrings` to prime the recognizer with the target text's words. Apple docs: "An array of phrases that should be recognized, even if they are not in the system vocabulary."
- Changed `startListening()` to accept `contextualStrings: [String]` parameter
- ViewModel passes `comparator.getTargetWords()` when starting recognition
- This should improve recognition of ALL uncommon words in the target text ("thine", "encircles", "maidservant", etc.) at the source, before any post-processing
- Files changed: `SpeechRecognitionService.swift`, `RecitationViewModel.swift`, `HomeScreen.swift` (v1.6)

**Fix v6 / SPEECH-003 continued (Feb 2026):** Expanded archaic word homophone groups
- "thy" → "they" observed in logs. The "thy" homophone group `["thy", "thigh", "the"]` was missing "they".
- "thou" → "though" reported by user. Missing from "thou" group.
- "thine" → "vine" still occurring despite contextualStrings. Added dedicated homophone group.
- Updated groups:
  - `["thou", "you", "tho", "though", "thow"]`
  - `["thy", "thigh", "the", "they", "die"]`
  - `["thine", "vine", "fine", "dine", "mine"]` (new)
- Files changed: `WordComparator.swift`, `HomeScreen.swift` (v1.7)

**Fix v7 / COMPARE-001 (Feb 2026):** Filler word filter skipping expected words
- **Critical bug:** The filler word list includes common words: "so", "well", "you", "like", "know". When these appear in the target text, the filler filter skipped them BEFORE checking if they matched the expected word.
- Example: target has "so" at pos 36. User says "so". Comparator skips it as filler. Comparator stays stuck at pos 36. Every subsequent word mismatches → cascading false errors.
- Fix: Before skipping a filler word, check if it matches the expected word at the current position. If it does, don't skip.
- Files changed: `WordComparator.swift`, `HomeScreen.swift` (v1.8)

**Fix v8 / SPEECH-003 continued (Feb 2026):** Further expanded "thy" homophone group
- Log analysis showed recognizer trying "by", "die", "why", "they" for "Thy" at position 23.
- "die" eventually matched via existing homophone group, but "by" and "why" were not in the group and caused unnecessary pending mismatches before "die" was tried.
- Also observed transcript corruption (repeating transcript sections) during long recognition sessions — separate issue, not yet addressed.
- Updated "thy" group: `["thy", "thigh", "the", "they", "die", "by", "why", "high", "eye"]`
- Files changed: `WordComparator.swift`, `HomeScreen.swift` (v1.9)

**Fix v9 / SPEECH-002 continued (Feb 2026):** Compound buffer consuming words + multi-word join
- **Bug discovered:** When the compound buffer combine fails (e.g., buffer "made" + new word "maidservant" = "mademaidservant" ≠ "maidservant"), the new word was consumed without being checked independently. "maidservant" arrived from STT but was never compared against expected "maidservant" — a direct match was lost.
- **Fix 1 (bug fix):** When buffer combine fails and the combined result isn't a prefix, clear the buffer and fall through to normal comparison instead of returning a mismatch. The new word now gets independently compared.
- **Fix 2 (feature):** Multi-word join buffer. Tracks the last 4 mismatched words at the same stuck position. After each new mismatch, tries joining the last 2-3 consecutive words and checking via `checkMatch()` (which includes fuzzy matching). Example: STT produces "mate" + "servant" → joined "mateservant" vs "maidservant" → Levenshtein distance 2, similarity 82% → FUZZY MATCH.
- This handles the case where STT splits compound words into parts that individually don't match but together are close to the expected word.
- Files changed: `WordComparator.swift`, `HomeScreen.swift` (v2.1)

**Fix v9b / SPEECH-002 continued (Feb 2026):** Multi-word join improvements for compound buffer interaction
- **Problem:** When compound buffer "maids" was flushed (combine "maids"+"ser"="maidsser" failed), the flushed word wasn't included in the multi-word buffer. Also, STT partials "ser" → "servan" accumulated as separate entries instead of being recognized as revisions.
- **Fix 1:** Seed the multi-word buffer with the flushed compound buffer word so it participates in joins
- **Fix 2:** In multi-word buffer, detect when new word extends the last entry (hasPrefix) and replace instead of appending. "ser" → "servan" becomes a single entry.
- Result: "maids" (from buffer) + "servan" (revised from "ser") = "maidsservan" ≈ "maidservant" (Levenshtein distance 2, similarity 82%) → FUZZY MATCH
- Files changed: `WordComparator.swift`, `HomeScreen.swift` (v2.2)

**Fix v10 / SPEECH-004 (Feb 2026):** Proactive session restart to prevent transcript corruption
- **Problem:** Apple's `SFSpeechRecognizer` degrades after ~60 seconds. The transcript starts repeating sections ("sweet scented fragrance" sent twice), and the final result arrives empty (`words=0, lastProcessed=57`).
- **Fix:** Proactively restart the recognition session every 50 seconds. The audio engine stays running — only the recognition task is swapped. A `sessionGeneration` counter ensures results from the cancelled old task are ignored.
- **Implementation:** `startSessionRestartTimer()` fires after 50s → `restartRecognitionSession()` cancels old task, creates new request (reusing contextualStrings), starts new task. The existing audio tap reads `self.recognitionRequest`, so swapping the request seamlessly redirects audio to the new session.
- Also added guard for empty final results (transcript corruption symptom).
- Files changed: `SpeechRecognitionService.swift`, `HomeScreen.swift` (v2.3)

**Fix v13 / SPEECH-005b (Feb 2026):** Pending mismatch not cancelled on look-ahead match
- **Problem:** When look-ahead matches at a position beyond the pending mismatch (e.g., pending at pos 10, look-ahead matches at pos 11), the pending mismatch was not cancelled because the cancellation check used `==` instead of `>=`. This caused a false mistake to fire for a position that look-ahead had already skipped past and marked as correct.
- **Fix:** Changed `pendingMismatchResult?.position == result.position` to `result.position >= pendingPos`. Now any match at or beyond the pending position cancels the stale pending mismatch.
- Files changed: `RecitationViewModel.swift`, `HomeScreen.swift` (v2.5)

**Fix v12 / SPEECH-004b (Feb 2026):** Session restart replay bug (v2.5-v2.7, multiple iterations)
- **Problem:** After the 50s proactive session restart, the new recognition session replays the old transcript, causing all previously-processed words to be re-sent to the comparator as "new" words.
- **v2.5 attempt:** Keep `lastProcessedWordCount` across restart + `isPostRestart` flag. FAILED — the cancelled old task's empty final result resets `lastProcessedWordCount = 0` via the empty-final handler, and the `isPostRestart` fresh-start path also resets to 0 when the count drops. Both paths defeat the fix.
- **v2.7 fix (robust):** Post-restart replay guard at the TOP of `handleRecognitionResult()`, before any final/interim branching:
  - Save `preRestartWordCount` before restart
  - Skip ALL results (final or interim) while `words.count <= preRestartWordCount`
  - Final results during post-restart are ignored completely (from cancelled old task)
  - Once `words.count > preRestartWordCount`, set `lastProcessedWordCount = preRestartWordCount` and resume normally — only genuinely new words get processed
  - 3-second timeout clears post-restart state if the replay never catches up (user paused)
- Files changed: `SpeechRecognitionService.swift`, `HomeScreen.swift` (v2.7)
- **v2.9 fix (threading):** The v2.7 guard was logically correct but never triggered. Root cause: **threading race condition**. Apple's `SFSpeechRecognitionTask` fires its result handler on an arbitrary background queue, but `restartRecognitionSession()` runs on the main thread (Timer callback). The background thread reads `isPostRestart`/`preRestartWordCount` before the main thread writes are visible — no memory barrier, no synchronization.
  - Fix: Wrap `handleRecognitionResult` in `DispatchQueue.main.async` in BOTH callback sites (initial `startListening` and `restartRecognitionSession`). This ensures:
    1. All state access (isPostRestart, preRestartWordCount, lastProcessedWordCount) happens on the main thread
    2. Timer callbacks (restart, debounce) and recognition callbacks are naturally serialized
    3. Timers created inside handleRecognitionResult are on the main run loop (correct behavior)
  - Latency impact: negligible (~1ms for main queue dispatch), delegate callbacks already dispatch to main via `Task { @MainActor }`
- Files changed: `SpeechRecognitionService.swift`, `HomeScreen.swift` (v2.9)

**Fix v14 / UI-001 (Feb 2026):** Results screen mistake counter shows 0
- **Problem:** After recitation with look-ahead matching, the results screen showed 0 mistakes even though 5 mistake alerts fired. Root cause: results screen used `totalWords - correctWords` to display mistakes. But look-ahead marks skipped positions as `.correct` (even positions where mistakes were fired), so `correctWords` = `totalWords` → 0 mistakes displayed.
- **Fix 1:** Changed results screen to use `session.mistakes.count` instead of `session.totalWords - session.correctWords`
- **Fix 2:** Changed `PracticeSession.accuracy` to use `(totalWords - mistakes.count) / totalWords` instead of `correctWords / totalWords`
- Files changed: `RecitationScreen.swift`, `Quote.swift`, `HomeScreen.swift` (v3.0)

**Fix v15 / SPEECH-004c (Feb 2026):** Restart replay caused by stopListening() not invalidating generation
- **Problem:** The v2.9 `DispatchQueue.main.async` fix was correct for the restart timer case, but the replay at the end of recitation had a different cause. When recitation completes, `pause()` → `stopListening()` resets `lastProcessedWordCount = 0` and `isPostRestart = false`, but does NOT increment `sessionGeneration`. The cancelled task's pending callbacks (dispatched to main) pass the generation check and see `lastProcessedWordCount = 0` → all old words replayed.
- **Fix:** Add `sessionGeneration += 1` at the start of `stopListening()`. Any queued/pending callbacks from the old task fail the generation check and are filtered out.
- Files changed: `SpeechRecognitionService.swift`, `HomeScreen.swift` (v3.0)

**Fix v11 / SPEECH-005 (Feb 2026):** Look-ahead resync for STT word merging
- **Problem:** STT sometimes merges consecutive words into one. "O Thou" → "Although". The app gets stuck at position 0 expecting "O" while the user keeps speaking correctly. Every subsequent word mismatches.
- **Fix:** After 3 consecutive mismatches at the same position, try matching the spoken word against the next 5 expected words (look-ahead). If a match is found, skip to that position and resync.
- Example: "Although" (miss), "most" (miss), "glorious" (miss → look-ahead → matches pos 3!) → skip to pos 4
- ViewModel updated to handle position jumps: skipped words are marked as correct (user spoke them, STT couldn't match individually).
- `result.position` now used instead of `previousPosition` to mark the matched word correctly in the UI.
- Files changed: `WordComparator.swift`, `RecitationViewModel.swift`, `HomeScreen.swift` (v2.4)

**Fix v16 / SPEECH-005c (Feb 2026):** More aggressive look-ahead to prevent cascading failures
- **Problem:** When STT fails to recognize "Thy" and produces "love" instead, the word "love" is consumed as a mismatch at the "Thy" position. After "that" matches "Thy" via homophone, the comparator advances to expect "love" — but the user already said it. The app gets stuck for 8+ words (should, be, filled, with, rapture, ecstasy...) until a distant look-ahead match or multiple mistake alerts fire.
- **Root cause:** Look-ahead threshold of 3 was too conservative. "be" (the 2nd mismatch word at pos 35) matched expected "be" at pos 40, but look-ahead hadn't activated yet (needed 3 mismatches). By the time look-ahead activated on the 3rd mismatch ("filled"), none of the words matched in the look-ahead range.
- **Fix:** Reduced look-ahead threshold from 3 to 2 and increased range from 5 to 8 words. With threshold=2: "should" (miss #1) → "be" (miss #2, look-ahead triggers) → matches expected "be" at pos 40 → resync after just 1 false alert instead of 4+.
- Files changed: `WordComparator.swift`, `HomeScreen.swift` (v3.0)

**User-defined word equivalences (Feb 2026):**
- New feature: "Accept as match" button on mistake display lets users teach the app their voice's STT patterns
- `UserEquivalencesStore` persists mappings via UserDefaults, checked in `checkMatch()` after direct match, before homophones
- Files changed: `UserEquivalencesStore.swift` (new), `MemorezerApp.swift`, `WordComparator.swift`, `RecitationViewModel.swift`, `RecitationScreen.swift`, `HomeScreen.swift` (v2.0)

**Fix v17 / SPEECH-006 (Feb 2026):** Look-ahead false jump on common short words + bloated homophone group
- **Problem:** User paused before "Thou art the Mighty and the Powerful." When they said "the" (for the first "the"), two bugs cascaded:
  1. STT produced "that" which matched "the" at pos 52 via homophones (the "thy" group contained both "that" and "the")
  2. Then "the" triggered look-ahead at pos 53 (expected "Mighty") and jumped to pos 55 (the second "the"), skipping "Mighty" and "and"
- **Root cause 1:** The "thy" homophone group had grown to include "that", "by", "why", "high", "eye" — making them ALL equivalent to "the". "that" is NOT a homophone of "the".
- **Root cause 2:** Look-ahead had no minimum word length. Short words like "the" (3 chars) appear many times in any quote, so matching them ahead is almost always a false positive.
- **Fix 1:** Trimmed "thy" homophone group from `["thy", "thigh", "the", "they", "that", "die", "by", "why", "high", "eye"]` to `["thy", "thigh", "they", "die"]`. Removed "the" (now only in its own group `["the", "thee", "da"]`), "that", "by", "why", "high", "eye". Deleted redundant `["thee", "the", "thy"]` group. Users can handle voice-specific STT confusions via "Accept as match".
- **Fix 2:** Added `lookAheadMinWordLength = 4` — look-ahead only jumps for spoken words >= 4 characters. "the", "a", "and", "of", "is" etc. are too common to reliably identify position.
- Files changed: `WordComparator.swift`, `HomeScreen.swift` (v3.3)

**Fix v18 / SPEECH-006b (Feb 2026):** Look-ahead partial word match causing orphaned split word
- **Problem:** User said "O thou most maidservant" (skipping 5 words). STT produced "Almost made servant". "made" triggered look-ahead at pos 0, matched "maidservant" at pos 8 via user equivalences (user previously accepted "made" as match for "maidservant"). Look-ahead jumped to pos 9. Then "servant" (the second half of split "maidservant") arrived at pos 9, expected "of" → false mistake.
- **Root cause:** Look-ahead allowed a 4-char word to match an 11-char word (36% length ratio). "made" was just the first half of a split word, not a complete match. The second half ("servant") was orphaned after the jump.
- **Fix:** Added length ratio check in look-ahead: spoken word must be at least 50% of the expected word's length (`normalizedSpoken.count * 2 >= expectedLen`). This prevents partial/split words from triggering look-ahead jumps to much longer expected words.
  - "made" (4) vs "maidservant" (11): 4*2=8 < 11 → SKIP ✓
  - "circles" (7) vs "encircles" (9): 7*2=14 >= 9 → MATCH ✓ (legit fuzzy match)
  - "might" (5) vs "mighty" (6): 5*2=10 >= 6 → MATCH ✓
- Files changed: `WordComparator.swift`, `HomeScreen.swift` (v3.4)

**Fix v19 / SPEECH-007 (Feb 2026):** Look-ahead broken with `requireCorrectWord=false`
- **Problem:** With `requireCorrectWord=false`, the comparator advances position on every mismatch. The consecutive mismatch counter tracked per-position, so it reset to 0 on each mismatch (new position ≠ old position). Look-ahead threshold of 2 was never reached → look-ahead never triggered. This caused cascading position shifts when STT absorbed a word (e.g., "Thine" skipped, "blessed" matches at wrong position, everything shifts by 1 for 8+ words).
- **Example:** pos 10 expected "Thine", got "blessed" (STT skipped "Thine"). Position advances to 11. Now pos 11 expected "blessed", got "and" — missed match! Cascades through pos 12-17 until "cherished" resyncs at pos 18. Only 2 of 8 mismatches actually fired as alerts (pendings silently replaced each other).
- **Fix 1 (WordComparator):** Dual-mode mismatch tracking:
  - `requireCorrectWord=true`: per-position tracking (existing behavior, threshold=2)
  - `requireCorrectWord=false`: global tracking across positions (threshold=1, any mismatch triggers look-ahead immediately)
  - With threshold=1: "blessed" at pos 10 → look-ahead → finds "blessed" at pos 11 → MATCH! No cascade.
- **Fix 2 (RecitationViewModel):** Fire pending mismatch when position changes. Old behavior: pending only fired when new mismatch was at the same position. With `requireCorrectWord=false`, each mismatch is at a different position → old pending silently dropped. New behavior: any non-revision mismatch fires the existing pending (works for both modes).
- Files changed: `WordComparator.swift`, `RecitationViewModel.swift`, `HomeScreen.swift` (v3.5)

**Fix v20 / SPEECH-008 (Feb 2026):** Partial words and split words cause cascading off-by-one with requireCorrectWord=false
- **Problem 1 (Revision desync):** With `requireCorrectWord=false`, when STT sends a partial word (e.g., "char" for "cherished"), it mismatches and the comparator advances. The full revision ("cherished") arrives at the NEXT position — permanent off-by-one.
- **Problem 2 (Split word desync):** STT splits compound words across position boundaries. "maidservant" → "mate" (pos 8, mismatch, advance) + "servant" (pos 9, mismatch). Each half consumes a position, but only one expected word was spoken. The multi-word join in the comparator can't help because each mismatch resets the buffer (position changed).
- **Problem 3 (Silent pending drop):** "servant" is flagged `isRevision=true` by the speech service (it's a revision of "ser" in the transcript). The `!isRevision` guard in processComparisonResult prevents firing the pending for "mate" — so the pending is silently replaced, never counted as a mistake or cancelled.
- **Fix 1 (Revision rescue):** Before sending a revision to the comparator, check if it matches the expected word at the pending mismatch's position via `checkMatchAtPosition()`. Handles "char"→"cherished" case.
- **Fix 2 (Pending join rescue):** Before sending ANY word to the comparator, try joining `pending.spokenWord + newWord` and check against the pending's expected word. "mate"+"servant"="mateservant" vs "maidservant" → fuzzy match (82% similarity). Cancels pending, commits match, skips comparator. The comparator already advanced past the position (correct since one expected word was consumed).
- **Fix 3 (Pending firing for different-position revisions):** Changed pending fire condition from `!isRevision` to `!isRevision || result.position != pending.position`. A "revision" at a different comparator position is actually a different word (speech service flags it as revision due to transcript-level debounce mechanics). This prevents silent pending drops.
- **Guard conditions:** Rescues only activate when `requireCorrectWord=false`. With `requireCorrectWord=true`, the comparator stays at the same position, so the compound buffer and multi-word join handle split words naturally.
- Files changed: `WordComparator.swift`, `RecitationViewModel.swift`, `HomeScreen.swift` (v3.6)

**v4.0 Major Simplification (Feb 2026):**
- **Removed `ComparatorOptions` struct entirely.** Behavior is now hardcoded: always case insensitive, ignore punctuation, ignore fillers, allow contractions, always require correct word.
- **Removed `requireCorrectWord=false` mode** and all code supporting it:
  - Dual-mode look-ahead tracking (global vs per-position)
  - Revision rescue in ViewModel (checking revisions against pending mismatch positions)
  - Pending join rescue in ViewModel (joining pending + new word for split compounds)
  - `checkMatchAtPosition()` method on WordComparator
  - `comparator.updateOptions()` method
  - Position advancing on mismatch (3 locations in comparator)
- **Removed auto-hint timer.** Hints are now manual only (tap the Hint button). Removed `hintTimer`, `startHintTimer()`, `stopHintTimer()` from RecitationViewModel.
- **Removed 8 settings properties:** `caseSensitive`, `ignorePunctuation`, `ignoreFillerWords`, `allowContractions`, `requireCorrectWord`, `showHints`, `hintDelay`, `autoRestartOnCompletion`. Removed corresponding UI sections (Comparison, Practice) from SettingsScreen and accessors from SettingsStore.
- **Replaced inline mistake display with popup alert.** On mismatch: listening pauses, alert shows expected/said with two buttons:
  - "It's a Match" → saves equivalence, removes mistake, advances position, resumes listening
  - "It's Wrong" → keeps mistake counted, resumes listening (user retries word)
- **Added `advancePosition()` to WordComparator** for the popup "It's a Match" flow.
- Files changed: `Settings.swift`, `SettingsStore.swift`, `SettingsScreen.swift`, `WordComparator.swift`, `RecitationViewModel.swift`, `RecitationScreen.swift`, `HomeScreen.swift` (v4.0)

**Fix v22 / SPEECH-010 (Feb 2026):** Dropped words cause permanent desync — look-ahead unreachable in popup flow
- **Problem:** STT dropped "Thy" entirely ("of Thy love" → "of love"). "love" arrived at pos=34 where "Thy" was expected → popup. After "It's Wrong", comparator at pos=34 but speech already past "Thy" → permanent desync.
- **v4.3 attempt (REVERTED):** Lowered comparator `lookAheadThreshold` from 2 to 1. Fixed the "Thy"/"love" case but caused a NEW problem: look-ahead with threshold=1 was too aggressive — it jumped ahead on earlier words and skipped "fragrance" at its correct position. When "fragrance" arrived from STT later, comparator was already at "Thou" (pos=50) → false mistake.
- **v4.4 fix (two-layer approach):**
  1. **Reverted** lookAheadThreshold back to 2 (prevents false jumps during compareWord)
  2. **Added ViewModel-level sync recovery** in `firePendingMismatch()`: before showing the popup, call `comparator.tryMatchAhead(spoken:, range: 2)` which checks if the spoken word matches one of the next 1-2 expected words. If yes → STT dropped a word → auto-resync, no popup. If no → real mistake → show popup.
  - This is more targeted than the comparator's look-ahead: only fires at popup-time, small range (2 vs 8), doesn't affect the main compareWord flow.
  - The comparator's threshold=2 look-ahead can still fire during the settle interval if a 2nd word arrives before the pending timer, providing an additional sync opportunity.
- Files changed: `WordComparator.swift`, `RecitationViewModel.swift`, `HomeScreen.swift` (v4.4)

**Fix v23 / SPEECH-011 (Feb 2026):** Speech restart echo causes false mismatch on already-matched word
- **Problem:** User correctly said "cherished" (matched, marked green), but then the popup showed Expected: "at", Said: "cherished". The speech engine sent "cherished" twice.
- **Root cause:** After a mistake popup, `confirmMistake()` restarts the speech service fresh (`startListening()`). The new recognition session picks up residual audio from the user's mouth still finishing "cherished". It transcribes this as a new word "cherished" and sends it. The comparator has already advanced past "cherished" and now expects "at" → false mismatch.
- **Fix:** Added echo filter in `WordComparator.compareWord()`: if the spoken word exactly matches the previous target word (position-1) but doesn't match the current expected word, it's an echo from a speech restart — return nil (ignore it). Uses `checkMatch` for the current word to ensure homophones/equivalences aren't accidentally filtered.
- **Edge cases handled:** Consecutive identical words (e.g., "the the") → second "the" matches current position via `checkMatch`, so NOT filtered. User genuinely says wrong word matching previous → silently ignored (better UX than false popup).
- Files changed: `WordComparator.swift`, `HomeScreen.swift` (v4.5)

**Fix v21 / SPEECH-009 (Feb 2026):** Pending mismatch silently replaced by subsequent words, then cancelled by look-ahead
- **Problem:** User said "banana" instead of "maidservant" — app didn't catch it. Three-step failure:
  1. "banana" → pending mismatch (0.82s timer for 11-char "maidservant")
  2. "of" arrived as `isRevision: true` (flushed by speech service). ViewModel's `!isRevision` guard prevented firing "banana" — silently REPLACED with "of". Same for "dying".
  3. "Thine" → look-ahead match at pos=10 → cancelled pending at pos=8. Real mistake lost.
- **Root cause:** `flushPendingWord()` in speech service always sends with `isRevision: true` (line 401). Flushed words are confirmed trailing words (a new word appeared after them), NOT revisions of the pending mismatch. But the ViewModel treated all `isRevision=true` words as harmless revisions that shouldn't fire the pending.
- **Why fuzzy matching didn't help:** "banana" (6 chars) vs "maidservant" (11 chars) — fuzzy matching requires spoken word to be >= 75% of expected word's length (8.25 chars). 6 < 8.25 → fuzzy matching never attempted.
- **Fix:** Once a pending mismatch is scheduled, don't let new mismatches replace it. Ignore new mismatch results entirely while a pending exists. The pending fires via its timer or gets cancelled by a match (look-ahead).
- **Why this works for both cases:**
  - "banana" case: pending fires via 0.82s timer (at T=820ms), BEFORE "Thine" arrives (~T=1200ms). Popup shows correctly.
  - Merged-words case ("O Thou" → "Although"): subsequent words match via look-ahead QUICKLY (within 200-400ms settle window) and cancel the pending. No false popup.
- Files changed: `RecitationViewModel.swift`, `HomeScreen.swift` (v4.1)

**Fix v24 / SPEECH-012 (Mar 2026):** STT mid-transcript insertion causes missed words and false mismatches
- **Problem:** STT restructures the transcript mid-stream, inserting words at indices below `lastProcessedWordCount`. Example: transcript has 22 words ending in "threshold" (`lastProcessedWordCount=22`). STT restructures to 23 words: a word earlier in the transcript gets merged/dropped, shifting "threshold" from index 21 to 20. "of" appears at index 21. Only index 22 ("th", partial of "Thy") is above the high water mark and gets sent. "of" at index 21 is never sent to the comparator. "th" is compared against expected "of" → false mismatch.
- **Root cause:** The high-water-mark approach (`lastProcessedWordCount`) only sends words at indices >= the mark. When STT inserts words below the mark (by shifting existing words), those insertions are invisible.
- **Fix:** Store `previousWords: [String]` — the words array from the last processed result. When new words arrive (`words.count > lastProcessedWordCount`), compare the word at `lastProcessedWordCount - 1` in the new transcript against the same index in `previousWords`. If they differ, the transcript was restructured. Scan backwards to find where the last confirmed word shifted to, then lower `effectiveStart` to include the newly inserted words.
- **Algorithm:**
  1. `prevBoundaryWord = previousWords[lastProcessedWordCount - 1]`
  2. `newBoundaryWord = words[lastProcessedWordCount - 1]`
  3. If different → scan backwards from `lastProcessedWordCount - 2` looking for `prevBoundaryWord`
  4. If found at index `j` → set `effectiveStart = j + 1` (the inserted words start right after)
  5. Send words from `effectiveStart` instead of `lastProcessedWordCount`
- **Example flow:** previousWords[21]="threshold", words[21]="of" → mismatch → scan: words[20]="threshold" → effectiveStart=21 → sends "of" (previously missed) → "th" debounced as trailing
- **Guard:** Only lowers effectiveStart when the word is found at a strictly lower index (revision without shift doesn't trigger). Case-insensitive comparison.
- Files changed: `SpeechRecognitionService.swift`, `HomeScreen.swift` (v9.9)

**v13.7 / Confidence-Gated Matching + Phonetic Tolerance Layer (Mar 2026):**
- **Problem:** False positives from accents/pronunciation — ASR transcribes incorrectly but the user said the right word. Hardcoded homophone groups can't cover all ASR confusions.
- **Three-layer fix:**
  1. **ASR alternative hypotheses:** Apple's Speech framework provides per-word alternative transcriptions (0-3). The comparator now checks alternatives against the expected word when the primary transcription fails. Many false positives had the correct word in the alternatives.
  2. **Double Metaphone phonetic matching:** New `DoubleMetaphone.swift` implements Lawrence Philips' algorithm (~400 lines). Produces two 4-char phonetic codes per word. Two words match if any code combination matches. Guards: both words >= 3 chars, length ratio >= 60%. Positioned in match hierarchy after homophones/contractions, before fuzzy matching. Target word codes pre-computed at setup; only spoken word encoded per comparison (~0.01ms).
  3. **Confidence gating:** Per-word confidence scores from SFTranscriptionSegment are now plumbed through to the comparator and ViewModel. Mismatches at low/medium confidence (< 0.85) are classified as `.uncertain` (orange) instead of `.incorrect` (red). Uncertain mistakes don't count toward accuracy and don't trigger alert sounds. Low-confidence mismatches extend the settle timer (+200-300ms) to give the ASR more time to revise.
- **New `WordState.uncertain`:** Orange word state for low-confidence mismatches. Users can tap orange words — popup says "Did you mean [expected]? I heard [spoken]" with "Yes, I said it right" button.
- **New `MistakeCertainty` enum:** `.definite` (high confidence, counts in accuracy) and `.uncertain` (low confidence, shown in review). `PracticeMistake` now includes `confidence: Float` and `certainty: MistakeCertainty` with backward-compatible decoding.
- **Results screen:** Accuracy circle uses only definite mistakes. Collapsible "Possible Mismatches" section shows uncertain mistakes with confidence percentages.
- **New `MatchType` enum:** Tracks how each match was determined (exact, userEquivalence, communityEquivalence, homophone, contraction, phonetic, alternativeMatch, fuzzy, mismatch). `ComparisonResult` now includes `confidence` and `matchType` fields.
- **Match hierarchy:** exact → userEquivalence → communityEquivalence → homophone → contraction → phonetic → alternativeMatch → fuzzy → mismatch
- **Latency impact:** ~0.1ms total added per word comparison (well within 50ms budget).
- Files changed: `DoubleMetaphone.swift` (new), `WordComparator.swift`, `SpeechRecognitionService.swift`, `RecitationViewModel.swift`, `RecitationScreen.swift`, `Quote.swift`, `HomeScreen.swift` (v13.7), `project.pbxproj`

**v13.8 / SPEECH-004d (Mar 2026):** Post-restart timeout drops all new words
- **Problem:** After the 50s proactive session restart, if the new session starts fresh (no replay of old transcript), the post-restart timeout fires after 3 seconds and sets `isPostRestart = false`. But `lastProcessedWordCount` stays at the old high water mark (e.g., 42). The new session's transcript starts at word count 1, 2, 3... which is always less than 42 → every result hits the "COUNT DROP" path → all words permanently dropped. User speaks correctly but nothing reaches the comparator.
- **Root cause:** Post-restart timeout handler only cleared `isPostRestart` but didn't reset `lastProcessedWordCount`, `lastProcessedWord`, or `previousWords`.
- **Fix:** When the post-restart timeout fires, also reset `lastProcessedWordCount = 0`, `lastProcessedWord = ""`, and `previousWords = []`. The new session's words are then treated as genuinely new.
- **Also fixed:** Confidence-based settle timer extension was adding +300ms to ALL mismatches because interim results always report `confidence = 0.0` (Apple only provides real confidence in final results). Changed to only add extra settle time when actual non-zero confidence < 0.85 is available. Unknown (0.0) confidence no longer penalizes settle timing.
- Files changed: `SpeechRecognitionService.swift`, `RecitationViewModel.swift`, `HomeScreen.swift` (v13.8)

**v30.1 / SPEECH-014 (Mar 2026):** STT word-boundary merge in non-English locales causes false mistakes
- **Problem:** In Spanish, saying "veracidad es" causes the STT to revise "veracidad" → "veracidades" (the plural noun) because they're acoustically identical. The already-matched word at pos=1 gets revised by merging with the next syllable. The merged word "veracidades" arrives as a revision at pos=2 where "es" is expected → false mismatch.
- **Root cause:** Apple's speech recognizer sometimes merges a completed word with the following word when they form a valid word in the target language. This is a word-boundary ambiguity specific to non-English locales (Spanish "veracidad es" ≈ "veracidades", potentially similar patterns in other languages).
- **Fix:** In `processWord()`, when a revision arrives (`isRevision=true`) and the previous word was already matched (`.correct`), check if the revision starts with the previously-matched word. If so, extract the suffix and compare that against the current expected word instead. For the example: "veracidades" starts with "veracidad" → suffix "es" → matches expected "es" at pos=2.
- **Guard:** Only applies when `isRevision=true` AND previous word state is `.correct`, preventing false positives on genuine mismatches.
- Files changed: `RecitationViewModel.swift`

**v13.9 / Library Photo Grid (Mar 2026):** Category photo covers + Unsplash integration
- **Feature:** Replaced the flat quote list with chip filters with a 2-column photo grid of category "books". Each card shows a cover photo with category name overlaid. Tapping navigates to a CategoryDetailView with the quote list.
- **Model change:** Replaced `QuoteCategory.icon: String` with `imageSource: CategoryImageSource` enum (`.local(filename)`, `.unsplash(info)`, `.none`). Custom decoder handles migration from old icon-based categories (sets `.none`). Removed `availableIcons` and `presets`.
- **New files:**
  - `UnsplashService.swift` — async Unsplash API client (search + random photo + TOS download trigger)
  - `PhotoSourcePicker.swift` — sheet for picking cover photos via Camera, Photo Library, or Unsplash search
- **Auto-assignment:** New categories and suggestion packs auto-fetch a random Unsplash photo as cover (fire-and-forget Task, graceful fallback to `.none` on failure).
- **Local images:** Camera/Photo Library images saved as JPEG (0.8 quality) to `Documents/category_images/`. Cleaned up on category deletion.
- **Camera permission:** Added `NSCameraUsageDescription` to Info.plist.
- **Removed:** `SuggestionPack.icon` property, `QuoteCategory.presets`, `QuoteCategory.availableIcons`, `CategoryChip` view, icon grid in `CategoryEditView`.
- Files changed: `Quote.swift`, `SuggestionPack.swift`, `QuoteStore.swift`, `QuoteLibraryScreen.swift` (rewrite), `QuoteInputView.swift`, `HomeScreen.swift` (v13.9), `Info.plist`, `project.pbxproj`, `UnsplashService.swift` (new), `PhotoSourcePicker.swift` (new)

**v14.0 / Brain Character Mascot (Mar 2026):** Sprite sheet character system
- **Feature:** Added a 12-character brain mascot sprite sheet (4x3 grid) throughout the app. Characters are cropped at runtime from a single sprite sheet image via `BrainCharacterManager` (CG-based cropping with caching).
- **Character groups:**
  - **Hero (home page top):** meditating, praying, meditatingMat, candlelight — randomized on each visit
  - **Mistakes (popup):** stubbedToe, brokenVase, carCrash, spilledDrink — rotated on each popup appearance
  - **Success (results):** studying, workout, reading, exercising — shown when accuracy >= 50%
  - **Section decorators:** workout (stats), stubbedToe (needs practice), studying (suggestions), reading (library/empty states)
- **New files:** `BrainCharacterView.swift` (enum + manager + view), `BrainCharacters.imageset` (asset catalog)
- **Placements:** HomeScreen hero, stats header, needs practice header, suggestions header, library header, empty library, RecitationScreen mistake popup, ResultsView, QuoteLibraryScreen empty state
- Files changed: `HomeScreen.swift` (v14.0), `RecitationScreen.swift`, `QuoteLibraryScreen.swift`, `BrainCharacterView.swift` (new), `project.pbxproj`

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

**User-Defined Word Equivalences (Feb 2026)**
Hardcoding every possible STT substitution in the homophone groups doesn't scale — the recognizer produces unpredictable variants depending on the user's voice, accent, and speaking speed. Instead of expanding homophone lists reactively, v2.0 lets users define their own equivalences via an "Accept as match" button on the mistake display.

- `UserEquivalencesStore` persists mappings in UserDefaults (`memorezar_user_equivalences`)
- Equivalences are checked in `WordComparator.checkMatch()` after direct match, before homophones — user-defined mappings take priority over hardcoded ones
- Mappings are normalized (lowercased, punctuation stripped) for consistent matching
- Equivalences take effect immediately in the current session and persist across app launches

### Debugging Discoveries

**iOS Speech Recognizer Sends Partial Transcriptions (Feb 2026)**
The iOS speech recognizer continuously refines its transcription as it processes audio. For a word like "Juxtaposition", it may send: "Just" → "Jax" → "Juxta" → "Juxtaposition". This is expected behavior from the recognizer, but the app's revision detection code (lines 225-233) forwards EACH of these to the comparator.

**Comparator Position Behavior (Feb 2026 - CORRECTED)**
With `requireCorrectWord = true` (the default in `ComparatorOptions`), the comparator does NOT advance position on mismatch - only on match. Setting `requireCorrectWord = false` would cause position to advance on mismatch (for skip detection). The multi-alert problem occurs because EACH partial transcription triggers a separate MISMATCH result and alert, even though position stays the same.

**Log Analysis is Essential (Feb 2026)**
Initial theory based on code reading was completely wrong. The actual bug flow was only revealed by examining console logs. Always request/check logs before proposing fixes.

**Speech Debounce Only Catches Revisions, Not First Words (Feb 2026)**
The speech service's revision debounce (scheduleRevisionSend) only triggers when `words.count == lastProcessedWordCount` and the last word changed. The FIRST interim result for a word goes through the "new word" path (`words.count > lastProcessedWordCount`) and is sent immediately with no debounce. This is why "Just" (the first partial of "juxtaposition") bypassed the 150ms debounce entirely.

**STT Splits Uncommon Words Into Multiple Words (Feb 2026)**
iOS speech recognizer sometimes cannot recognize uncommon words as single words. Example: "encircles" → "And circle" → "In circles" (two words). The recognizer genuinely interprets the audio as two separate words. This is fundamentally different from the "juxtaposition" problem (where the word count stays at 1 and only the transcription is revised). For word-splitting, no amount of debouncing helps — we need fuzzy matching at the comparator level.

**Pending Mismatch Timer Design (Feb 2026)**
Moving the debounce from the speech layer to the ViewModel (alert layer) is more effective because:
1. It has access to comparison results (match vs mismatch), not just raw words
2. Correct words have ZERO added latency (matches are processed immediately)
3. The `isRevision` flag enables handling the "wrong word then retry" edge case
4. Buffer/nil results from the comparator reset the timer (word still being refined)
The tradeoff is ~350ms added latency for real mistake detection.

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

## Pack System Architecture

### PACK-001: Supabase-Only Pack System

**Status:** Implementing (March 2026)
**Priority:** High — prerequisite for paywall

#### Background

Quote packs previously had a 3-tier fallback: Supabase → cache → bundled Swift packs. This is being changed to Supabase-only because:
- Next phase puts packs behind a paywall — bundled/cached packs would bypass that
- Pack data (quotes, translations, metadata) should be managed server-side
- Users should only have offline access to packs they've explicitly added to their library

#### Pack Management Rules

1. **Supabase is the single source of truth.** All packs come from the `suggestion_packs` table. No bundled fallback for browsing.
2. **No internet = no browse.** If Supabase is unreachable, the Browse Quote Packs section is hidden. No cache fallback.
3. **Added packs live offline.** Once a user taps "Add to Library", quotes are persisted locally. Available regardless of network.
4. **Sync on every launch.** `syncInstalledPacks` fires at QuoteStore init. Updates installed packs when server `version` > local version, preserving all practice stats.
5. **Match by pack ID, not name.** Categories store a `sourcePackId` so sync is resilient to server-side name changes.
6. **Language defaults to system language.** When viewing or adding a pack, use system language if translation exists, else English. Pack name/description stay English (not translated in this phase).
7. **Version bumps trigger updates.** To push changes to users who already added a pack: bump the `version` integer in Supabase. App auto-syncs on next launch.

#### Supabase Table Schema

```sql
CREATE TABLE suggestion_packs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  cover_search_query TEXT,
  cover_url TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  quotes JSONB NOT NULL
);
```

`quotes` column format:
```json
[
  {
    "title": "The betterment of the world",
    "text": "The betterment of the world can be accomplished...",
    "translations": {
      "es": { "title": "El mejoramiento del mundo", "text": "..." },
      "fr": { "title": "L'amélioration du monde", "text": "..." }
    }
  }
]
```

#### Admin Workflow (How to Update Packs)

1. **Add a new pack:** Insert a row into `suggestion_packs` with `version: 1`
2. **Update an existing pack:** Edit the row, bump `version` by 1
3. **Fix a translation:** Edit the quotes JSONB, bump `version`
4. **Add a new language:** Add translation keys to quotes JSONB, bump `version`
5. **Remove a pack from browse:** Delete the row (users who already added it keep their local copy)

#### Code Changes

| File | Change |
|------|--------|
| `Quote.swift` | Add `sourcePackId: String?` to `QuoteCategory` with backward-compatible decoding |
| `QuoteStore.swift` | Set `sourcePackId` in `addSuggestionPack()`, check it in `isPackAdded()` |
| `PackService.swift` | Remove cache/bundled fallback from `fetchPacks()` (remote → []), match sync by `sourcePackId` |
| `SuggestionPack.swift` | Mark bundled packs as seed data only (comment, not runtime) |

#### Key Design Decision: sourcePackId

Categories store `sourcePackId: String?` linking them back to the Supabase pack they came from. This replaces matching by name in `syncInstalledPacks`, which was fragile — renaming a pack on the server would break the sync. Now sync matches `categories.first(where: { $0.sourcePackId == packId })` and also updates the category name if it changed server-side.

---

## Translation & Language System

### How Multi-Language Quotes Work

Quotes in Supabase are stored in English as the canonical form, with translations as a nested JSONB object:

```json
{
  "title": "The betterment of the world",
  "text": "The betterment of the world can be accomplished...",
  "translations": {
    "es": { "title": "El mejoramiento del mundo", "text": "..." },
    "fr": { "title": "L'amélioration du monde", "text": "..." }
  }
}
```

### Language Swap on Add

When a user adds a pack, `QuoteStore.addSuggestionPack()` checks the system language via `LanguageHelper.preferredLanguageCode`. If a translation exists for that language:

1. The translated title/text becomes the Quote's primary `title`/`text` fields
2. The English original is stored as `translations["en"]`
3. The system language key is removed from `translations` (to avoid duplication)
4. `primaryLanguage` is set to the system language code (e.g. `"es"`)

**Example:** Spanish device adds Ruhi pack → Quote stores Spanish as primary, English/French/Italian as translations. The `primaryLanguage` field is `"es"`.

For English devices (or when no translation exists), `primaryLanguage` is `nil` (meaning English).

### The `primaryLanguage` Field

`Quote.primaryLanguage: String?` — tracks which language the primary title/text is in.

- `nil` = English (default, backward compatible with all existing quotes)
- `"es"` = Spanish is primary, etc.

This field is critical for the recitation screen's language pill — without it, the UI doesn't know what language the "original" text is in and defaults to showing "EN".

### LANG-001: Language Pill Showed Wrong Language (Resolved)

**Status:** Resolved (March 2026)

**Symptoms:**
- Badge showed "EN" even when the quote text was in Spanish
- Language picker showed "English" twice (once as the "original", once from the `"en"` translation key)
- Other languages showed correctly (French, Italian)

**Root Cause:** The language pill in `RecitationScreen` hardcoded `"en"` as the fallback for `activeLanguage ?? "en"`. When a Spanish user added a pack, the primary text was Spanish but the UI assumed it was English. The `"en"` key in the translations dict then appeared as a duplicate.

**Fix:** Added `primaryLanguage: String?` to `Quote`, set during pack import. The recitation screen now uses `viewModel.primaryLanguageCode` (which reads `quote.primaryLanguage ?? "en"`) instead of hardcoded `"en"` in:
- The language pill badge text and colors
- The language picker menu (first "original" entry)
- All recording language labels

**Files changed:**
- `Quote.swift` — added `primaryLanguage` field with backward-compatible Codable decoding
- `QuoteStore.swift` — `addSuggestionPack()` and `replaceQuotes()` set `primaryLanguage`
- `RecitationViewModel.swift` — added `primaryLanguageCode` computed property
- `RecitationScreen.swift` — replaced all `?? "en"` fallbacks with `?? viewModel.primaryLanguageCode`

**Note:** Users who added packs before this fix need to remove and re-add the pack to populate `primaryLanguage` on existing quotes.

---

## Adaptive Difficulty System (Reveal & Familiarity)

### Overview

The app progressively hides words as the user gets better at reciting a quote. New quotes start with almost all words visible; well-practiced quotes show almost none. The system uses **effective accuracy** — raw accuracy weighted by difficulty — so gaming the reveal slider or using hints doesn't inflate scores.

### Key Concepts

| Term | Definition |
|------|------------|
| **Reveal %** | Percentage of upcoming words shown as hints (0 = all hidden, 100 = all visible). Controlled by slider on recitation screen. |
| **Raw accuracy** | `(totalWords - definiteMistakes) / totalWords`. Stored per session. |
| **Effective reveal** | `min(100, sliderReveal + hintReveal)` where `hintReveal = hintCount / totalWords * 100`. Accounts for both slider position and hints used. |
| **Effective accuracy** | `rawAccuracy * (1 - effectiveReveal / 100)`. The core metric. A perfect score with everything visible = 0.0. |
| **Familiarity** | Average effective accuracy across the **last 3 sessions** for a quote. Drives the next session's default reveal. |

### Formula

```
effectiveReveal = min(100, sliderReveal + (hintCount / totalWords * 100))
effectiveAccuracy = rawAccuracy * (1 - effectiveReveal / 100)
familiarity = avg(effectiveAccuracy) over last 3 sessions
defaultReveal = clamp(95 - familiarity * 90, 5, 95)
```

### Examples

| Scenario | Raw Acc | Slider | Hints | Eff. Reveal | Eff. Accuracy |
|----------|---------|--------|-------|-------------|---------------|
| New user, reading along | 100% | 95% | 0 | 95% | 0.05 |
| Cheating: slider at 100% | 100% | 100% | 0 | 100% | 0.00 |
| Honest practice, some help | 90% | 30% | 2/50 | 34% | 0.59 |
| Strong recall, minimal hints | 95% | 5% | 1/50 | 7% | 0.88 |
| Perfect, no help | 100% | 0% | 0 | 0% | 1.00 |

### Reveal Progression (typical user journey)

| Familiarity | Default Reveal | Meaning |
|-------------|---------------|---------|
| 0.00 (new) | 95% | Almost all words visible |
| 0.25 | 72% | Three-quarters visible |
| 0.50 | 50% | Half visible |
| 0.75 | 27% | Mostly hidden |
| 1.00 | 5% | Nearly all hidden |

### Anti-Gaming Properties

- **Slider to 100%**: effective accuracy = 0, familiarity drops, next session gets *easier* (user rewinds own progress)
- **Excessive hints**: each hint adds to effective reveal, lowering effective accuracy proportionally
- **3-session window**: one lucky/cheated run can't permanently lock difficulty — it rolls off after 3 sessions
- **No cliffs**: smooth linear curve instead of hardcoded jumps at practice counts

### Data Model

`PracticeSession` stores `revealPercentage` (slider at session end) and `hintCount`. Old sessions decoded before this change default to `revealPercentage: 50`, `hintCount: 0` for backward compatibility.

### Key Files

| File | What |
|------|------|
| `Quote.swift` → `PracticeSession` | `effectiveAccuracy` computed property, `revealPercentage` & `hintCount` fields |
| `RecitationViewModel.swift` → `calculateDefaultReveal()` | Familiarity formula using last 3 sessions |
| `RecitationViewModel.swift` → `calculateChunkDefaultReveal(at:)` | Same formula for split chunks, falls back to legacy chunk accuracy |
| `RecitationViewModel.swift` → `createSession()` / `createChunkSession()` | Passes current reveal % and hint count when recording sessions |

### Design Decisions

1. **Last 3 sessions, not all-time best**: Recent performance matters more than a personal best from weeks ago. If you're rusty, the system adapts.
2. **Slider value at session end**: If user adjusts mid-session, the final position is what counts — that's the difficulty they completed at.
3. **Old sessions default to 50% reveal**: A neutral assumption. Not harsh (0%) or generous (100%).
4. **Clamped to 5-95**: Never fully hidden (always some scaffolding) and never fully shown (always some challenge).

### LEVEL-001: 3-Level Reveal Ladder Demotes on <70% Accuracy (Intentional)

**Status:** by-design — do NOT "fix"

The discrete 3-level reveal ladder (Level 1 = 90% reveal / Learning, Level 2 = 50% / Advancing, Level 3 = 20% / Proficient) **demotes the user one level when a session ends below 70% accuracy**. It has come up multiple times whether this should be removed because "users shouldn't go backwards." The answer is **no** — demotion is intentional and both iOS and Android match.

**Rules (as implemented in both apps):**
- Promote: `accuracy ≥ 90%` AND `currentLevel < 3` AND the reveal % actually used in the session supports the current level (`achievedFromReveal ≥ currentLevel`). New level = `min(3, achieved + 1)`.
- Demote: `accuracy < 0.70` AND `currentLevel > 1` → drop one level. Floor at level 1.
- Mastered quotes (`masteryStreak ≥ 3`) always open at level 3 regardless of stored level.

**Why demotion stays:** without it, a user who memorized a quote weeks ago and is now rusty would stay locked at level 3 (20% reveal) and fail every session. Demoting one level gives them more scaffolding so they can rebuild confidence, then re-promote. It's a single-step soft reset, not a full reset — the mastery streak is a separate counter and is unaffected by regular-session demotion.

**Key files:**
- iOS: `ios/Memorezar/UI/ViewModels/RecitationViewModel.swift` → `checkLevelAdvancement(accuracy:)` (lines ~362-391)
- Android: `memorezar-android/app/src/main/java/com/memorezar/app/ui/viewmodels/RecitationViewModel.kt` → `checkLevelAdvancement(accuracy)`

---

## Mastery Challenge System

### Overview

Mastery is an intentional challenge, not an automatic badge. Users explicitly enter "Master mode" and must pass 3 consecutive tests at 95%+ accuracy with 0% reveal and no hints. Mastery can be lost if a retest goes badly, and stale mastery (14+ days without practice) is surfaced for retesting.

### How It Works

1. **Enter Master Mode**: Tap the crown button (top-left of recitation screen). Always available.
2. **Locked conditions**: Reveal slider locked to 0% (disabled + dimmed). Tapping a word shows a popup: "No help — prove you know it!" with a character sprite. No hints allowed.
3. **Pass threshold**: 95%+ raw accuracy (since reveal is 0% and hints are 0, effective accuracy = raw accuracy).
4. **3 consecutive passes**: Each pass increments `masteryStreak` (0 → 1 → 2 → 3). At 3, the Mastered badge is earned.
5. **1 failure = reset**: Any test below 95% resets `masteryStreak` to 0. Must start over.
6. **Exit anytime**: Tap the crown again to leave master mode. Streak is preserved — you can come back later.

### Mastery Demotion

- If a user with Mastered status (streak ≥ 3) retests in master mode and scores below 95%, their streak resets to 0 and they lose the badge immediately.
- They drop back to Proficient (or whatever their practice count/accuracy qualifies for).
- Must complete the full 3/3 challenge again to re-earn Mastered.

### Stale Mastery

- A mastered quote becomes "stale" after 14 days without practice (`isMasteryStale` on `Quote`).
- Stale quotes should be surfaced to the user for retesting (UX TBD — could be a home screen section, badge indicator, or notification).
- The staleness itself doesn't demote — only a failed retest does.

### Auto-Progression (Unchanged)

The first four mastery levels still auto-progress based on practice count and accuracy:

| Level | Criteria |
|-------|----------|
| New | 0 practices |
| Beginner | Any practice, accuracy < 60% |
| Learning | Accuracy ≥ 60% |
| Proficient | 3+ practices, accuracy ≥ 80% |
| **Mastered** | **Manual: 3 consecutive master-mode passes at 95%+** |

### Data Model

| Field | Type | Location | Description |
|-------|------|----------|-------------|
| `masteryStreak` | `Int` | `Quote` | 0-3: consecutive master-mode passes. ≥ 3 = Mastered. |
| `isMasteryStale` | `Bool` (computed) | `Quote` | True if mastered and `lastPracticedAt` > 14 days ago |
| `isMasterMode` | `Bool` | `RecitationViewModel` | Whether the current session is a mastery challenge |
| `showMasterModeHintBlock` | `Bool` | `RecitationViewModel` | Triggers the "no hints" popup |

### Key Files

| File | What |
|------|------|
| `Quote.swift` | `masteryStreak` field, updated `masteryLevel` computed property, `isMasteryStale` |
| `RecitationViewModel.swift` | `enterMasterMode()`, `exitMasterMode()`, `recordMasteryResult()`, hint blocking in `tapWord()` |
| `RecitationScreen.swift` | Crown toolbar button, disabled slider, hint-block popup, mastery progress in ResultsView |

### ResultsView in Master Mode

- Shows 3 crown icons (filled = passed, outline = remaining)
- Mastery-specific messages: "X more to go!", "Mastered!", "Progress reset — 0/3", "You lost your mastery"
- Try Again stays in master mode (doesn't recalculate reveal)
- Both Try Again and Done record the mastery result before proceeding

### Design Decisions

1. **Mastery is opt-in**: Users choose when to attempt it. No pressure, no surprise difficulty spikes.
2. **3 consecutive, not 3 total**: Proves consistent recall, not a lucky run.
3. **0% reveal, no hints**: If you need help, you don't know it yet. Clean and unambiguous.
4. **1 failure demotes**: Mastered means you know it *now*, not that you knew it once.
5. **Staleness doesn't auto-demote**: We recommend retesting but don't punish absence. Only actual poor performance removes the badge.
6. **Crown icon**: Chosen because it's distinct from the star (removed) and communicates achievement/challenge.

---

## Upcoming Features

### FEATURE-001: Text-to-Speech Quote Playback

**Priority:** Medium
**Complexity:** Low

**Description:** Add a "Listen" mode that reads the quote aloud on repeat using `AVSpeechSynthesizer`, so users can learn by listening before they practice reciting.

**Implementation Notes:**
- Use iOS built-in `AVSpeechSynthesizer` — no API keys or dependencies needed, works offline
- ~15 lines of core code
- Supports multiple languages (matches existing translation support)
- Configurable speech rate (`.rate`), pitch, and voice selection (Siri voices sound better than default)
- **Audio session consideration**: App uses `.playAndRecord` for mic. Speech synthesis works with this, but need to decide: separate "listen only" mode vs. playing while reciting
- **Suggested UX**: Add a "Listen" button on the recitation screen that reads the quote aloud on repeat. User listens a few times, then switches to recitation mode
- Could read full text at once or pause between sentences/chunks

---

### TUTORIAL-001: Spotlight Walkthrough (Shelved)

**Status:** Shelved — code preserved, trigger disabled
**Files:**
- `ios/Memorezar/UI/Screens/RecitationScreen.swift` — `showSpotlightTutorial` and `showRecitationTutorial` flags (lines ~303-307), `spotlightTutorialSteps` array (line ~2436), overlay logic (lines ~388-402)

**Description:** A multi-step spotlight walkthrough that highlights each control on the recitation screen (mode tabs, reveal slider, word grid, first letter button, crown, language, info bar, mic button). Fully implemented but disabled while the onboarding flow tutorial is being built. To re-enable, uncomment `showSpotlightTutorial = true` in the `.onAppear` block. Consider gating behind `tutorialStore.shouldShowTip(.recitationIntro)` so it only shows once.

---

## Android-Specific Issues

Android's `SpeechRecognizer` is fundamentally different from iOS's `SFSpeechRecognizer`. iOS provides a continuous streaming session with per-word confidence, alternatives, and contextual priming. Android stops after every final result, requiring a destroy-and-recreate cycle. This creates **session gaps** — periods of 150-700ms where audio is lost permanently. Much of the Android voice mode work is about mitigating these gaps.

### ANDROID-SPEECH: Session Gap Architecture

**Severity:** Architectural limitation
**Affects:** Android app (all devices)
**Files:**
- `memorezar-android/app/src/main/java/com/memorezar/app/core/speech/SpeechRecognitionService.kt`
- `memorezar-android/app/src/main/java/com/memorezar/app/ui/viewmodels/RecitationViewModel.kt`
- `memorezar-android/app/src/main/java/com/memorezar/app/core/comparison/WordComparator.kt`

#### The Problem

| Aspect | iOS (SFSpeechRecognizer) | Android (SpeechRecognizer) |
|--------|--------------------------|---------------------------|
| Session model | Continuous stream | Stops after each final result |
| Per-word confidence | Yes (segment-level) | No (result-level only) |
| Per-word alternatives | Yes (alternativeSubstrings) | No |
| Contextual priming | contextualStrings array | Not available |
| Gap between sessions | None (continuous) | 150-700ms (audio lost) |

When Android's recognizer delivers a FINAL result, it stops. We must destroy and recreate the recognizer to continue. During this gap:
- The user may still be speaking
- 1-4 words can be lost depending on speaking speed
- Position tracking desyncs because the comparator never sees those words

#### Mitigations Implemented (v2.4.3 → v2.4.19)

**1. High Water Mark (replay guard)**
After each restart, the new recognizer may replay words from its audio buffer that overlap with the previous session. `highWaterMark` tracks how many words were emitted before the restart. Words below this mark are skipped to prevent duplicate processing.

**2. Deferred Mismatch Settlement**
When a mismatch is detected, it's held as `pendingMismatch` for ~500ms before confirming. This gives time for the correct word to arrive from a new session after a gap. If the correct word arrives during the settle window, the mismatch is cancelled.

**3. Sync Recovery via Look-Ahead (confirmMismatch)**
When a mismatch is confirmed, `confirmMismatch()` does a broader look-ahead (`maxJump=5`) to find if the spoken word matches a position further ahead. If found, skipped positions are marked CORRECT (assumed lost in the session gap) and position jumps forward. Normal processing uses a conservative `maxJump=2` to prevent premature jumps.

**Known limitation:** Sync recovery can be too aggressive. If the user says completely wrong words and then says a word that matches something far ahead, positions in between get incorrectly marked CORRECT. Example: saying "banana apple pineapple virtues" on the quote "Truthfulness is the foundation of all human virtues" — "virtues" matches pos 7, so pos 2-6 get marked CORRECT even though they were never spoken. This is an acceptable trade-off for now since the common case (session gaps during correct recitation) is more important than the adversarial case.

**4. isRestarting Guard**
Prevents overlapping restarts. Set to `true` in all restart paths (FINAL result, error handler, proactive timeout) and cleared only after the new recognizer is created.

### ANDROID-ERR11: OnePlus Service Unbinding Race (Error 11)

**Severity:** Medium (mitigated)
**Affects:** OnePlus devices (confirmed on OnePlus 15), possibly other OEMs
**Status:** Mitigated

**Root Cause:** When we destroy the old `SpeechRecognizer` and immediately create a new one, the Android speech service framework logs `ServiceConnector.Impl: Service is unbinding` and the new recognizer gets error 11 (`ERROR_LANGUAGE_NOT_SUPPORTED`). This is NOT a real language support error — it's a race condition where the service hasn't finished unbinding.

**Fix:** `RESTART_DELAY_MS = 150ms` — enough time for the service to fully unbind before creating the new recognizer. Error 11 does NOT count toward `consecutiveErrorCount` and always retries with a fixed 150ms delay (no backoff, since backoff creates larger dead zones where audio is lost).

### ANDROID-ERR-DISPLAY: No Errors Shown to User

**Severity:** Low
**Status:** Resolved (v2.4.9)

All speech recognition errors are handled silently. The `onError` handler auto-restarts the recognizer for any error while listening, never calling `delegate?.onError()`. This was done because:
- Error 11 fires on nearly every restart on OnePlus — confusing "Language not supported" messages
- Error 7 (no speech) fires when the user pauses — confusing "No speech detected" messages
- Error 8 (recognizer busy) fires during overlapping restarts — confusing "Recognition service busy" messages
- None of these errors are actionable by the user

The user can always tap the mic button to manually restart if something truly breaks. After `MAX_CONSECUTIVE_REAL_ERRORS` (8) real errors, the recognizer gives up silently.

### ANDROID-LOCALE: Device Locale Mismatch

**Severity:** Low
**Status:** Resolved (v2.4.10)

`localeForLanguageCode()` hardcoded `"en"` → `"en-US"`, but the OnePlus device had `en-GB` as default. The recognizer got error 11 on `en-US` and fell back to `en-GB` every time. Fixed by checking if the device's language matches the requested language code — if so, use the device locale directly (e.g., device `en-GB` + quote `en` → use `en-GB`).

### ANDROID-STUCK: PendingMismatch Lifecycle Bug

**Severity:** Critical
**Status:** Resolved (v2.4.6)

**Symptom:** App permanently stuck at a word, never advancing regardless of what the user says.

**Root Cause:** In `confirmMismatch()`, when the recovery path (tryMatchNext/tryMatchAhead) succeeded, the function returned WITHOUT setting `pendingMismatch = null`. All subsequent words hit the "pending already exists" guard and were ignored forever.

**Fix:** Added `pendingMismatch = null` at the top of the recovery success path, before the return.

### ANDROID-BACKOFF: Exponential Backoff Counterproductive

**Severity:** Medium
**Status:** Resolved (v2.4.5)

**Lesson learned:** Exponential backoff (100→200→400→800→1600ms) for error 11 was counterproductive. Since error 11 is a race condition (not a load issue), backing off just creates larger dead zones where audio is lost. Fixed by using a fixed 150ms delay for error 11 and mild linear backoff (150, 300, 450, 600ms max) for real errors only.

### Future Considerations

- **Deepgram or Google Cloud Speech v2:** If the built-in `SpeechRecognizer` session gap problem proves too limiting, the `SpeechRecognitionDelegate` interface abstracts the provider, making it straightforward to swap in a streaming API that doesn't have session gaps.
- **Sync recovery tuning:** The `maxJump=5` in `confirmMismatch` could be made smarter — e.g., only allow large jumps when the preceding mismatch was a near-miss (phonetic match) rather than a total mismatch, or mark skipped positions as SKIPPED instead of CORRECT.

---

## BACKUP-001: Auto-Backup Disabled (Manual Only)

**Severity:** N/A (design decision)
**Status:** Intentionally disabled

**What exists:** `CloudBackupService.scheduleBackup()` is wired into all store save methods (`QuoteStore.saveQuotes/saveSessions/saveCategories`, `SettingsStore.saveSettings`, `UserEquivalencesStore.save`, `TutorialStore.save` + `hasCompletedOnboarding` didSet) with a 5-second debounce. The infrastructure for automatic background backup after every data change is fully implemented.

**What's disabled:** All `scheduleBackup()` calls are commented out with `// BACKUP-001: auto-backup disabled, manual only`. The "Cloud Backup" status row in SettingsScreen is also removed.

**Current behavior:** Users must tap **"Back Up Now"** in Settings → Account to trigger a backup. Restore works via **"Restore from Backup"** button or the auto-restore prompt on sign-in.

**To re-enable auto-backup:** Uncomment the 7 `scheduleBackup()` calls across the 4 store files, and optionally restore the "Cloud Backup" status row in SettingsScreen showing last backup time.

**Why disabled:** User preference — wants backup to be an explicit user action for now. May revisit later if users request automatic sync.

---

*Last Updated: April 2026*
