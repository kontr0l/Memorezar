# Known Issues - Memorezar

This document tracks known issues, bugs, workarounds, and ongoing investigations. AI assistants should consult this file at the start of every session and update it with relevant findings from conversations.

---

## Active Issues

### Speech Recognition

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| SPEECH-001 | open | Duplicate word sends on transcript revision cause phantom mistakes | None - fix was reverted |

#### SPEECH-001: Duplicate Word Sends on Transcript Revision

**Severity:** High
**Affects:** iOS app
**File:** `ios/Memorezar/Core/Speech/SpeechRecognitionService.swift` (lines 211-234)

**Symptoms:**
- User says ONE word correctly, but gets multiple mistakes counted
- Example: Saying "Juxtaposition" → 1 correct + 3 mistakes (word sent 4 times)
- Error banner shows the correct word being compared against the NEXT expected word

**Root Cause:**
When the speech recognizer revises its transcript (e.g., "juxta position" → "juxtaposition"), the word count drops. The code updates `lastProcessedWordCount` but NOT `lastProcessedWord`. This causes false "revision" detection on subsequent interim results, sending the same word multiple times.

**Flow that causes the bug:**
```
1. Recognizer: "juxta" (1 word) → sends "juxta", lastProcessedWord = "juxta"
2. Recognizer: "juxta position" (2 words) → sends "position", lastProcessedWord = "position"
3. Recognizer revises: "juxtaposition" (1 word) → COUNT DROP triggers, lastProcessedWordCount = 1
   BUT lastProcessedWord still = "position" (NOT updated!)
4. Next interim: "juxtaposition" (1 word) → revision check sees "juxtaposition" != "position"
   → SENDS "juxtaposition" AGAIN (duplicate!)
```

**The fix that was reverted (commit 6f9e9b5):**
```swift
if words.count < lastProcessedWordCount {
    lastProcessedWordCount = words.count
    lastProcessedWord = words.last ?? ""  // ← This line was the fix
}
```

**Why was it reverted?** (commit c19704c)
Unknown - needs investigation. The revert commit message doesn't explain why.

**To Fix:**
Re-apply the fix from commit 6f9e9b5, or investigate why it was reverted and find alternative solution.

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

**SPEECH-001 Investigation (Feb 2026)**
- Need to understand why fix in commit 6f9e9b5 was reverted
- Possible reasons: caused other issues? Didn't fully solve the problem?
- Check if there's a better approach than just updating `lastProcessedWord`

### Past Investigation Findings

**Feb 16, 2026 - Duplicate Word Bug Analysis**
User reported saying "Juxtaposition" once but receiving 3 mistakes. Screenshot analysis revealed:
- Word 1 "juxtaposition" correctly matched (green)
- Stats showed 1/10 words, 1 correct, 3 mistakes
- Error banner: Expected "superfluous" · Said "Juxtaposition"

This confirmed the word was sent 4 times (1 correct match + 3 mistakes against next word). Root cause traced to missing `lastProcessedWord` update in count drop handler at `SpeechRecognitionService.swift:212-214`.

---

## Conversation Insights

Key learnings and decisions from development conversations that may be relevant to future work.

### Technical Decisions

*No decisions logged yet*

### Debugging Discoveries

**Speech Recognition State Machine Quirk (Feb 2026)**
The iOS speech recognizer can revise transcripts in ways that reduce word count (e.g., splitting then merging words). When this happens, `lastProcessedWord` becomes stale and causes the "revision detection" logic (lines 225-233) to fire incorrectly, re-sending already-processed words.

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
