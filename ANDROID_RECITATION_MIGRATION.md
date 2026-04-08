# Android Recitation Screen Migration Guide

## Overview

This document specifies exactly what the Android RecitationScreen must implement to reach iOS parity. The iOS RecitationScreen is 4,480 lines; the Android version is currently 343 lines. The iOS RecitationViewModel is 700+ lines; Android is 322 lines.

**The core speech pipeline (SpeechRecognitionService, WordComparator, AlertManager, TextChunker) is already production-ready on Android.** The gap is entirely in the UI layer and ViewModel state management.

---

## CURRENT ANDROID STATE (What Works)

- Voice mode: start/stop listening, word-by-word comparison, instant alerts
- Basic word display (FlowRow with color-coded states)
- Progress bar
- Audio level visualization
- Completion view with accuracy %
- Try Again / Done buttons

## WHAT'S MISSING (Prioritized)

### P0 — Core Recitation Experience (Must Have)

#### 1. Word Hide/Reveal System
The most critical missing feature. iOS hides words based on a reveal percentage.

**Word Display Modes:**
- `full` — complete word shown
- `firstLetter` — "C____" (first letter + underscores)
- `letters(count)` — "Cor___" (N letters + underscores)
- `hidden` — gray outlined box (no text visible)

**Reveal Slider (3-level discrete):**
- Level 1 (right): 90% of words revealed, 3 letters shown in first-letter mode
- Level 2 (center): 50% revealed, 2 letters shown
- Level 3 (left): 20% revealed, 1 letter shown
- Thumb: 26dp blue circle with eye icon
- While dragging: shows number (90/50/20 or 3/2/1)
- Auto-hides label after 2 seconds
- Disabled (dimmed) in master mode

**Reveal Logic:**
```
1. Get all pending word indices (after currentPosition)
2. Calculate revealCount = pendingIndices.count * (revealPercentage / 100)
3. Randomly select revealCount indices → mark as isRevealed = true
4. Revealed words show full text; hidden words show box or first letter
```

**WordDisplayState needs:**
```kotlin
data class WordDisplayState(
    val id: String = UUID.randomUUID().toString(),
    val word: String,
    val state: WordState,
    val isRevealed: Boolean = false  // ← ADD THIS
)
```

**Tap-to-peek:**
- Tapping a hidden word reveals it for 1 second (counts as hint)
- Increments `hintCount`
- Blocked in master mode (shows popup instead)

#### 2. Mode Selector Bar
Horizontal segmented control at top of screen with 4-5 modes:

```
[ 🎤 Voice | ⌨️ Typing | 🔲 Multiple Choice | ♫ Audio ]
```

**Layout:**
- HStack, 42dp height, 9dp corner radius
- White sliding indicator behind active segment
- Active icon: primary color; inactive: secondary
- Right side: Exit button (door icon, 32dp)

**Mode enum (already exists):** VOICE, TYPING, MULTIPLE_CHOICE, AUDIO
- FIRST_LETTER is a toggle within voice/typing, not a separate tab

#### 3. Bottom Control Bar (Dark Pill)
The stats bar at the bottom is critical for the practice experience.

**Layout:** Dark rounded pill (#333333, 36dp corner radius)

**Contents (left to right):**
| INFO | ✓ Correct | ✗ Mistakes | 💡 Hints | RESTART |
|------|-----------|------------|----------|---------|

- INFO: Opens accuracy detail sheet
- Correct count: green checkmark + number (20sp bold, monospacedDigit)
- Mistakes count: red X + number
- Hints count: yellow lightbulb + number
- RESTART: arrow.counterclockwise icon, calls reset()
- Each stat: 40dp width, centered

**Above the pill (80dp height) — action buttons:**

Voice mode:
```
[ First-Letter Toggle (44dp) ] [ MIC BUTTON (80dp) ] [ Crown (44dp) ]
```

Typing mode:
```
[ First-Letter Toggle (44dp) ] [ TEXT INPUT (flexible) ] [ Crown (44dp) ]
```

Multiple choice: MC grid shown above, no input buttons

#### 4. Mic Button States
- **Idle:** 80dp blue circle, mic icon (34sp white), shadow
- **Listening:** Yellow liquid fill overlay + VoiceWaveformView (5 bars)
- **Pause icon:** After 2s silence, waveform fades out, pause icon (30sp) fades in

**VoiceWaveformView:**
- 5 vertical bars (8dp wide, 5dp spacing)
- Min height: 11dp, max height: 53dp
- Different scale per bar: [0.5, 0.85, 1.0, 0.75, 0.45]
- Height = minHeight + (maxHeight - minHeight) * audioLevel * barScale
- 80ms animation for level changes

#### 5. First-Letter Toggle Button (Left of Mic)
- 44dp circle, gray background
- Icon: "A□" (a.square equivalent)
- Toggled state: indigo background
- Switches between word-hide and letter-hide display
- In master mode: shows "X/3" streak text instead, non-interactive

#### 6. Master Crown Button (Right of Mic)
- 44dp circle, gray background
- Icon: crown (20sp)
- Tap (not in master mode): show info popup explaining master challenge
- Tap (in master mode): exit master mode
- Master mode active: yellow background, black icon

#### 7. Typing Mode Input
- Custom text field, centered
- Placeholder: "Type the word..." or "Type the first letter..."
- Auto-focus, no autocorrect, no capitalization
- Space/Enter submits word
- In first-letter mode: single character submits immediately
- Border: 3dp, blue (normal) or yellow (master mode)
- 14dp vertical padding, 20dp horizontal, 10dp corner radius

#### 8. Multiple Choice Mode
- LazyVerticalGrid, 2 columns, 8dp spacing
- 4 choices: 1 correct + 3 decoys from other positions in quote
- Correct tap: blue bg → mark correct, advance, generate new choices
- Wrong tap: red bg flash (0.4s) → record mistake, advance
- Decoy selection: other words from quote; fallback: "and", "the", "but", "for"

#### 9. Results Sheet (Completion View)
**Normal results:**
```
- Accuracy % (36sp bold, color-coded)
- Score circle (160dp diameter):
  - Outer ring: gray (16dp stroke)
  - Inner arc: colored (trim 0 to accuracy)
  - Center: Brain character (120dp)
- Stats row: Words tested | Correct (green) | Mistakes (red)
- Motivational message (based on accuracy tier)
- "Try Again" button (indigo)
- "Done" button (gray)
```

**Accuracy color tiers:**
- ≥95%: green, "Perfect!"
- ≥90%: green, "Excellent!"
- ≥80%: orange, "Great job!"
- ≥70%: orange, "Good effort!"
- ≥50%: orange, "Nice try!"
- <50%: red, "Keep practicing!"

**Master mode results (see section below)**

#### 10. Visual Mistake Flash
- Full-screen red overlay (Color.Red, 30% alpha)
- Ignores safe area
- Non-interactive (allowsHitTesting false)
- Duration: ~150ms (set by ViewModel)
- Currently partially implemented but needs to cover full screen

### P1 — Mastery System

#### 11. Master Mode
**Entry:** Tap crown → info popup → "Let's Go" button
**Rules:**
- Reveal slider locked at 0% (all words hidden)
- Hints blocked (tap shows "No help — prove you know it!" popup)
- First-letter toggle disabled
- 95%+ accuracy required per session
- Early fail: if 95% becomes mathematically impossible, session ends immediately
- 3 consecutive passes → quote marked MASTERED

**Info Popup:**
```
- Brain character (120dp, success variant)
- "Master This Quote" (title)
- "Get 3 consecutive perfect recitations with no hints or reveals."
- 3 crown icons showing current progress (0-3 filled)
- "Miss one and you start over."
- "Let's Go" button (yellow)
```

**Results in Master Mode:**
- Pass (streak 1-2): "Nice!" + crown progress animation + "X more to go!"
- Fail: "Not quite!" + crown drain animation + streak resets to 0
- Complete (streak 3): Confetti + large crown animation + "Congratulations!"

**Crown Progress Animation:**
- 3 CrownFillView components (36dp each)
- Fill animation: 0.5s ease-in-out
- Bounce: scale to 1.15x
- Drain on fail: sequential 0.7s stagger per crown

**ViewModel additions needed:**
```kotlin
var isMasterMode: Boolean = false
var showMasterModeHintBlock: Boolean = false  // "No help" popup
// Quote.masteryStreak already exists in Quote model
// masterModeCanStillPass: check if 95% still achievable
```

#### 12. Level Advancement
After each session:
- Accuracy ≥90% AND achieved level ≥ current → advance (level 1→2→3)
- Accuracy <70% AND level > 1 → demote one level
- 70-90%: no change

```kotlin
fun checkLevelAdvancement(accuracy: Double): Int? {
    val currentLevel = max(1, quote.revealLevel)
    if (accuracy < 0.70 && currentLevel > 1) {
        return currentLevel - 1  // Demote
    }
    if (accuracy < 0.90) return null  // No change
    if (currentLevel >= 3) return null  // Already max
    val achieved = levelAchieved(revealPercentage)
    if (achieved < currentLevel) return null
    return min(3, achieved + 1)  // Advance
}
```

### P1 — Session Persistence

#### 13. Practice Session Recording
On completion, create and save a PracticeSession:
```kotlin
PracticeSession(
    quoteId = quote.id,
    startedAt = sessionStartTime,
    completedAt = now,
    totalWords = words.size,
    testedWords = testedWordCount,  // hidden words only (for MC/typing) or all (for voice)
    correctWords = correctCount,
    mistakes = mistakes,  // List<PracticeMistake>
    revealPercentage = revealPercentage,
    hintCount = hintCount
)
```

Update quote after session:
- `practiceCount += 1`
- `lastPracticedAt = now`
- `lastAccuracy = accuracy`
- `bestAccuracy = max(bestAccuracy, accuracy)`
- `revealLevel` (if level advancement)
- `masteryStreak` (if master mode)

### P1 — Mistake Dispute

#### 14. Mistake Dispute Popup
When user taps a red (incorrect) word:
```
- Dimmed background (40% black overlay)
- Brain character (150dp, random mistake variant)
- "I heard you say '[spokenWord]'" (red text for spoken word)
- "No, I said the right word" button (green)
```

**"No, I said the right word" action:**
1. Remove all mistakes at that position
2. Mark word as correct
3. Save equivalence locally (UserEquivalencesStore)
4. Update comparator's live equivalences
5. Report to community (EquivalenceService, fire-and-forget)

### P2 — Quote Splitting (Chunking)

#### 15. Inline Split Feature
Splits long quotes into manageable chunks.

**Split Popup:**
- "How many parts?" with +/- buttons (range 2-10)
- "~X words each" preview
- "Split" button (indigo, scissors icon)

**Split Word Display:**
- Active chunk: full word display
- Peek containers above/below (max 2 each): mini previews of adjacent chunks
- Prev/Next navigation with "Chunk X of Y" header

**Merge Options (when already split):**
- "Only with previous part" (merges current + previous)
- "Back to full quote" (removes all splits)

**Each chunk maintains its own state:**
```kotlin
data class ChunkState(
    val chunkText: String,
    val words: List<WordDisplayState>,
    var currentPosition: Int = 0,
    var mistakes: MutableList<PracticeMistake> = mutableListOf(),
    var hintCount: Int = 0,
    var mcChoices: List<String> = emptyList(),
    var mcCorrectIndex: Int = 0,
    var revealPercentage: Double = 0.0,
    var previousWordWasMistake: Boolean = false
)
```

### P2 — Language Support

#### 16. Language Switching
If quote has translations:
- Language pill next to title (colored by language: en=blue, es=yellow, fr=red, etc.)
- Tap opens menu with available languages
- Switching reloads words, resets position, reapplies reveal
- Speech recognizer reconfigures locale

**Language pill colors:**
| Code | Background | Text Color |
|------|-----------|------------|
| en | Blue | White |
| es | Yellow | Black |
| fr | Red | White |
| it | Green | Black |
| de | Orange | Black |
| pt | Green | Black |
| ar | Green | White |
| default | Indigo | White |

### P2 — Audio/Playback Mode

#### 17. Audio Mode (Playback)
When user selects the music note tab:
- Recording picker sheet (personal + community recordings)
- TTS "Read Aloud" button (orange)
- Playback controls: prev/next, play/pause (80dp), repeat toggle
- Seekable progress bar
- Recording mode: record your own audio, save/share with community

This is the most complex mode and can be deferred to a later release.

### P3 — Polish Features

#### 18. Spotlight Tutorial
6-step tutorial highlighting UI elements with descriptions. Currently shelved on iOS (KNOWN_ISSUES TUTORIAL-001). Skip for Android.

#### 19. Confetti Effect
Canvas-based particle system for master mode completion (50 particles, 4s lifetime). Nice-to-have.

#### 20. Liquid Wave Animation
Yellow gradient wave that fills mic button and background when entering master mode. Nice-to-have but visually distinctive.

---

## VIEWMODEL STATE MAP (iOS → Android)

### Already in Android ViewModel
| Property | Type | Status |
|----------|------|--------|
| words | List<WordDisplayState> | ✅ Exists |
| currentPosition | Int | ✅ Exists |
| isListening | Boolean | ✅ Exists |
| showResults | Boolean | ✅ Exists |
| audioLevel | Float | ✅ Exists |
| mistakes | List<PracticeMistake> | ✅ Exists (internal) |
| progress | Float | ✅ Exists (computed) |

### Must Add to Android ViewModel
| Property | Type | Purpose |
|----------|------|---------|
| showMistakeFlash | Boolean | Red overlay on mistake |
| displayLevel | Int (1-3) | Reveal slider level |
| revealPercentage | Double (0-100) | % words revealed |
| letterRevealStep | Int (0-5) | Letters shown in first-letter mode |
| isFirstLetterToggle | Boolean | Word-hide vs letter-hide |
| currentMode | MemorizationMode | Active practice mode |
| typingInput | String | Typing mode buffer |
| hintCount | Int | Times user peeked at hidden word |
| correctCount | Int (computed) | Correct words (accounting for reveal) |
| mistakeCount | Int (computed) | Total mistakes |
| testedWordCount | Int (computed) | Words actually tested |
| isMasterMode | Boolean | Master challenge active |
| showMasterModeHintBlock | Boolean | "No help" popup |
| mcChoices | List<String> | 4 MC options |
| mcCorrectIndex | Int | Correct MC answer index |
| mcWrongIndex | Int? | Wrong selection (flash) |
| tappedMistakeIndex | Int? | Dispute popup trigger |
| showPauseIcon | Boolean | After 2s silence |
| flashingWordIndex | Int? | Hint flash (1s) |
| showAllWords | Boolean | Manual reveal override |
| sessionStartTime | Date? | For duration tracking |
| previousWordWasMistake | Boolean | For recovery sound |
| splitChunks | List<ChunkState>? | Chunking state |
| activeChunkIndex | Int | Current chunk |
| activeLanguage | String? | nil=original, else code |

### Must Add to Android ViewModel Methods
| Method | Purpose |
|--------|---------|
| applyRevealPercentage() | Randomly reveal % of pending words |
| wordDisplayMode(index) → WordDisplayMode | Determine how to render each word |
| switchMode(to) | Change practice mode with state sync |
| toggleFirstLetterMode() | Switch word-hide ↔ letter-hide |
| submitTypingInput() | Handle typed word submission |
| generateMCChoices() | Create 4 MC options |
| selectMCChoice(index) | Handle MC selection |
| tapWord(index) | Peek/dispute handler |
| enterMasterMode() | Lock reveal, start challenge |
| exitMasterMode() | Unlock, preserve streak |
| handleCompletion() | Record session, check advancement |
| overrideMistake() | Accept disputed word as correct |
| split(into count) | Split quote into chunks |
| switchToChunk(index) | Navigate chunks |
| mergeChunks(at index) | Combine adjacent chunks |
| unsplit() | Restore full quote |
| switchLanguage(code) | Change practice language |
| resetWordActivityTimer() | 2s silence → pause icon |

---

## IMPLEMENTATION ORDER

### Sprint 1: Word Display & Reveal (Highest Impact)
1. Add `isRevealed` to WordDisplayState
2. Implement `WordDisplayMode` enum (full, hidden, firstLetter, letters)
3. Build WordCell composable with all display modes
4. Implement 3-level reveal slider
5. Implement `applyRevealPercentage()` in ViewModel
6. Implement tap-to-peek with hint counting
7. Add `hintCount`, `correctCount`, `testedWordCount` to ViewModel

### Sprint 2: Bottom Control Bar & Stats
1. Build dark pill with INFO / stats / RESTART
2. Wire correct/mistake/hint counts
3. Build proper mic button with waveform visualization
4. Add first-letter toggle button
5. Add crown button (info-only, no master mode yet)
6. Build exit button

### Sprint 3: Mode Selector & Typing/MC
1. Build mode selector bar with sliding indicator
2. Implement typing mode input + submission
3. Implement first-letter toggle within typing
4. Implement multiple choice generation + selection
5. Implement skipToNextHiddenWord()

### Sprint 4: Results & Session Persistence
1. Redesign results view with score circle + brain character
2. Add accuracy color tiers and motivational messages
3. Implement session creation and persistence
4. Implement level advancement logic
5. Update quote stats after session

### Sprint 5: Master Mode
1. Implement master mode entry/exit
2. Lock reveal slider at 0%
3. Block hints with popup
4. Implement 95% early-fail check
5. Implement crown progress visualization
6. Implement master mode results variants

### Sprint 6: Mistake Dispute & Equivalences
1. Build dispute popup (tap incorrect word)
2. Implement overrideMistake()
3. Wire UserEquivalencesStore
4. Wire EquivalenceService (community reporting)
5. Load user + community equivalences on session start

### Sprint 7: Chunking
1. Implement split popup UI
2. Wire TextChunker
3. Build chunk navigation (prev/next + peek containers)
4. Implement merge logic
5. Persist chunk state to quote

### Sprint 8: Language & Polish
1. Implement language pill + switching
2. Reconfigure speech recognizer locale
3. Reconfigure comparator with translated text
4. Add visual mistake flash (full-screen red overlay)
5. Add pause icon after 2s silence
6. Add confetti effect for mastery completion (nice-to-have)

---

## KEY ARCHITECTURAL NOTES

### FlowRow for Word Display
Use Compose `FlowRow` (from `accompanist` or Compose Foundation 1.4+):
```kotlin
FlowRow(
    modifier = Modifier
        .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(16.dp))
        .padding(12.dp),
    horizontalArrangement = Arrangement.spacedBy(8.dp),
    verticalArrangement = Arrangement.spacedBy(8.dp)
) {
    words.forEachIndexed { index, wordState ->
        WordCell(wordState, displayMode = viewModel.wordDisplayMode(index), ...)
    }
}
```

### WordCell Composable
```kotlin
@Composable
fun WordCell(
    word: WordDisplayState,
    displayMode: WordDisplayMode,
    isFlashing: Boolean,
    fontSize: TextUnit,
    onTap: () -> Unit
) {
    val bgColor = when {
        isFlashing -> Color.Yellow.copy(alpha = 0.2f)
        word.state == WordState.CURRENT -> Color.Blue.copy(alpha = 0.2f)
        word.state == WordState.CORRECT -> Color.Green.copy(alpha = 0.2f)
        word.state == WordState.INCORRECT -> Color.Red.copy(alpha = 0.2f)
        else -> Color.Transparent
    }
    val borderColor = when {
        isFlashing -> Color.Yellow
        word.state == WordState.CURRENT -> Color.Blue
        else -> Color.Transparent
    }
    val text = when (displayMode) {
        WordDisplayMode.Full -> word.word
        WordDisplayMode.Hidden -> "█".repeat(max(3, word.word.length))  // or gray box
        is WordDisplayMode.Letters -> {
            val visible = word.word.take(displayMode.count)
            val hidden = "_".repeat(max(0, word.word.length - displayMode.count))
            // Keep trailing punctuation visible
            visible + hidden + trailingPunctuation(word.word)
        }
    }
    // Render with background, border, tap gesture
}
```

### Deferred Mismatch Timer (Already Implemented)
The Android ViewModel already has the adaptive settle timer. No changes needed for the core comparison pipeline.

### Android Haptic During Recording
Unlike iOS, Android does NOT suppress haptics while the mic is recording. The audio-pause workaround is NOT needed on Android. Haptics fire normally alongside SpeechRecognizer. This is confirmed in the memory notes.

---

## REFERENCE: iOS FILE → ANDROID FILE MAPPING

| iOS File | Android File | Lines iOS | Lines Android | Gap |
|----------|-------------|-----------|---------------|-----|
| RecitationScreen.swift | RecitationScreen.kt | 4,480 | 343 | ~4,000 lines of UI |
| RecitationViewModel.swift | RecitationViewModel.kt | 700+ | 322 | ~400 lines of state/logic |
| SpeechRecognitionService.swift | SpeechRecognitionService.kt | 661 | 521 | ✅ Feature-complete |
| WordComparator.swift | WordComparator.kt | 1,147 | 1,129 | ✅ Feature-complete |
| AlertManager.swift | AlertManager.kt | 371 | 261 | ✅ Feature-complete |
| TextChunker.swift | TextChunker.kt | ~100 | 102 | ✅ Feature-complete |

**Total gap: ~4,400 lines of UI + ViewModel code needed.**
