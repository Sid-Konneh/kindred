-- Kindred: admin features 2 — scam alerts on risky messages, private member notes, daily activity,
-- sign-up funnel, recent-photo review and CSV exports.

create table if not exists public.message_flags (
  id          uuid primary key default gen_random_uuid(),
  message_id  uuid references public.messages(id) on delete set null,
  match_id    uuid,
  sender      uuid references public.profiles(id) on delete cascade,
  recipient   uuid references public.profiles(id) on delete set null,
  body        text not null,
  category    text not null check (category in ('money','off_platform')),
  matched     text,
  status      text not null default 'open' check (status in ('open','dismissed','actioned')),
  resolved_by uuid references auth.users(id) on delete set null,
  resolved_at timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists message_flags_status_idx on public.message_flags (status, created_at desc);
create index if not exists message_flags_sender_idx on public.message_flags (sender);
alter table public.message_flags enable row level security;   -- admins only, through functions
revoke all on public.message_flags from anon, authenticated;

-- Flags money requests (Orange Money, Afrimoney, airtime, "Le 200"...) and attempts to move off Kindred
-- (WhatsApp, Telegram, Sierra Leone phone numbers). Tested against innocent phrases such as "people 20" and "Momodu".
create or replace function public.flag_risky_message() returns trigger
language plpgsql security definer set search_path = public as $$
declare t text := lower(new.body); m text; cat text; other uuid;
begin
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
drop trigger if exists messages_flag on public.messages;
create trigger messages_flag after insert on public.messages for each row execute function public.flag_risky_message();
revoke all on function public.flag_risky_message() from public, anon, authenticated;

create table if not exists public.member_notes (
  id         uuid primary key default gen_random_uuid(),
  member_id  uuid not null references public.profiles(id) on delete cascade,
  admin_id   uuid references auth.users(id) on delete set null,
  body       text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists member_notes_member_idx on public.member_notes (member_id, created_at desc);
alter table public.member_notes enable row level security;
revoke all on public.member_notes from anon, authenticated;

create or replace function public.admin_flags(p_status text default 'open', p_limit int default 200) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(row order by (row->>'created_at') desc) from (
    select jsonb_build_object('id', f.id, 'body', f.body, 'category', f.category, 'matched', f.matched, 'status', f.status,
      'created_at', f.created_at, 'resolved_at', f.resolved_at, 'resolved_by', (select email from auth.users where id = f.resolved_by),
      'sender', jsonb_build_object('id', s.id, 'name', s.name, 'photos', s.photos, 'banned_at', s.banned_at,
                  'flags', (select count(*) from public.message_flags x where x.sender = f.sender)),
      'recipient', case when r.id is null then null else jsonb_build_object('id', r.id, 'name', r.name) end) as row
    from public.message_flags f join public.profiles s on s.id = f.sender left join public.profiles r on r.id = f.recipient
    where p_status = 'all' or f.status = p_status
    order by f.created_at desc limit least(greatest(coalesce(p_limit, 200), 1), 500)) t), '[]');
end $$;

create or replace function public.admin_resolve_flag(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare who uuid;
begin
  perform private.require_admin();
  if p_status not in ('open','dismissed','actioned') then raise exception 'Unknown status'; end if;
  update public.message_flags set status = p_status,
         resolved_by = case when p_status = 'open' then null else auth.uid() end,
         resolved_at = case when p_status = 'open' then null else now() end
   where id = p_id returning sender into who;
  if not found then raise exception 'Flag not found'; end if;
  perform private.audit('flag_' || p_status, who, jsonb_build_object('flag', p_id));
end $$;

create or replace function public.admin_resolve_flags_for(p_sender uuid, p_status text) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  perform private.require_admin();
  if p_status not in ('dismissed','actioned') then raise exception 'Unknown status'; end if;
  update public.message_flags set status = p_status, resolved_by = auth.uid(), resolved_at = now()
   where sender = p_sender and status = 'open';
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.admin_notes(p_member uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'body', n.body, 'created_at', n.created_at,
            'admin', (select email from auth.users where id = n.admin_id), 'mine', n.admin_id = auth.uid()) order by n.created_at desc)
    from public.member_notes n where n.member_id = p_member), '[]');
end $$;

create or replace function public.admin_add_note(p_member uuid, p_body text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform private.require_admin();
  insert into public.member_notes (member_id, admin_id, body) values (p_member, auth.uid(), btrim(p_body));
  perform private.audit('note_add', p_member, jsonb_build_object('note', left(btrim(p_body), 200)));
end $$;

create or replace function public.admin_delete_note(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare who uuid; author uuid;
begin
  perform private.require_admin();
  select member_id, admin_id into who, author from public.member_notes where id = p_id;
  if who is null then raise exception 'Note not found'; end if;
  if author is distinct from auth.uid() and private.admin_role() <> 'super_admin' then raise exception 'Only the author or a super admin can delete a note'; end if;
  delete from public.member_notes where id = p_id;
  perform private.audit('note_delete', who, null);
end $$;

create or replace function public.admin_activity(p_days int default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d int := least(greatest(coalesce(p_days, 30), 7), 180);
begin
  perform private.require_admin();
  return (select jsonb_agg(jsonb_build_object(
      'day', g::date,
      'signups',  (select count(*) from public.profiles p where not p.is_test and p.created_at::date = g::date),
      'matches',  (select count(*) from public.matches m join public.profiles p on p.id = m.user_a where not p.is_test and m.created_at::date = g::date),
      'messages', (select count(*) from public.messages x join public.profiles p on p.id = x.sender where not p.is_test and x.created_at::date = g::date),
      'likes',    (select count(*) from public.swipes s join public.profiles p on p.id = s.swiper where not p.is_test and s.action in ('like','super') and s.created_at::date = g::date),
      'reports',  (select count(*) from public.reports r where r.created_at::date = g::date),
      'flags',    (select count(*) from public.message_flags f where f.created_at::date = g::date)) order by g)
    from generate_series(current_date - (d - 1), current_date, interval '1 day') g);
end $$;

create or replace function public.admin_funnel() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform private.require_admin();
  return (with m as (select id, onboarded, photos from public.profiles where not is_test)
    select jsonb_build_array(
      jsonb_build_object('label', 'Joined', 'count', (select count(*) from m)),
      jsonb_build_object('label', 'Finished profile', 'count', (select count(*) from m where onboarded)),
      jsonb_build_object('label', 'Added a photo', 'count', (select count(*) from m where cardinality(photos) > 0)),
      jsonb_build_object('label', 'Liked someone', 'count', (select count(distinct s.swiper) from public.swipes s join m on m.id = s.swiper where s.action in ('like','super'))),
      jsonb_build_object('label', 'Got a match', 'count', (select count(*) from m where exists (select 1 from public.matches x where m.id in (x.user_a, x.user_b)))),
      jsonb_build_object('label', 'Sent a message', 'count', (select count(distinct x.sender) from public.messages x join m on m.id = x.sender))));
end $$;

create or replace function public.admin_recent_photos(p_limit int default 60, p_before timestamptz default null) returns jsonb
language plpgsql stable security definer set search_path = public, storage as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(row order by (row->>'uploaded_at') desc) from (
    select jsonb_build_object('path', o.name, 'uploaded_at', o.created_at, 'member', jsonb_build_object('id', p.id, 'name', p.name, 'is_test', p.is_test, 'banned_at', p.banned_at)) as row
      from storage.objects o
      join public.profiles p on p.id::text = (storage.foldername(o.name))[1]
     where o.bucket_id = 'photos'
       and exists (select 1 from unnest(p.photos) u where u like '%/' || o.name)
       and (p_before is null or o.created_at < p_before)
     order by o.created_at desc
     limit least(greatest(coalesce(p_limit, 60), 1), 200)) t), '[]');
end $$;

create or replace function public.admin_export_members() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform private.require_admin(true);
  perform private.audit('export_members', null, null);
  return coalesce((select jsonb_agg(jsonb_build_object('name', p.name, 'email', u.email, 'age', date_part('year', age(p.birthdate))::int,
      'gender', p.gender, 'city', p.city, 'looking_for', p.looking_for, 'onboarded', p.onboarded, 'photos', cardinality(p.photos),
      'suspended', p.banned_at is not null, 'test_account', p.is_test, 'joined', p.created_at, 'last_active', p.last_active,
      'reports_against', (select count(*) from public.reports r where r.reported = p.id)) order by p.created_at)
    from public.profiles p join auth.users u on u.id = p.id), '[]');
end $$;

create or replace function public.admin_export_reports() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform private.require_admin(true);
  perform private.audit('export_reports', null, null);
  return coalesce((select jsonb_agg(jsonb_build_object('created', r.created_at, 'reason', r.reason, 'details', r.details, 'status', r.status,
      'reporter', rp.name, 'reported', dp.name, 'reported_email', du.email, 'resolved_by', (select email from auth.users where id = r.resolved_by),
      'resolved_at', r.resolved_at, 'note', r.resolution_note) order by r.created_at)
    from public.reports r join public.profiles dp on dp.id = r.reported left join auth.users du on du.id = r.reported
    left join public.profiles rp on rp.id = r.reporter), '[]');
end $$;

revoke all on function public.admin_flags(text, int), public.admin_resolve_flag(uuid, text), public.admin_resolve_flags_for(uuid, text),
  public.admin_notes(uuid), public.admin_add_note(uuid, text), public.admin_delete_note(uuid), public.admin_activity(int), public.admin_funnel(),
  public.admin_recent_photos(int, timestamptz), public.admin_export_members(), public.admin_export_reports() from public, anon;
grant execute on function public.admin_flags(text, int), public.admin_resolve_flag(uuid, text), public.admin_resolve_flags_for(uuid, text),
  public.admin_notes(uuid), public.admin_add_note(uuid, text), public.admin_delete_note(uuid), public.admin_activity(int), public.admin_funnel(),
  public.admin_recent_photos(int, timestamptz), public.admin_export_members(), public.admin_export_reports() to authenticated;
