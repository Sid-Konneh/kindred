-- Kindred: dating platform for Sierra Leone
-- Run 001 then 002 in Supabase: Dashboard > SQL Editor > New query > paste > Run. Safe to re-run.
--
-- Security model
--  * Row level security on every table. Nobody can read another person's row directly.
--  * Other people's profiles are only reachable through discover_feed() and my_matches(),
--    which return public fields (age, never birthdate) and hide anyone who blocked you.
--  * A match can only be created by swipe(), when both people liked each other.
--  * You can only message people you are matched with.
--  * Birthdate is checked (18+) in the database and can't be changed once set.

create extension if not exists pgcrypto;

-- ---------- tables ----------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 40),
  birthdate   date,
  gender      text check (gender in ('woman','man')),
  show_me     text not null default 'everyone' check (show_me in ('women','men','everyone')),
  city        text check (char_length(city) <= 60),
  job         text check (char_length(job) <= 60),
  bio         text not null default '' check (char_length(bio) <= 500),
  interests   text[] not null default '{}' check (cardinality(interests) <= 10),
  languages   text[] not null default '{}' check (cardinality(languages) <= 13),
  looking_for text check (looking_for in ('relationship','marriage','friendship','not_sure')),
  religion    text check (religion in ('muslim','christian','other','prefer_not')),
  photos      text[] not null default '{}' check (cardinality(photos) <= 6),
  age_min     int not null default 18 check (age_min between 18 and 99),
  age_max     int not null default 45 check (age_max between 18 and 99),
  onboarded   boolean not null default false,
  last_active timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  check (age_min <= age_max)
);

create table if not exists public.swipes (
  swiper     uuid not null references public.profiles(id) on delete cascade,
  target     uuid not null references public.profiles(id) on delete cascade,
  action     text not null check (action in ('like','pass','super')),
  created_at timestamptz not null default now(),
  primary key (swiper, target),
  check (swiper <> target)
);
create index if not exists swipes_target_idx on public.swipes (target, action);

create table if not exists public.matches (
  id              uuid primary key default gen_random_uuid(),
  user_a          uuid not null references public.profiles(id) on delete cascade,
  user_b          uuid not null references public.profiles(id) on delete cascade,
  created_at      timestamptz not null default now(),
  last_message_at timestamptz,
  unique (user_a, user_b),
  check (user_a < user_b)
);
create index if not exists matches_b_idx on public.matches (user_b);

create table if not exists public.messages (
  id         uuid primary key default gen_random_uuid(),
  match_id   uuid not null references public.matches(id) on delete cascade,
  sender     uuid not null references public.profiles(id) on delete cascade,
  body       text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at    timestamptz
);
create index if not exists messages_match_idx on public.messages (match_id, created_at);

create table if not exists public.blocks (
  blocker    uuid not null references public.profiles(id) on delete cascade,
  blocked    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);

create table if not exists public.reports (
  id         uuid primary key default gen_random_uuid(),
  reporter   uuid not null references public.profiles(id) on delete cascade,
  reported   uuid not null references public.profiles(id) on delete cascade,
  reason     text not null check (char_length(reason) between 1 and 80),
  details    text check (char_length(details) <= 1000),
  status     text not null default 'open' check (status in ('open','reviewed','actioned')),
  created_at timestamptz not null default now()
);

-- ---------- triggers ----------
-- New sign-ups (email or Google) get a profile row automatically.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare bd date;
begin
  begin bd := nullif(new.raw_user_meta_data->>'birthdate', '')::date; exception when others then bd := null; end;
  insert into public.profiles (id, name, birthdate)
  values (
    new.id,
    left(coalesce(nullif(btrim(new.raw_user_meta_data->>'name'), ''),
                  nullif(split_part(btrim(new.raw_user_meta_data->>'full_name'), ' ', 1), ''),
                  split_part(new.email, '@', 1)), 40),
    bd
  )
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- 18+ only, and birthdate can be set once (Google sign-ups set it during onboarding).
create or replace function public.guard_profile() returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'UPDATE' and old.birthdate is not null and new.birthdate is distinct from old.birthdate then
    raise exception 'Date of birth cannot be changed' using errcode = 'check_violation';
  end if;
  if new.birthdate is not null and new.birthdate > (current_date - interval '18 years')::date then
    raise exception 'You must be 18 or older to use Kindred' using errcode = 'check_violation';
  end if;
  if new.onboarded and (new.birthdate is null or new.gender is null) then
    raise exception 'Profile is incomplete' using errcode = 'check_violation';
  end if;
  return new;
end $$;
drop trigger if exists profiles_guard on public.profiles;
create trigger profiles_guard before insert or update on public.profiles
  for each row execute function public.guard_profile();

create or replace function public.bump_match() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.matches set last_message_at = new.created_at where id = new.match_id;
  return new;
end $$;
drop trigger if exists messages_bump on public.messages;
create trigger messages_bump after insert on public.messages
  for each row execute function public.bump_match();

-- Blocking someone also removes the match (and with it the chat).
create or replace function public.drop_blocked_match() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from public.matches
   where user_a = least(new.blocker, new.blocked) and user_b = greatest(new.blocker, new.blocked);
  return new;
end $$;
drop trigger if exists blocks_drop_match on public.blocks;
create trigger blocks_drop_match after insert on public.blocks
  for each row execute function public.drop_blocked_match();

-- ---------- helpers ----------
create or replace function public.is_match_member(p_match uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.matches where id = p_match and auth.uid() in (user_a, user_b));
$$;

create or replace function public.blocked_between(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.blocks where (blocker = a and blocked = b) or (blocker = b and blocked = a));
$$;

-- ---------- row level security ----------
alter table public.profiles enable row level security;
alter table public.swipes   enable row level security;
alter table public.matches  enable row level security;
alter table public.messages enable row level security;
alter table public.blocks   enable row level security;
alter table public.reports  enable row level security;

drop policy if exists profiles_own_select on public.profiles;
create policy profiles_own_select on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists profiles_own_update on public.profiles;
create policy profiles_own_update on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists swipes_own_select on public.swipes;
create policy swipes_own_select on public.swipes for select to authenticated using (swiper = auth.uid());

drop policy if exists matches_member_select on public.matches;
create policy matches_member_select on public.matches for select to authenticated using (auth.uid() in (user_a, user_b));

drop policy if exists messages_member_select on public.messages;
create policy messages_member_select on public.messages for select to authenticated using (public.is_match_member(match_id));
drop policy if exists messages_member_insert on public.messages;
create policy messages_member_insert on public.messages for insert to authenticated
  with check (sender = auth.uid() and public.is_match_member(match_id));

drop policy if exists blocks_own on public.blocks;
create policy blocks_own on public.blocks for all to authenticated using (blocker = auth.uid()) with check (blocker = auth.uid());

drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports for insert to authenticated with check (reporter = auth.uid());

-- Column-level privileges: users can edit their profile fields but not id, created_at or onboarding shortcuts.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (name, birthdate, gender, show_me, city, job, bio, interests, languages, looking_for, religion, photos, age_min, age_max, onboarded, last_active)
  on public.profiles to authenticated;
revoke all on public.swipes, public.matches from anon, authenticated;
grant select on public.swipes, public.matches to authenticated;
revoke all on public.messages from anon, authenticated;
grant select, insert on public.messages to authenticated;
revoke all on public.blocks, public.reports from anon, authenticated;
grant select, insert, delete on public.blocks to authenticated;
grant insert on public.reports to authenticated;

-- ---------- functions the app calls ----------
create or replace function public.discover_feed(p_limit int default 20, p_city text default null)
returns table (id uuid, name text, age int, gender text, city text, job text, bio text, interests text[],
               languages text[], looking_for text, religion text, photos text[], last_active timestamptz)
language sql stable security definer set search_path = public as $$
  with me as (select * from public.profiles where profiles.id = auth.uid())
  select p.id, p.name, date_part('year', age(p.birthdate))::int, p.gender, p.city, p.job, p.bio, p.interests,
         p.languages, p.looking_for, p.religion, p.photos, p.last_active
    from public.profiles p, me
   where p.id <> me.id
     and p.onboarded and p.birthdate is not null
     and (me.show_me = 'everyone' or (me.show_me = 'women' and p.gender = 'woman') or (me.show_me = 'men' and p.gender = 'man'))
     and (p.show_me = 'everyone' or (p.show_me = 'women' and me.gender = 'woman') or (p.show_me = 'men' and me.gender = 'man'))
     and date_part('year', age(p.birthdate)) between me.age_min and me.age_max
     and (p_city is null or p.city = p_city)
     and not exists (select 1 from public.swipes s where s.swiper = me.id and s.target = p.id)
     and not public.blocked_between(me.id, p.id)
   order by exists (select 1 from public.swipes s2 where s2.swiper = p.id and s2.target = me.id and s2.action in ('like','super')) desc,
            p.last_active desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

create or replace function public.swipe(p_target uuid, p_action text) returns uuid
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); a uuid; b uuid; mid uuid;
begin
  if me is null then raise exception 'Please sign in again'; end if;
  if p_action not in ('like','pass','super') then raise exception 'Unknown action'; end if;
  if p_target = me then raise exception 'You cannot swipe on yourself'; end if;
  if not exists (select 1 from public.profiles where id = p_target and onboarded) then raise exception 'Profile not found'; end if;

  insert into public.swipes (swiper, target, action) values (me, p_target, p_action)
  on conflict (swiper, target) do update set action = excluded.action, created_at = now();

  if p_action in ('like','super')
     and exists (select 1 from public.swipes where swiper = p_target and target = me and action in ('like','super'))
     and not public.blocked_between(me, p_target) then
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
     and not public.blocked_between(m.user_a, m.user_b)
   order by coalesce(m.last_message_at, m.created_at) desc;
$$;

create or replace function public.mark_read(p_match uuid) returns void
language sql security definer set search_path = public as $$
  update public.messages set read_at = now()
   where match_id = p_match and sender <> auth.uid() and read_at is null and public.is_match_member(p_match);
$$;

create or replace function public.unmatch(p_match uuid) returns void
language sql security definer set search_path = public as $$
  delete from public.matches where id = p_match and auth.uid() in (user_a, user_b);
$$;

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Please sign in again'; end if;
  -- Photos are removed by the app through the Storage API first (Supabase blocks deleting them from SQL).
  delete from auth.users where id = me; -- cascades to profile, swipes, matches, messages, blocks
end $$;

revoke all on function public.discover_feed(int, text), public.swipe(uuid, text), public.my_matches(),
  public.mark_read(uuid), public.unmatch(uuid), public.delete_my_account(),
  public.is_match_member(uuid), public.blocked_between(uuid, uuid) from public, anon;
grant execute on function public.discover_feed(int, text), public.swipe(uuid, text), public.my_matches(),
  public.mark_read(uuid), public.unmatch(uuid), public.delete_my_account(),
  public.is_match_member(uuid), public.blocked_between(uuid, uuid) to authenticated;
revoke all on function public.handle_new_user(), public.bump_match(), public.drop_blocked_match() from public, anon, authenticated;

-- ---------- realtime chat ----------
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; end $$;

-- ---------- photo storage ----------
-- Public bucket with unguessable file names, so photos load fast and cache well on slow networks.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "photos upload own folder" on storage.objects;
create policy "photos upload own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "photos delete own" on storage.objects;
create policy "photos delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
