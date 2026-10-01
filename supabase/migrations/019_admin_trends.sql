-- Kindred: admin trends. This week against last week, daily active members, women and men, and towns.
-- "Active" means the member did something that day (swiped, sent a message or started a call). That differs
-- from profiles.last_active, which keeps only the latest visit. Real members only (profiles.is_test = false).
create or replace function public.admin_trends() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r jsonb;
begin
  perform private.require_admin();
  with
  m as (select id, gender, city, onboarded, created_at from public.profiles where not is_test),
  acts as (
    select s.swiper uid, s.created_at ts from public.swipes s join m on m.id = s.swiper where s.created_at > now() - interval '60 days'
    union all select x.sender, x.created_at from public.messages x join m on m.id = x.sender where x.created_at > now() - interval '60 days'
    union all select c.caller, c.created_at from public.calls c join m on m.id = c.caller where c.created_at > now() - interval '60 days'),
  likes as (select s.swiper, s.target, s.created_at from public.swipes s join m on m.id = s.swiper where s.action in ('like','super')),
  rm as (select mt.user_a, mt.user_b, mt.created_at from public.matches mt join m a on a.id = mt.user_a join m b on b.id = mt.user_b),
  wk(k, lo, hi) as (values ('cur', now() - interval '7 days', now()), ('prev', now() - interval '14 days', now() - interval '7 days')),
  p as (
    select m.*,
           exists (select 1 from acts a where a.uid = m.id and a.ts > now() - interval '7 days') active_7d,
           exists (select 1 from rm where m.id in (rm.user_a, rm.user_b)) matched
      from m where onboarded)
  select jsonb_build_object(
    'weeks', (select jsonb_object_agg(k, jsonb_build_object(
        'signups',  (select count(*) from m where created_at >= lo and created_at < hi),
        'active',   (select count(distinct uid) from acts where ts >= lo and ts < hi),
        'likes',    (select count(*) from likes where created_at >= lo and created_at < hi),
        'matches',  (select count(*) from rm where created_at >= lo and created_at < hi),
        'messages', (select count(*) from public.messages x join m on m.id = x.sender where x.created_at >= lo and x.created_at < hi),
        'calls',    (select count(*) from public.calls c join m on m.id = c.caller where c.created_at >= lo and c.created_at < hi),
        'reports',  (select count(*) from public.reports where created_at >= lo and created_at < hi))) from wk),
    'dau', (select jsonb_agg(jsonb_build_object('day', g::date, 'count', (select count(distinct uid) from acts where ts::date = g::date)) order by g)
              from generate_series(current_date - 29, current_date, interval '1 day') g),
    'wau', (select count(distinct uid) from acts where ts > now() - interval '7 days'),
    'mau', (select count(distinct uid) from acts where ts > now() - interval '30 days'),
    'stale_reports', (select count(*) from public.reports where status = 'open' and created_at < now() - interval '48 hours'),
    'stale_flags', (select count(*) from public.message_flags where status = 'open' and created_at < now() - interval '48 hours'),
    'gender', (select jsonb_agg(jsonb_build_object(
        'gender', g,
        'members', (select count(*) from p where p.gender = g),
        'active_7d', (select count(*) from p where p.gender = g and active_7d),
        'with_match', (select count(*) from p where p.gender = g and matched),
        'likes_sent', (select count(*) from likes l join m on m.id = l.swiper where m.gender = g),
        'likes_received', (select count(*) from likes l join m on m.id = l.target where m.gender = g)) order by ord)
        from (values ('woman', 1), ('man', 2)) v(g, ord)),
    'towns', coalesce((select jsonb_agg(jsonb_build_object('city', city, 'members', n, 'women', w, 'men', mn, 'new_30d', nw, 'active_7d', act, 'matched', mt)
                                        order by n desc, city)
        from (select city, count(*) n, count(*) filter (where gender = 'woman') w, count(*) filter (where gender = 'man') mn,
                     count(*) filter (where created_at > now() - interval '30 days') nw,
                     count(*) filter (where active_7d) act, count(*) filter (where matched) mt
                from p where city is not null group by city order by n desc, city limit 12) t), '[]')
  ) into r;
  return r;
end $$;
revoke all on function public.admin_trends() from public, anon;
grant execute on function public.admin_trends() to authenticated;
