-- Replace "alvaradonicolemickle@gmail.com" with the exact email of the administrator account.

create table if not exists public.person_media (
  id uuid primary key default gen_random_uuid(),
  person_id text not null,
  kind text not null check (kind in ('photo', 'document')),
  object_path text not null unique,
  file_name text not null,
  mime_type text not null default 'application/octet-stream',
  size_bytes bigint not null check (size_bytes >= 0 and size_bytes <= 10485760),
  created_at timestamptz not null default now()
);

create unique index if not exists person_media_one_profile_photo
  on public.person_media (person_id)
  where kind = 'photo';

alter table public.person_media enable row level security;
grant select on public.person_media to anon, authenticated;
grant insert, update, delete on public.person_media to authenticated;

drop policy if exists "Public can read person media" on public.person_media;
create policy "Public can read person media"
  on public.person_media for select to anon, authenticated
  using (true);

drop policy if exists "Owner can insert person media" on public.person_media;
create policy "Owner can insert person media"
  on public.person_media for insert to authenticated
  with check (lower(auth.jwt() ->> 'email') = lower('OWNER_EMAIL_HERE'));

drop policy if exists "Owner can update person media" on public.person_media;
create policy "Owner can update person media"
  on public.person_media for update to authenticated
  using (lower(auth.jwt() ->> 'email') = lower('OWNER_EMAIL_HERE'))
  with check (lower(auth.jwt() ->> 'email') = lower('OWNER_EMAIL_HERE'));

drop policy if exists "Owner can delete person media" on public.person_media;
create policy "Owner can delete person media"
  on public.person_media for delete to authenticated
  using (lower(auth.jwt() ->> 'email') = lower('OWNER_EMAIL_HERE'));

insert into storage.buckets (id, name, public, file_size_limit)
values ('person-media', 'person-media', true, 10485760)
on conflict (id) do update set public = true, file_size_limit = 10485760;

drop policy if exists "Public can read person media files" on storage.objects;
create policy "Public can read person media files"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'person-media');

drop policy if exists "Owner can upload person media files" on storage.objects;
create policy "Owner can upload person media files"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'person-media'
    and lower(auth.jwt() ->> 'email') = lower('OWNER_EMAIL_HERE')
  );

drop policy if exists "Owner can update person media files" on storage.objects;
create policy "Owner can update person media files"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'person-media'
    and lower(auth.jwt() ->> 'email') = lower('OWNER_EMAIL_HERE')
  )
  with check (
    bucket_id = 'person-media'
    and lower(auth.jwt() ->> 'email') = lower('OWNER_EMAIL_HERE')
  );

drop policy if exists "Owner can delete person media files" on storage.objects;
create policy "Owner can delete person media files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'person-media'
    and lower(auth.jwt() ->> 'email') = lower('OWNER_EMAIL_HERE')
  );
