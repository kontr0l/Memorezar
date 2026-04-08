# Auth Setup — Next Steps

## Supabase Dashboard

### 1. Enable Apple Provider
- Auth → Providers → Apple → Enable
- Service ID: `com.memorezar.app`
- Add your Apple private key (from Apple Developer → Keys → Sign in with Apple)

### 2. Enable Google Provider
- Auth → Providers → Google → Enable
- Client ID + Secret from Google Cloud Console (OAuth 2.0 credentials)
- Authorized redirect URI: copy from Supabase dashboard into Google Console

### 3. Set Redirect URL
- Auth → URL Configuration → Redirect URLs → Add `com.memorezar.app://callback`

### 4. Run the DB Migration
Run `supabase/migrations/20260324_add_auth_to_recordings.sql` via Supabase SQL Editor or CLI.

Adds: `user_id` column, unique index (one recording per user/quote/language), RLS policies.

### 5. Storage Bucket Limit
- Storage → recordings bucket → Policies → Set 5 MB max file size

## Apple Developer Portal

### 6. Sign in with Apple Capability
- Certificates, Identifiers & Profiles → App IDs → `com.memorezar.app`
- Enable "Sign in with Apple"
- Create a Services ID if you don't have one (needed for Supabase)
- Create a Key with Sign in with Apple enabled → download the `.p8` file → upload to Supabase

## Testing Checklist

- [ ] Fresh launch → app works without signing in
- [ ] Settings → Account → Sign In → test email/password flow
- [ ] Sign out → verify reverts to anon
- [ ] Sign in with Apple → verify **on device** (doesn't work in Simulator)
- [ ] Sign in with Google → OAuth flow completes
- [ ] Record + toggle "share with community" while signed out → shows sign-in prompt
- [ ] Record + share while signed in → check `user_id` appears in Supabase `recordings` table
- [ ] Record same quote+language again → "Replace Recording?" alert → replaces (not duplicate)
- [ ] Kill app → relaunch → session restored (no re-login needed)
- [ ] Wait 50+ min or manually expire token → verify silent refresh works
