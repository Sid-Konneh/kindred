-- Kindred: admin console (roles, moderation, suspensions, report evidence, audit log).
-- Grant the first super admin once, by hand:
--   insert into public.admins (user_id, role) select id, 'super_admin' from auth.users where email = 'you@example.com';

create table if not exists public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null check (role in ('super_admin','moderator')),
  added_by   uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.admin_audit (
  id          bigint generated always as identity primary key,
  admin_id    uuid references auth.users(id) on delete set null,
  admin_email text,
  action      text not null,
  target      uuid,
  target_name text,
  details     jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists admin_audit_created_idx on public.admin_audit (created_at desc);
alter table public.admins enable row level security;       -- no policies on purpose: only reachable through admin_* functions
alter table public.admin_audit enable row level security;
revoke all on public.admins, public.admin_audit from anon, authenticated;

alter table public.profiles add column if not exists banned_at timestamptz;
alter table public.profiles add column if not exists ban_reason text check (char_length(ban_reason) <= 500);
alter table public.reports add column if not exists evidence jsonb;
alter table public.reports add column if not exists resolved_by uuid references auth.users(id) on delete set null;
alter table public.reports add column if not exists resolved_at timestamptz;
alter table public.reports add column if not exists resolution_note text check (char_length(resolution_note) <= 1000);
create index if not exists reports_status_idx on public.reports (status, created_at desc);

-- ---------- helpers ----------
create or replace function private.admin_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.admins where user_id = auth.uid();
$$;

create or replace function private.require_admin(p_super boolean default false) returns text
language plpgsql stable security definer set search_path = public as $$
declare r text := private.admin_role();
begin
  if r is null then raise exception 'Admins only' using errcode = '42501'; end if;
  if p_super and r <> 'super_admin' then raise exception 'Super admins only' using errcode = '42501'; end if;
  return r;
end $$;

create or replace function private.audit(p_action text, p_target uuid, p_details jsonb default null) returns void
language sql security definer set search_path = public as $$
  insert into public.admin_audit (admin_id, admin_email, action, target, target_name, details)
  values (auth.uid(), (select email from auth.users where id = auth.uid()), p_action, p_target,
          (select name from public.profiles where id = p_target), p_details);
$$;
revoke all on function private.admin_role(), private.require_admin(boolean), private.audit(text, uuid, jsonb) from public, anon;
grant execute on function private.admin_role(), private.require_admin(boolean), private.audit(text, uuid, jsonb) to authenticated;

-- ---------- evidence: copy the recent chat into a report before the block deletes it ----------
create or replace function public.capture_report_evidence() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.evidence := jsonb_build_object(
    'captured_at', now(),
    'profile', (select jsonb_build_object('name', p.name, 'bio', p.bio, 'job', p.job, 'city', p.city, 'photos', p.photos)
                  from public.profiles p where p.id = new.reported),
    'messages', coalesce((
      select jsonb_agg(jsonb_build_object('from', case when x.sender = new.reported then 'reported' else 'reporter' end,
                                          'body', x.body, 'at', x.created_at) order by x.created_at)
        from (select m.* from public.messages m join public.matches mt on mt.id = m.match_id
               where mt.user_a = least(new.reporter, new.reported) and mt.user_b = greatest(new.reporter, new.reported)
               order by m.created_at desc limit 50) x), '[]'::jsonb));
  return new;
end $$;
drop trigger if exists reports_evidence on public.reports;
create trigger reports_evidence before insert on public.reports for each row execute function public.capture_report_evidence();
revoke all on function public.capture_report_evidence() from public, anon, authenticated;

-- ---------- suspended members can't act, and disappear for everyone else ----------
create or replace function public.discover_feed(p_limit int default 20, p_city text default null)
returns table (id uuid, name text, age int, gender text, city text, job text, bio text, interests text[],
               languages text[], looking_for text, religion text, photos text[], last_active timestamptz)
language sql stable security definer set search_path = public as $$
  with me as (select * from public.profiles where profiles.id = auth.uid() and banned_at is null)
  select p.id, p.name, date_part('year', age(p.birthdate))::int, p.gender, p.city, p.job, p.bio, p.interests,
         p.languages, p.looking_for, p.religion, p.photos, p.last_active
    from public.profiles p, me
   where p.id <> me.id
     and p.is_test = me.is_test
     and p.banned_at is null
     and p.onboarded and p.birthdate is not null
     and (me.show_me = 'everyone' or (me.show_me = 'women' and p.gender = 'woman') or (me.show_me = 'men' and p.gender = 'man'))
     and (p.show_me = 'everyone' or (p.show_me = 'women' and me.gender = 'woman') or (p.show_me = 'men' and me.gender = 'man'))
     and date_part('year', age(p.birthdate)) between me.age_min and me.age_max
     and (p_city is null or p.city = p_city)
     and not exists (select 1 from public.swipes s where s.swiper = me.id and s.target = p.id)
     and not private.blocked_between(me.id, p.id)
   order by exists (select 1 from public.swipes s2 where s2.swiper = p.id and s2.target = me.id and s2.action in ('like','super')) desc,
            p.last_active desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

create or replace function public.swipe(p_target uuid, p_action text) returns uuid
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); a uuid; b uuid; mid uuid;
begin
  if me is null then raise exception 'Please sign in again'; end if;
  if exists (select 1 from public.profiles where id = me and banned_at is not null) then raise exception 'This account has been suspended'; end if;
  if p_action not in ('like','pass','super') then raise exception 'Unknown action'; end if;
  if p_target = me then raise exception 'You cannot swipe on yourself'; end if;
  if not exists (select 1 from public.profiles t, public.profiles m
                  where t.id = p_target and t.onboarded and t.banned_at is null and m.id = me and t.is_test = m.is_test) then
    raise exception 'Profile not found';
  end if;
  insert into public.swipes (swiper, target, action) values (me, p_target, p_action)
  on conflict (swiper, target) do update set action = excluded.action, created_at = now();
  if p_action in ('like','super')
     and exists (select 1 from public.swipes where swiper = p_target and target = me and action in ('like','super'))
     and not private.blocked_between(me, p_target) then
    a := least(me, p_target); b := greatest(me, p_target);
    insert into public.matches (user_a, user_b) values (a, b)
    on conflict (user_a, user_b) do nothing returning id into mid;
    if mid is null then select id into mid from public.matches where user_a = a and user_b = b; end if;
    return mid;
  end if;
  return null;
end $$;

create or replace function public.my_matches()
returns table (match_id uuid, created_at timestamptz, last_message_at timestamptz, last_body text,
               last_sender uuid, unread int, other jsonb)
language sql stable security definer set search_path = public as $$
  select m.id, m.created_at, m.last_message_at, lm.body, lm.sender,
         (select count(*)::int from public.messages x where x.match_id = m.id and x.sender <> auth.uid() and x.read_at is null),
         jsonb_build_object('id', p.id, 'name', p.name, 'age', date_part('year', age(p.birthdate))::int, 'gender', p.gender,
           'city', p.city, 'job', p.job, 'bio', p.bio, 'interests', p.interests, 'languages', p.languages,
           'looking_for', p.looking_for, 'religion', p.religion, 'photos', p.photos, 'last_active', p.last_active)
    from public.matches m
    join public.profiles p on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
    left join lateral (select body, sender from public.messages where messages.match_id = m.id order by messages.created_at desc limit 1) lm on true
   where auth.uid() in (m.user_a, m.user_b)
     and p.banned_at is null
     and not private.blocked_between(m.user_a, m.user_b)
   order by coalesce(m.last_message_at, m.created_at) desc;
$$;

drop policy if exists messages_member_insert on public.messages;
create policy messages_member_insert on public.messages for insert to authenticated
  with check (sender = (select auth.uid()) and private.is_match_member(match_id)
              and not exists (select 1 from public.profiles where id = (select auth.uid()) and banned_at is not null));

-- admins may list and delete any member photo (to remove a bad photo, or clean up a deleted member)
drop policy if exists "photos admin read" on storage.objects;
create policy "photos admin read" on storage.objects for select to authenticated using (bucket_id = 'photos' and private.admin_role() is not null);
drop policy if exists "photos admin delete" on storage.objects;
create policy "photos admin delete" on storage.objects for delete to authenticated using (bucket_id = 'photos' and private.admin_role() is not null);
