-- Private `recording-backups` bucket for per-user audio backups.
-- Files live at `<auth.uid()>/<local_recording_id>.m4a` and are only
-- accessible to the uploader. Used by CloudBackupService when the user
-- taps "Back Up Now" / "Restore from Backup" in Settings.
--
-- NOT for community recordings — those live in the public `recordings`
-- bucket with different RLS.

-- Ensure the bucket exists and is PRIVATE (not publicly readable).
insert into storage.buckets (id, name, public)
values ('recording-backups', 'recording-backups', false)
on conflict (id) do update set public = false;

-- Drop any pre-existing policies with the same names so this is re-runnable.
drop policy if exists "Recording backups: owner can read"   on storage.objects;
drop policy if exists "Recording backups: owner can write"  on storage.objects;
drop policy if exists "Recording backups: owner can update" on storage.objects;
drop policy if exists "Recording backups: owner can delete" on storage.objects;

-- Read: owner-only. A user can only SELECT their own folder.
create policy "Recording backups: owner can read"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'recording-backups'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Insert: owner-only. User can only write into their own folder.
create policy "Recording backups: owner can write"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'recording-backups'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Update: owner-only (covers upsert via `x-upsert: true` header).
create policy "Recording backups: owner can update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'recording-backups'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'recording-backups'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Delete: owner-only (for future cleanup routines + account deletion cascade).
create policy "Recording backups: owner can delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'recording-backups'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
