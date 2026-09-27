-- Photos and videos in chat. Files live in a PRIVATE bucket, one folder per match; only the two members
-- (and admins, for reports) can open them, through short-lived signed links.
alter table public.messages add column if not exists kind text not null default 'text' check (kind in ('text','image','video'));
alter table public.messages add column if not exists media_path text check (char_length(media_path) <= 300);
alter table public.messages add column if not exists media_meta jsonb;
alter table public.messages alter column body set default '';
alter table public.messages drop constraint if exists messages_body_check;
alter table public.messages add constraint messages_body_check check (
  (kind = 'text' and char_length(btrim(body)) between 1 and 2000)
  or (kind in ('image','video') and media_path is not null and char_length(body) <= 2000));

drop policy if exists messages_member_insert on public.messages;
create policy messages_member_insert on public.messages for insert to authenticated
  with check (sender = (select auth.uid()) and private.is_match_member(match_id)
              and not exists (select 1 from public.profiles where id = (select auth.uid()) and banned_at is not null)
              and (kind = 'text' or media_path like match_id::text || '/%'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-media', 'chat-media', false, 20971520,
        array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime','video/3gpp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.chat_folder_member(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select case when (storage.foldername(p_name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then private.is_match_member(((storage.foldername(p_name))[1])::uuid) else false end;
$$;
revoke all on function private.chat_folder_member(text) from public, anon;
grant execute on function private.chat_folder_member(text) to authenticated;

drop policy if exists "chat media upload" on storage.objects;
create policy "chat media upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'chat-media' and private.chat_folder_member(name)
              and not exists (select 1 from public.profiles where id = (select auth.uid()) and banned_at is not null));
drop policy if exists "chat media read" on storage.objects;
create policy "chat media read" on storage.objects for select to authenticated
  using (bucket_id = 'chat-media' and (private.chat_folder_member(name) or private.admin_role() is not null));
drop policy if exists "chat media delete" on storage.objects;
create policy "chat media delete" on storage.objects for delete to authenticated
  using (bucket_id = 'chat-media' and (owner_id = (select auth.uid())::text or private.admin_role() is not null));

-- Match list preview says "Photo" / "Video" for media messages
create or replace function public.my_matches()
returns table (match_id uuid, created_at timestamptz, last_message_at timestamptz, last_body text,
               last_sender uuid, unread int, other jsonb)
language sql stable security definer set search_path = public as $$
  select m.id, m.created_at, m.last_message_at,
         case lm.kind when 'image' then '📷 Photo' when 'video' then '🎥 Video' else lm.body end, lm.sender,
         (select count(*)::int from public.messages x where x.match_id = m.id and x.sender <> auth.uid() and x.read_at is null),
         jsonb_build_object('id', p.id, 'name', p.name, 'age', date_part('year', age(p.birthdate))::int, 'gender', p.gender,
           'city', p.city, 'job', p.job, 'bio', p.bio, 'interests', p.interests, 'languages', p.languages,
           'looking_for', p.looking_for, 'religion', p.religion, 'photos', p.photos, 'last_active', p.last_active)
    from public.matches m
    join public.profiles p on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
    left join lateral (select body, sender, kind from public.messages where messages.match_id = m.id order by messages.created_at desc limit 1) lm on true
   where auth.uid() in (m.user_a, m.user_b)
     and p.banned_at is null
     and not private.blocked_between(m.user_a, m.user_b)
   order by coalesce(m.last_message_at, m.created_at) desc;
$$;

-- Report evidence also records photos/videos (their storage paths)
create or replace function public.capture_report_evidence() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.evidence := jsonb_build_object(
    'captured_at', now(),
    'profile', (select jsonb_build_object('name', p.name, 'bio', p.bio, 'job', p.job, 'city', p.city, 'photos', p.photos)
                  from public.profiles p where p.id = new.reported),
    'messages', coalesce((
      select jsonb_agg(jsonb_build_object('from', case when x.sender = new.reported then 'reported' else 'reporter' end,
                                          'body', x.body, 'kind', x.kind, 'media_path', x.media_path, 'at', x.created_at) order by x.created_at)
        from (select m.* from public.messages m join public.matches mt on mt.id = m.match_id
               where mt.user_a = least(new.reporter, new.reported) and mt.user_b = greatest(new.reporter, new.reported)
               order by m.created_at desc limit 50) x), '[]'::jsonb));
  return new;
end $$;

-- the scam check only reads text
create or replace function public.flag_risky_message() returns trigger
language plpgsql security definer set search_path = public as $$
declare t text := lower(coalesce(new.body, '')); m text; cat text; other uuid;
begin
  if t = '' then return new; end if;
  m := substring(t from '(orange ?money|afri ?money|mobile money|\mmomo\M|send (me )?(some )?money|transport (fare|money)|\mairtime\M|\mtop ?up\M|recharge card|western union|money ?gram|bank transfer|\m(le|sle|nle)\s?[0-9][0-9,.]*|[0-9][0-9,.]*\s?(leones?\M|le\M)|\$\s?[0-9]+)');
  if m is not null then cat := 'money';
  else
    m := substring(t from '(whats ?app|\mtelegram\M|(\+?232|\m0)[ -]?[0-9]{2}[ -]?[0-9]{3}[ -]?[0-9]{3})');
    if m is not null then cat := 'off_platform'; end if;
  end if;
  if cat is not null then
    select case when user_a = new.sender then user_b else user_a end into other from public.matches where id = new.match_id;
    insert into public.message_flags (message_id, match_id, sender, recipient, body, category, matched)
    values (new.id, new.match_id, new.sender, other, left(new.body, 2000), cat, left(m, 80));
  end if;
  return new;
end $$;
