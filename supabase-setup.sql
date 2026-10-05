-- Replace "alvaradonicolemickle@gmail.com" with the exact email of the administrator account.

create table if not exists public.person_media (
  id uuid primary key default gen_random_uuid(),
  person_id text not null,
  kind text not null check (kind in ('photo', 'document')),
  object_path text not null unique,
  file_name text not null,
  mime_type text not null default 'application/octet-stream',
  size_bytes bigint not null check (size_bytes >= 0 and size_bytes <= 10485760),
  document_type text not null default 'other',
  description text,
  created_at timestamptz not null default now()
);

alter table public.person_media
  add column if not exists document_type text not null default 'other';
alter table public.person_media
  add column if not exists description text;
alter table public.person_media
  drop constraint if exists person_media_document_type_check;
alter table public.person_media
  add constraint person_media_document_type_check
  check (document_type in ('birth', 'death', 'marriage', 'baptism', 'other'));

drop index if exists public.person_media_one_profile_photo;
create unique index if not exists person_media_one_profile_photo
  on public.person_media (person_id)
  where kind = 'photo' and person_id not like 'family:%';

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
  with check (lower(auth.jwt() ->> 'email') = lower('alvaradonicolemickle@gmail.com'));

drop policy if exists "Owner can update person media" on public.person_media;
create policy "Owner can update person media"
  on public.person_media for update to authenticated
  using (lower(auth.jwt() ->> 'email') = lower('alvaradonicolemickle@gmail.com'))
  with check (lower(auth.jwt() ->> 'email') = lower('alvaradonicolemickle@gmail.com'));

drop policy if exists "Owner can delete person media" on public.person_media;
create policy "Owner can delete person media"
  on public.person_media for delete to authenticated
  using (lower(auth.jwt() ->> 'email') = lower('alvaradonicolemickle@gmail.com'));

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
    and lower(auth.jwt() ->> 'email') = lower('alvaradonicolemickle@gmail.com')
  );

drop policy if exists "Owner can update person media files" on storage.objects;
create policy "Owner can update person media files"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'person-media'
    and lower(auth.jwt() ->> 'email') = lower('alvaradonicolemickle@gmail.com')
  )
  with check (
    bucket_id = 'person-media'
    and lower(auth.jwt() ->> 'email') = lower('alvaradonicolemickle@gmail.com')
  );

drop policy if exists "Owner can delete person media files" on storage.objects;
create policy "Owner can delete person media files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'person-media'
    and lower(auth.jwt() ->> 'email') = lower('alvaradonicolemickle@gmail.com')
  );

create table if not exists public.genogram_activity (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('person', 'family', 'genogram')),
  entity_id text not null,
  entity_name text,
  summary text not null,
  created_at timestamptz not null default now()
);

alter table public.genogram_activity enable row level security;
grant select on public.genogram_activity to anon, authenticated;

drop policy if exists "Public can read genogram activity" on public.genogram_activity;
create policy "Public can read genogram activity"
  on public.genogram_activity for select to anon, authenticated
  using (true);

create or replace function public.record_genogram_media_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  media_row public.person_media%rowtype;
  activity_entity_type text;
  activity_entity_id text;
  activity_summary text;
  document_label text;
begin
  if tg_op = 'DELETE' then
    media_row := old;
  else
    media_row := new;
  end if;

  if left(media_row.person_id, 7) = 'family:' then
    activity_entity_type := 'family';
    activity_entity_id := substring(media_row.person_id from 8);
  else
    activity_entity_type := 'person';
    activity_entity_id := media_row.person_id;
  end if;

  if media_row.kind = 'photo' then
    if tg_op = 'INSERT' then
      activity_summary := 'Se agregó una foto.';
    elsif tg_op = 'UPDATE' then
      activity_summary := 'Se actualizó la foto.';
    else
      activity_summary := 'Se quitó una foto.';
    end if;
  else
    document_label := case media_row.document_type
      when 'birth' then 'una partida de nacimiento'
      when 'death' then 'una partida de defunción'
      when 'marriage' then 'un acta de matrimonio'
      when 'baptism' then 'un acta de bautismo'
      else 'un documento'
    end;
    if tg_op = 'INSERT' then
      activity_summary := 'Se agregó ' || document_label || '.';
    elsif tg_op = 'UPDATE' then
      activity_summary := 'Se actualizó ' || document_label || '.';
    else
      activity_summary := 'Se quitó ' || document_label || '.';
    end if;
  end if;

  insert into public.genogram_activity (entity_type, entity_id, summary)
  values (activity_entity_type, activity_entity_id, activity_summary);

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists person_media_activity_log on public.person_media;
create trigger person_media_activity_log
  after insert or update or delete on public.person_media
  for each row execute function public.record_genogram_media_activity();

create table if not exists public.genogram_snapshot (
  singleton boolean primary key default true check (singleton = true),
  data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.genogram_snapshot enable row level security;
revoke all on public.genogram_snapshot from anon, authenticated;

create or replace function public.sync_genogram_snapshot(current_snapshot jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  previous_snapshot jsonb;
  previous_people jsonb;
  current_people jsonb;
  person_entry record;
begin
  if lower(auth.jwt() ->> 'email') is distinct from lower('alvaradonicolemickle@gmail.com') then
    raise exception 'Only the configured administrator can sync the genogram';
  end if;
  if coalesce(jsonb_typeof(current_snapshot -> 'people'), '') <> 'object' then
    raise exception 'Invalid genogram snapshot';
  end if;

  perform pg_advisory_xact_lock(631234567);
  select data into previous_snapshot
    from public.genogram_snapshot where singleton = true;
  if not found then
    insert into public.genogram_snapshot (singleton, data) values (true, current_snapshot);
    return;
  end if;

  previous_people := coalesce(previous_snapshot -> 'people', '{}'::jsonb);
  current_people := coalesce(current_snapshot -> 'people', '{}'::jsonb);

  for person_entry in select key, value from jsonb_each(current_people) loop
    if not (previous_people ? person_entry.key) then
      insert into public.genogram_activity (entity_type, entity_id, entity_name, summary)
      values ('person', person_entry.key, person_entry.value ->> 'name', 'Se agregó al genograma.');
    elsif previous_people -> person_entry.key is distinct from person_entry.value then
      insert into public.genogram_activity (entity_type, entity_id, entity_name, summary)
      values ('person', person_entry.key, person_entry.value ->> 'name', 'Se actualizaron sus datos.');
    end if;
  end loop;

  for person_entry in select key, value from jsonb_each(previous_people) loop
    if not (current_people ? person_entry.key) then
      insert into public.genogram_activity (entity_type, entity_id, entity_name, summary)
      values ('person', person_entry.key, person_entry.value ->> 'name', 'Se quitó del genograma.');
    end if;
  end loop;

  if previous_snapshot -> 'relationships' is distinct from current_snapshot -> 'relationships' then
    insert into public.genogram_activity (entity_type, entity_id, entity_name, summary)
    values ('genogram', 'relationships', 'Genograma familiar', 'Se actualizaron los vínculos familiares.');
  end if;

  update public.genogram_snapshot set data = current_snapshot, updated_at = now()
    where singleton = true;
end;
$$;

revoke all on function public.sync_genogram_snapshot(jsonb) from public, anon;
grant execute on function public.sync_genogram_snapshot(jsonb) to authenticated;
