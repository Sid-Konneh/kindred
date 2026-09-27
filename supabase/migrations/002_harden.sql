-- Kindred: hardening applied after 001.
-- Moves internal helpers out of the public API (so nobody can ask "has X blocked Y?"),
-- makes RLS evaluate auth.uid() once per query, and adds indexes for foreign keys.

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_match_member(p_match uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.matches where id = p_match and (select auth.uid()) in (user_a, user_b));
$$;
create or replace function private.blocked_between(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.blocks where (blocker = a and blocked = b) or (blocker = b and blocked = a));
$$;
revoke all on function private.is_match_member(uuid), private.blocked_between(uuid, uuid) from public, anon;
grant execute on function private.is_match_member(uuid), private.blocked_between(uuid, uuid) to authenticated;

drop policy if exists profiles_own_select on public.profiles;
create policy profiles_own_select on public.profiles for select to authenticated using (id = (select auth.uid()));
drop policy if exists profiles_own_update on public.profiles;
create policy profiles_own_update on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
drop policy if exists swipes_own_select on public.swipes;
create policy swipes_own_select on public.swipes for select to authenticated using (swiper = (select auth.uid()));
drop policy if exists matches_member_select on public.matches;
create policy matches_member_select on public.matches for select to authenticated using ((select auth.uid()) in (user_a, user_b));
drop policy if exists messages_member_select on public.messages;
create policy messages_member_select on public.messages for select to authenticated using (private.is_match_member(match_id));
drop policy if exists messages_member_insert on public.messages;
create policy messages_member_insert on public.messages for insert to authenticated
  with check (sender = (select auth.uid()) and private.is_match_member(match_id));
drop policy if exists blocks_own on public.blocks;
create policy blocks_own on public.blocks for all to authenticated using (blocker = (select auth.uid())) with check (blocker = (select auth.uid()));
drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports for insert to authenticated with check (reporter = (select auth.uid()));

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
  if p_action not in ('like','pass','super') then raise exception 'Unknown action'; end if;
  if p_target = me then raise exception 'You cannot swipe on yourself'; end if;
  if not exists (select 1 from public.profiles where id = p_target and onboarded) then raise exception 'Profile not found'; end if;
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
     and not private.blocked_between(m.user_a, m.user_b)
   order by coalesce(m.last_message_at, m.created_at) desc;
$$;

create or replace function public.mark_read(p_match uuid) returns void
language sql security definer set search_path = public as $$
  update public.messages set read_at = now()
   where match_id = p_match and sender <> auth.uid() and read_at is null and private.is_match_member(p_match);
$$;

drop function if exists public.is_match_member(uuid);
drop function if exists public.blocked_between(uuid, uuid);

create index if not exists blocks_blocked_idx on public.blocks (blocked);
create index if not exists messages_sender_idx on public.messages (sender);
create index if not exists reports_reported_idx on public.reports (reported);
create index if not exists reports_reporter_idx on public.reports (reporter);
