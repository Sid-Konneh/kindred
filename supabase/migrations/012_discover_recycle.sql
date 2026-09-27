-- Kindred: when there's nobody new, Discover can bring back people you passed on, reshuffled ("Start over").
-- Liked people stay out (they may still like you back), as do matches, blocked, suspended and test accounts.
-- p_recycle defaults to false, so older app versions that call discover_feed(p_limit, p_city) keep working.
drop function if exists public.discover_feed(int, text);
create or replace function public.discover_feed(p_limit int default 20, p_city text default null, p_recycle boolean default false)
returns table (id uuid, name text, age int, gender text, city text, job text, bio text, interests text[],
               languages text[], looking_for text, religion text, photos text[], last_active timestamptz)
language sql volatile security definer set search_path = public as $$
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
     and not private.blocked_between(me.id, p.id)
     and not exists (select 1 from public.matches mt where mt.user_a = least(me.id, p.id) and mt.user_b = greatest(me.id, p.id))
     and case when coalesce(p_recycle, false)
              then exists (select 1 from public.swipes s where s.swiper = me.id and s.target = p.id and s.action = 'pass')
              else not exists (select 1 from public.swipes s where s.swiper = me.id and s.target = p.id) end
   order by case when coalesce(p_recycle, false) then random() end,
            exists (select 1 from public.swipes s2 where s2.swiper = p.id and s2.target = me.id and s2.action in ('like','super')) desc,
            p.last_active desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;
revoke all on function public.discover_feed(int, text, boolean) from public, anon;
grant execute on function public.discover_feed(int, text, boolean) to authenticated;
