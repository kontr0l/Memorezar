# CLAUDE.md - AI Assistant Guidelines for Memorezar

## Project Overview

**Memorezar** is a real-time memorization assistant app that helps users memorize quotes, speeches, poetry, scripture, and other text by providing **instant feedback** when they make a mistake while reciting from memory.

### Core Value Proposition

Unlike existing memorization apps that provide delayed feedback, Memorezar alerts users **immediately** when they say the wrong word - not 4-5 words later. This instant correction is critical for effective memorization because:

- Delayed feedback reinforces incorrect neural pathways
- Immediate correction helps users learn the right word in context
- Real-time feedback creates a more natural "practice partner" experience

### The Technical Challenge

**Latency is the enemy.** The system must:
1. Capture audio in real-time
2. Transcribe speech word-by-word (not sentence-by-sentence)
3. Compare each word against the target text as it's spoken
4. Alert the user within ~200-300ms of saying the wrong word

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Interface                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Quote Input │  │  Recitation │  │  Instant Alert Display  │  │
│  │   & Storage │  │    Mode     │  │  (visual/audio/haptic)  │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Core Processing Engine                        │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ Audio Capture   │→ │  Streaming   │→ │ Word-by-Word      │  │
│  │ (low latency)   │  │  Speech-to-  │  │ Comparator        │  │
│  │                 │  │  Text (STT)  │  │                   │  │
│  └─────────────────┘  └──────────────┘  └───────────────────┘  │
│                                                │                 │
│                                                ▼                 │
│                              ┌─────────────────────────────────┐│
│                              │  Alert Trigger (< 300ms goal)   ││
│                              └─────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Data Layer                                 │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ Quote Library   │  │   Progress   │  │  User Settings    │  │
│  │                 │  │   Tracking   │  │                   │  │
│  └─────────────────┘  └──────────────┘  └───────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Critical Technical Requirements

### 1. Streaming Speech Recognition (HIGHEST PRIORITY)

The STT engine **must** support:
- **Interim/partial results** - Get transcription as words are spoken, not after silence
- **Low latency streaming** - Process audio chunks in real-time (< 100ms chunks)
- **Word-level timestamps** - Know exactly when each word was spoken

**Recommended Options (evaluate in order):**

| Service | Latency | Interim Results | Notes |
|---------|---------|-----------------|-------|
| Web Speech API | ~300ms | Yes | Free, browser-only, varies by browser |
| Deepgram | ~100ms | Yes | Excellent latency, paid |
| Azure Speech | ~200ms | Yes | Good accuracy, paid |
| Google Cloud STT | ~300ms | Yes | High accuracy, paid |
| Whisper (local) | High | No | Not suitable for real-time |

### 2. Word Comparison Algorithm

Must handle:
- **Case insensitivity** - "The" matches "the"
- **Punctuation tolerance** - "Hello," matches "Hello"
- **Contractions** - "don't" matches "do not" (configurable)
- **Homophones** - "their/there/they're" (flag but optionally allow)
- **Filler words** - Ignore "um", "uh", "like" (configurable)
- **Partial word detection** - Don't alert on incomplete words

```
Example flow:
Target:    "Four score and seven years ago"
Spoken:    "Four score and EIGHT years ago"
                          ↑
                    Alert HERE immediately
                    (not after "years" or "ago")
```

### 3. Alert System

Multiple feedback channels for instant notification:
- **Audio** - Short beep/tone (< 50ms sound)
- **Visual** - Screen flash or word highlight
- **Haptic** - Vibration on mobile devices

User should be able to configure which alerts are active.

---

## Repository Structure

```
Memorezar/
├── CLAUDE.md                 # This file - AI assistant guidelines
├── KNOWN_ISSUES.md           # Known bugs, investigations, and insights (READ EVERY SESSION!)
├── README.md                 # User-facing documentation
├── package.json              # Dependencies and scripts
│
├── src/
│   ├── core/
│   │   ├── speech/           # Speech recognition integration
│   │   │   ├── streaming.ts  # Streaming STT handler
│   │   │   ├── providers/    # Different STT provider adapters
│   │   │   └── types.ts      # Speech-related types
│   │   │
│   │   ├── comparison/       # Word comparison engine
│   │   │   ├── comparator.ts # Main comparison logic
│   │   │   ├── normalizer.ts # Text normalization (case, punctuation)
│   │   │   └── fuzzy.ts      # Fuzzy matching for homophones
│   │   │
│   │   └── alert/            # Alert system
│   │       ├── manager.ts    # Coordinates all alert types
│   │       ├── audio.ts      # Audio alerts
│   │       ├── visual.ts     # Visual alerts
│   │       └── haptic.ts     # Haptic feedback
│   │
│   ├── data/
│   │   ├── quotes/           # Quote storage and management
│   │   ├── progress/         # User progress tracking
│   │   └── settings/         # User preferences
│   │
│   ├── ui/                   # User interface components
│   │   ├── components/       # Reusable UI components
│   │   ├── screens/          # Main app screens
│   │   └── hooks/            # Custom React hooks
│   │
│   └── utils/                # Shared utilities
│
├── tests/
│   ├── unit/                 # Unit tests
│   ├── integration/          # Integration tests
│   └── fixtures/             # Test data (sample quotes, audio)
│
└── docs/
    ├── architecture.md       # Detailed architecture docs
    └── api.md                # API documentation
```

---

## Development Priorities

### Phase 1: Core Real-Time Engine (MVP)
1. Streaming speech recognition integration
2. Word-by-word comparison with immediate detection
3. Basic alert system (audio beep)
4. Simple UI to input quote and start recitation

### Phase 2: Enhanced Accuracy
1. Text normalization (punctuation, contractions)
2. Filler word filtering
3. Configurable strictness levels
4. Visual word highlighting

### Phase 3: Full App Features
1. Quote library management
2. Progress tracking and statistics
3. Multiple alert types (audio/visual/haptic)
4. Spaced repetition scheduling

---

## Code Conventions

### Performance-Critical Code

Since latency is critical, follow these rules in the speech processing pipeline:

```typescript
// BAD - Creates garbage, unpredictable GC pauses
function processWord(word: string) {
  return word.toLowerCase().trim().replace(/[.,!?]/g, '');
}

// GOOD - Reuse buffers, minimize allocations
const normalizeBuffer = new Array(100);
function processWord(word: string, buffer: string[]) {
  // Reuse pre-allocated buffer
}
```

- **Avoid allocations in hot paths** - Pre-allocate buffers
- **Use typed arrays** for audio data
- **Profile regularly** - Measure actual latency, not assumptions
- **Benchmark on target devices** - Mobile performance differs from desktop

### General Guidelines

1. **TypeScript** - Use strict mode, explicit types for public APIs
2. **Async/Await** - Prefer over raw promises for readability
3. **Error Handling** - Never swallow errors in speech pipeline; surface to user
4. **Testing** - Unit test comparison logic extensively with edge cases

### Commit Messages

```
feat(speech): add Deepgram streaming provider
fix(comparison): handle contractions correctly
perf(alert): reduce audio alert latency to <50ms
test(comparison): add homophone edge cases
```

---

## Key Technical Decisions to Document

When implementing, document these decisions:

1. **Which STT provider was chosen and why**
2. **Measured end-to-end latency** (speech → alert)
3. **How homophones are handled**
4. **Normalization rules applied**
5. **Alert timing and behavior**

---

## Testing Strategy

### Unit Tests
- Comparison logic with extensive edge cases
- Text normalization
- Alert trigger conditions

### Integration Tests
- Full pipeline with recorded audio samples
- Latency measurement tests (must stay under threshold)

### Test Fixtures Needed
- Sample quotes of varying lengths
- Recorded audio with intentional mistakes
- Homophones test cases
- Filler word test cases

---

## Performance Benchmarks

Track and maintain these metrics:

| Metric | Target | Acceptable | Unacceptable |
|--------|--------|------------|--------------|
| Word detection latency | < 200ms | < 300ms | > 500ms |
| Alert trigger time | < 50ms | < 100ms | > 200ms |
| Audio chunk size | 50-100ms | 100-200ms | > 300ms |
| Memory usage | < 50MB | < 100MB | > 200MB |

---

## Common Pitfalls to Avoid

1. **Using batch STT** - Must use streaming with interim results
2. **Waiting for silence** - Compare words as they arrive, not at pauses
3. **Over-normalizing** - Don't strip meaning (e.g., "won't" vs "want")
4. **Ignoring mobile** - Test on actual devices, not just simulators
5. **Alert fatigue** - One clear alert per mistake, not repeated alerts

---

## Suggestion Packs

Suggestion packs are curated collections of quotes users can browse and add to their library from the home screen.

### Architecture: Supabase-Only

**Supabase is the single source of truth.** All packs are served from the `suggestion_packs` table. There is no cache or bundled fallback for browsing — if the server is unreachable, the Browse section is hidden.

- **`PackService.fetchPacks()`**: Returns packs from Supabase, or `[]` if offline
- **`QuoteCategory.sourcePackId`**: Links a local category back to its Supabase pack ID for sync
- **`PackService.syncInstalledPacks()`**: Fires on every launch; updates installed packs when server `version` > local version, matching by `sourcePackId`

Bundled packs in `SuggestionPack.swift` are **seed data only** — kept as a reference for the Supabase table, never read at runtime.

See `KNOWN_ISSUES.md` → PACK-001 for full rules, schema, and admin workflow.

### Adding a New Pack

1. Insert a row into the `suggestion_packs` Supabase table with `version: 1`
2. Add a bundled cover image to `ios/Memorezar/Resources/Assets.xcassets/` as a new `.imageset` (JPEG or PNG only — Xcode does not support WebP). Set `cover_asset` to match the asset name. Or use `cover_url` for a remote image.
3. **Do not include the quote count in the `description`** — the count is already displayed under the pack title in the UI.

### Preview Snippets

The pack detail page shows the first 3 quotes as italic preview snippets. Snippets are generated automatically by `PackDetailView.fallbackSnippet()` — no manual work needed when adding new packs. The algorithm:

1. **If the quote is 7 words or fewer**, the full text is shown as-is (no "..." appended).
2. **First pass — sentence boundaries**: Looks for a word ending with `.`, `!`, or `?` at positions 5-7. Prefers completing a sentence over mid-sentence breaks.
3. **Second pass — function words**: Breaks right **after** a function word (is, are, can, has, have, will, would, which, that, with, of, to, for, lest, not, etc.) at positions 5-7. This creates a natural hook. Examples:
   - "The betterment of the world **can**..."
   - "The secret of getting ahead **is**..."
   - "Life is like riding a bicycle." (full sentence, no "...")
4. **Fallback**: If no natural break is found, takes the first 6 words.

### Button Styling

The "Add to Library" button on the pack detail page uses `.buttonStyle(.borderedProminent)` with `.tint(.indigo)` and no `.controlSize` modifier — matching the same height and rounded corners as the split/merge modal buttons. The label uses `HStack { Text(...) Image(...) }` (text first, icon after).

---

## For AI Assistants

### CRITICAL: Known Issues Document

**ALWAYS read [`KNOWN_ISSUES.md`](./KNOWN_ISSUES.md) at the start of every session.** This file contains:
- Active bugs and their workarounds
- Ongoing investigations
- Key insights from past debugging sessions
- Technical decisions that affect implementation

**ALWAYS update `KNOWN_ISSUES.md`** when:
- You discover a new bug or issue during the conversation
- You resolve an existing issue
- You uncover important debugging insights or root causes
- Technical decisions are made that relate to known problems
- You find workarounds or temporary fixes

This ensures continuity across sessions and prevents re-investigating the same issues.

### When Working on This Codebase

1. **Latency is paramount** - Every millisecond matters in the speech pipeline
2. **Test with real speech** - Synthetic tests miss real-world issues
3. **Consider edge cases** - Accents, speaking speed, background noise
4. **Don't over-engineer** - Simple, fast code beats elegant, slow code
5. **Profile before optimizing** - Measure actual bottlenecks

### Before Making Changes
- **Check `KNOWN_ISSUES.md`** for related issues or past investigations
- Understand the latency implications of any change to the speech pipeline
- Check if the change affects the critical path (audio → comparison → alert)
- Review existing normalization rules before adding new ones

### Version Tracking

**MANDATORY: Bump the version of the app you are actively working on with EVERY change, no matter how small.** Even a single-line tweak, icon swap, or config change requires a version bump. Do NOT bump the version of an app you are not working on.

- **iOS version:** `ios/Memorezar/UI/Screens/SettingsScreen.swift` (the `Text("vX.X")` line). Increment the minor version (35.3 → 35.4 → 35.5, etc.).
- **Android version:** `memorezar-android/app/src/main/java/com/memorezar/app/ui/screens/SettingsScreen.kt` (the `Text("vX.X.X")` line).

**Never skip this — there are no exceptions.**

### Key Files (Once Created)
- `src/core/speech/streaming.ts` - Heart of real-time processing
- `src/core/comparison/comparator.ts` - Word matching logic
- `src/core/alert/manager.ts` - Alert coordination

---

*Last Updated: March 2026*
