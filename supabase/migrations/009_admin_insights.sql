-- Kindred: admin Insights page (engagement, retention, activity heatmap, profile quality, safety, leaderboards)
-- and the "online now" count. Real members only (profiles.is_test = false).
create or replace function public.admin_online() returns int
language plpgsql stable security definer set search_path = public as $$
begin
  perform private.require_admin();
  return (select count(*) from public.profiles where not is_test and last_active > now() - interval '15 minutes');
end $$;
revoke all on function public.admin_online() from public, anon;
grant execute on function public.admin_online() to authenticated;

create or replace function public.admin_insights() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r jsonb;
begin
  perform private.require_admin();
  with
  m as (select * from public.profiles where not is_test),
  rm as (select mt.* from public.matches mt join m a on a.id = mt.user_a join m b on b.id = mt.user_b),
  rmsg as (select x.* from public.messages x join m on m.id = x.sender),
  convo as (select match_id, count(*) n, count(distinct sender) senders from rmsg group by match_id),
  likes as (select s.* from public.swipes s join m on m.id = s.swiper where s.action in ('like','super')),
  first_match as (
    select p.id, min(mt.created_at) - p.created_at as wait
      from m p join rm mt on p.id in (mt.user_a, mt.user_b) group by p.id, p.created_at),
  replies as (
    select extract(epoch from (created_at - lag(created_at) over w)) / 60 as mins,
           sender <> lag(sender) over w as is_reply
      from rmsg window w as (partition by match_id order by created_at)),
  events as (
    select created_at from rmsg where created_at > now() - interval '30 days'
    union all select s.created_at from public.swipes s join m on m.id = s.swiper where s.created_at > now() - interval '30 days')
  select jsonb_build_object(
    'online_now', (select count(*) from m where last_active > now() - interval '15 minutes'),
    'engagement', jsonb_build_object(
      'members', (select count(*) from m where onboarded),
      'matches', (select count(*) from rm),
      'likes', (select count(*) from likes),
      'match_rate', (select case when count(*) = 0 then null else round(100.0 * (select count(*) from rm) / count(*), 1) end from likes),
      'avg_matches_per_member', (select case when count(*) = 0 then null else round(2.0 * (select count(*) from rm) / count(*), 2) end from m where onboarded),
      'pct_matches_with_chat', (select case when count(*) = 0 then null else round(100.0 * (select count(*) from convo) / count(*), 1) end from rm),
      'pct_two_way', (select case when count(*) = 0 then null else round(100.0 * count(*) filter (where senders = 2) / count(*), 1) end from convo),
      'avg_messages_per_chat', (select round(avg(n), 1) from convo),
      'median_hours_to_first_match', (select round((extract(epoch from percentile_cont(0.5) within group (order by wait)) / 3600)::numeric, 1) from first_match),
      'median_reply_minutes', (select round(percentile_cont(0.5) within group (order by mins)::numeric, 1) from replies where is_reply)),
    'retention', coalesce((select jsonb_agg(jsonb_build_object('week', wk, 'joined', joined, 'active', active) order by wk desc)
        from (select date_trunc('week', created_at)::date wk, count(*) joined, count(*) filter (where last_active > now() - interval '7 days') active
                from m where created_at > now() - interval '8 weeks' group by 1) t), '[]'),
    'heatmap', coalesce((select jsonb_agg(jsonb_build_object('dow', dow, 'hour', hr, 'count', c))
        from (select extract(isodow from created_at)::int dow, extract(hour from created_at)::int hr, count(*) c from events group by 1, 2) t), '[]'),
    'profiles', jsonb_build_object(
      'avg_photos', (select round(avg(cardinality(photos)), 1) from m where onboarded),
      'pct_3_photos', (select case when count(*) = 0 then null else round(100.0 * count(*) filter (where cardinality(photos) >= 3) / count(*), 1) end from m where onboarded),
      'pct_bio', (select case when count(*) = 0 then null else round(100.0 * count(*) filter (where char_length(bio) >= 30) / count(*), 1) end from m where onboarded),
      'show_me', coalesce((select jsonb_agg(jsonb_build_object('label', show_me, 'count', c) order by c desc) from (select show_me, count(*) c from m where onboarded group by 1) t), '[]'),
      'religion', coalesce((select jsonb_agg(jsonb_build_object('label', coalesce(religion, 'not_set'), 'count', c) order by c desc) from (select religion, count(*) c from m where onboarded group by 1) t), '[]'),
      'interests', coalesce((select jsonb_agg(jsonb_build_object('label', v, 'count', c) order by c desc, v) from (select v, count(*) c from m, unnest(interests) v group by v order by c desc, v limit 12) t), '[]'),
      'languages', coalesce((select jsonb_agg(jsonb_build_object('label', v, 'count', c) order by c desc, v) from (select v, count(*) c from m, unnest(languages) v group by v order by c desc, v limit 10) t), '[]')),
    'safety', jsonb_build_object(
      'reports_by_reason', coalesce((select jsonb_agg(jsonb_build_object('label', reason, 'count', c) order by c desc) from (select reason, count(*) c from public.reports group by 1) t), '[]'),
      'flags_by_category', coalesce((select jsonb_agg(jsonb_build_object('label', category, 'count', c) order by c desc) from (select category, count(*) c from public.message_flags group by 1) t), '[]'),
      'blocks', (select count(*) from public.blocks b join m on m.id = b.blocker),
      'blocks_7d', (select count(*) from public.blocks b join m on m.id = b.blocker where b.created_at > now() - interval '7 days'),
      'suspended_now', (select count(*) from m where banned_at is not null),
      'suspensions_30d', (select count(*) from public.admin_audit where action = 'suspend' and created_at > now() - interval '30 days'),
      'median_hours_to_resolve', (select round((extract(epoch from percentile_cont(0.5) within group (order by resolved_at - created_at)) / 3600)::numeric, 1)
                                    from public.reports where resolved_at is not null),
      'open_reports', (select count(*) from public.reports where status = 'open'),
      'open_flags', (select count(*) from public.message_flags where status = 'open')),
    'leaders', jsonb_build_object(
      'most_liked', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'city', city, 'photo', photos[1], 'count', c, 'joined', created_at) order by c desc)
          from (select p.id, p.name, p.city, p.photos, p.created_at, count(*) c from likes l join m p on p.id = l.target group by p.id, p.name, p.city, p.photos, p.created_at order by c desc limit 5) t), '[]'),
      'most_messages', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'city', city, 'photo', photos[1], 'count', c, 'joined', created_at) order by c desc)
          from (select p.id, p.name, p.city, p.photos, p.created_at, count(*) c from rmsg x join m p on p.id = x.sender group by p.id, p.name, p.city, p.photos, p.created_at order by c desc limit 5) t), '[]'))
  ) into r;
  return r;
end $$;
revoke all on function public.admin_insights() from public, anon;
grant execute on function public.admin_insights() to authenticated;
