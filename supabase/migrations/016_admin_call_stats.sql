-- Admin overview: calls and chat photos/videos (real members only, like admin_stats)
create or replace function public.admin_call_stats()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r jsonb;
begin
  perform private.require_admin();
  with m as (select id from public.profiles where not is_test),
       c as (select c.* from public.calls c join m on m.id = c.caller)
  select jsonb_build_object(
    'calls', (select count(*) from c),
    'calls_7d', (select count(*) from c where created_at > now() - interval '7 days'),
    'video_share', (select round(100.0 * count(*) filter (where video) / nullif(count(*), 0)) from c),
    'answered_rate', (select round(100.0 * count(*) filter (where answered_at is not null) / nullif(count(*), 0)) from c),
    'failed', (select count(*) from c where status = 'failed'),
    'avg_seconds', (select round(avg(extract(epoch from ended_at - answered_at))) from c where answered_at is not null and ended_at is not null),
    'media', (select count(*) from public.messages x join m on m.id = x.sender where x.kind in ('image','video')),
    'media_7d', (select count(*) from public.messages x join m on m.id = x.sender where x.kind in ('image','video') and x.created_at > now() - interval '7 days'),
    'videos', (select count(*) from public.messages x join m on m.id = x.sender where x.kind = 'video')
  ) into r;
  return r;
end $$;
revoke all on function public.admin_call_stats() from public, anon;
grant execute on function public.admin_call_stats() to authenticated;
