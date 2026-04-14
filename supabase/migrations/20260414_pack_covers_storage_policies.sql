-- Storage policies for the `pack-covers` bucket used by the admin tool.
-- Public read (iOS/Android apps fetch covers without auth), authenticated write
-- (admin tool uploads/replaces covers using the signed-in user's JWT).

-- Ensure the bucket exists and is public for reads.
insert into storage.buckets (id, name, public)
values ('pack-covers', 'pack-covers', true)
on conflict (id) do update set public = true;

-- Drop any pre-existing policies with the same names so this is re-runnable.
drop policy if exists "Pack covers: public read"    on storage.objects;
drop policy if exists "Pack covers: authed insert"  on storage.objects;
drop policy if exists "Pack covers: authed update"  on storage.objects;
drop policy if exists "Pack covers: authed delete"  on storage.objects;

create policy "Pack covers: public read"
  on storage.objects for select
  to public
  using (bucket_id = 'pack-covers');

create policy "Pack covers: authed insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'pack-covers');

create policy "Pack covers: authed update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'pack-covers')
  with check (bucket_id = 'pack-covers');

create policy "Pack covers: authed delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'pack-covers');
