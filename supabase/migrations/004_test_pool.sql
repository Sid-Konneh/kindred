-- Kindred: test / app-review accounts live in a separate pool and only ever see each other.
-- is_test is not in the column grants, so members cannot change it. Set it with SQL:
--   update public.profiles set is_test = true where id = '<user id>';
alter table public.profiles add column if not exists is_test boolean not null default false;

create or replace function public.discover_feed(p_limit int default 20, p_city text default null)
returns table (id uuid, name text, age int, gender text, city text, job text, bio text, interests text[],
               languages text[], looking_for text, religion text, photos text[], last_active timestamptz)
language sql stable security definer set search_path = public as $$
  with me as (select * from public.profiles where profiles.id = auth.uid())
  select p.id, p.name, date_part('year', age(p.birthdate))::int, p.gender, p.city, p.job, p.bio, p.interests,
         p.languages, p.looking_for, p.religion, p.photos, p.last_active
    from public.profiles p, me
   where p.id <> me.id
     and p.is_test = me.is_test
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
  if not exists (select 1 from public.profiles t, public.profiles m
                  where t.id = p_target and t.onboarded and m.id = me and t.is_test = m.is_test) then
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
