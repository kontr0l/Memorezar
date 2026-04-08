# Recording Issues - Memorezar

Weaknesses and improvement opportunities for the community recordings system.

---

## Security / Abuse

### REC-001: No Authentication for Uploads

**Severity:** High

Anyone with the anon key (embedded in the app binary) can upload unlimited recordings. There's no user identity, no rate limiting, no size limit. A bad actor could flood the storage bucket with junk or offensive audio.

### REC-002: No Moderation Pipeline

**Severity:** High

Flagging exists (`RecordingService.flagRecording`) but there's no admin UI or automated process to review flags, remove offending recordings, or ban repeat offenders. Flags just pile up in a table with no action taken on them.

### REC-003: Anon Key Used as Bearer Token for Uploads

**Severity:** Medium

`uploadAudio` uses the anon key as the auth token for Supabase Storage. This means RLS on storage is effectively wide open for inserts. Anyone who extracts the key from the app binary can upload directly to the bucket.

---

## Data Integrity

### REC-004: No Upload Size or Duration Validation

**Severity:** Medium

No server-side or client-side cap on recording length or file size. A user could upload a 2-hour file and there's nothing preventing it.

### REC-005: Hash-Based Matching Is Fragile

**Severity:** Medium

Quotes are matched by SHA256 of normalized text. If a quote is edited even slightly (fix a typo, change punctuation), the hash changes and all existing recordings become orphaned. The `quoteId` fallback helps but only for newer recordings that have it set.

### REC-006: No Deduplication

**Severity:** Low

The same user can upload the same recording multiple times. No check for duplicate uploads (same audio data, same user, same quote).

### REC-007: Orphaned Storage Files on Partial Upload Failure

**Severity:** Medium

If `uploadAudio` (Storage) succeeds but `createRecording` (metadata row) fails, the audio file is orphaned in storage with no metadata pointing to it. There's no transactional guarantee between the two steps.

---

## UX / Quality

### REC-008: No Audio Quality Check

**Severity:** Medium

Silent recordings, extremely short recordings (< 1s), or recordings of background noise all get uploaded and shown to the community. No minimum duration, silence detection, or quality gate.

### REC-009: Uploader Name Is Self-Reported and Optional

**Severity:** Low

Defaults to "Anonymous". No way to verify identity or build reputation/trust around uploaders.

### REC-010: No Playback Count or Rating System

**Severity:** Low

All community recordings appear equal in the picker. Users can't distinguish a high-quality recording from a poor one without listening to each individually.

### REC-011: Download-Before-Play for Community Recordings

**Severity:** Medium

Every tap on a community recording requires a full download. No streaming, no caching. On slow connections this feels broken — the user taps and waits with no feedback until the download completes.

### REC-012: No Pagination for Community Recordings

**Severity:** Low (for now)

`fetchRecordings` returns all recordings for a hash in one request. If a popular quote accumulates hundreds of recordings, that's a large payload with no pagination.

---

## Reliability

### REC-013: No Offline Upload Queue

**Severity:** Medium

If the user saves a recording while offline, it's saved locally but the community upload silently fails. There's no retry queue — the recording never gets shared to the community.

---

## Improvement Priority (suggested)

| Priority | Issues | Rationale |
|----------|--------|-----------|
| P0 | REC-001, REC-002 | Abuse prevention is critical before community recordings scale |
| P1 | REC-004, REC-007, REC-008 | Data integrity and quality gates |
| P2 | REC-011, REC-013 | UX polish for reliability |
| P3 | REC-005, REC-006, REC-010, REC-012 | Nice-to-have improvements |
| P4 | REC-003, REC-009 | Longer-term auth/identity work |
