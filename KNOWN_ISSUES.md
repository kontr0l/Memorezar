# Known Issues - Memorezar

This document tracks known issues, bugs, workarounds, and ongoing investigations. AI assistants should consult this file at the start of every session and update it with relevant findings from conversations.

---

## Active Issues

### Speech Recognition

| Issue | Status | Description | Workaround |
|-------|--------|-------------|------------|
| SPEECH-001 | open | Duplicate word sends on transcript revision cause phantom mistakes | None - fix was reverted |

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

**Root Cause (VERIFIED BY LOGS):**
TWO interacting problems:
1. **Speech service sends every partial transcription** as the recognizer refines its output
2. **Comparator advances position on mismatch** instead of staying put

**Actual log from saying "Juxtaposition":**
```
[SPEECH] INTERIM: "Just" | words=1 lastProcessed=0
[SPEECH] → SEND (new): "Just"
[COMPARE] pos=0 → "just" != "juxtaposition" → MISTAKE #1

[SPEECH] INTERIM: "Jax" | words=1 lastProcessed=1
[SPEECH] → SEND (revision): "Jax" (was "Just")
[COMPARE] pos=1 → "jax" != "superfluous" → MISTAKE #2

[SPEECH] INTERIM: "Juxta" | words=1 lastProcessed=1
[SPEECH] → SEND (revision): "Juxta" (was "Jax")
[COMPARE] pos=2 → "juxta" != "extracurricular" → MISTAKE #3

[SPEECH] INTERIM: "Juxtaposition" | words=1 lastProcessed=1
[SPEECH] → SEND (revision): "Juxtaposition" (was "Juxta")
[COMPARE] pos=3 → "juxtaposition" != "tabletop" → MISTAKE #4
```

**Key Insight:** There is NO count drop in this scenario. The word count stays at 1 throughout. The revision detection code (lines 225-233) fires because the last word keeps changing: "Just" → "Jax" → "Juxta" → "Juxtaposition".

**The reverted fix (commit 6f9e9b5) WOULD NOT HELP** - it only addressed count drops, not same-count revisions.

**Potential Fixes:**
1. **Don't send revisions to comparator** - Only send when word is "stable" (but adds latency)
2. **Comparator: don't advance on revision mismatches** - Need way to distinguish new words vs revisions
3. **Comparator: stay at same position on mismatch** - Only advance on match (but breaks skip detection)
4. **Prefix matching** - Don't count mismatch if partial word is prefix of expected word
5. **Debounce revisions** - Wait brief period before sending to let word stabilize

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
- Initial theory about count drop was WRONG - logs show no count drop occurs
- The real problem is revision detection (lines 225-233) sends every partial transcription
- Combined with comparator advancing position on mismatch → cascading failures
- Need to decide on fix approach (see potential fixes in SPEECH-001 description)

### Past Investigation Findings

**Feb 16, 2026 - Duplicate Word Bug Analysis (CORRECTED)**

Initial hypothesis: Count drop handler doesn't update `lastProcessedWord`.
**WRONG** - Logs proved this isn't the issue.

Actual problem discovered via console logs:
- Speech recognizer sends partial transcriptions: "Just" → "Jax" → "Juxta" → "Juxtaposition"
- Word count stays at 1 throughout (NO count drop)
- Revision detection code fires on each change, sending to comparator
- Comparator advances position on each mismatch
- By the time correct "Juxtaposition" arrives, we're at position 3 expecting "tabletop"

The reverted fix (commit 6f9e9b5) addressed count drops, which is a DIFFERENT scenario. It would not fix this bug.

---

## Conversation Insights

Key learnings and decisions from development conversations that may be relevant to future work.

### Technical Decisions

*No decisions logged yet*

### Debugging Discoveries

**iOS Speech Recognizer Sends Partial Transcriptions (Feb 2026)**
The iOS speech recognizer continuously refines its transcription as it processes audio. For a word like "Juxtaposition", it may send: "Just" → "Jax" → "Juxta" → "Juxtaposition". This is expected behavior from the recognizer, but the app's revision detection code (lines 225-233) forwards EACH of these to the comparator.

**Comparator Advances Position on Mismatch (Feb 2026)**
The word comparator advances to the next expected word after ANY mismatch. This may be intentional (to handle skipped words) but causes problems when combined with partial transcription sends. Each partial word mismatches and advances, so the final correct word is compared against the wrong position.

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
