-- Kindred: which devices members use (platform, OS, browser, phone model, app version, first/last seen),
-- shown to admins in the member panel and on the Insights page.
-- device_key is a random id the app creates once per install/browser, not a hardware identifier.
create table if not exists public.member_devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  device_key   text not null check (char_length(device_key) between 8 and 64),
  platform     text not null check (platform in ('android_app','ios_app','web')),
  os           text check (char_length(os) <= 60),
  browser      text check (char_length(browser) <= 60),
  model        text check (char_length(model) <= 80),
  app_version  text check (char_length(app_version) <= 30),
  first_seen   timestamptz not null default now(),
  last_seen    timestamptz not null default now(),
  sign_ins     int not null default 1,
  unique (user_id, device_key)
);
create index if not exists member_devices_user_idx on public.member_devices (user_id, last_seen desc);
create index if not exists member_devices_last_seen_idx on public.member_devices (last_seen desc);
alter table public.member_devices enable row level security;   -- written only through register_device, read only by admins
revoke all on public.member_devices from anon, authenticated;

create or replace function public.register_device(p_key text, p_platform text, p_os text default null, p_browser text default null,
                                                   p_model text default null, p_app_version text default null, p_new_sign_in boolean default false) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or not exists (select 1 from public.profiles where id = me) then return; end if;
  if p_platform not in ('android_app','ios_app','web') or p_key is null or char_length(p_key) not between 8 and 64 then return; end if;
  insert into public.member_devices (user_id, device_key, platform, os, browser, model, app_version)
  values (me, p_key, p_platform, left(p_os, 60), left(p_browser, 60), left(p_model, 80), left(p_app_version, 30))
  on conflict (user_id, device_key) do update set
    platform = excluded.platform, os = excluded.os, browser = excluded.browser, model = excluded.model,
    app_version = excluded.app_version, last_seen = now(),
    sign_ins = member_devices.sign_ins + case when p_new_sign_in then 1 else 0 end;
  -- keep at most 20 devices per member
  delete from public.member_devices where user_id = me and id not in
    (select id from public.member_devices where user_id = me order by last_seen desc limit 20);
end $$;
revoke all on function public.register_device(text, text, text, text, text, text, boolean) from public, anon;
grant execute on function public.register_device(text, text, text, text, text, text, boolean) to authenticated;

create or replace function public.admin_member_devices(p_member uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('platform', platform, 'os', os, 'browser', browser, 'model', model,
            'app_version', app_version, 'first_seen', first_seen, 'last_seen', last_seen, 'sign_ins', sign_ins) order by last_seen desc)
    from public.member_devices where user_id = p_member), '[]');
end $$;

-- Each real member counted once per category, by the device they used most recently.
create or replace function public.admin_device_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform private.require_admin();
  return (with d as (select md.* from public.member_devices md join public.profiles p on p.id = md.user_id where not p.is_test),
               latest as (select distinct on (user_id) * from d order by user_id, last_seen desc)
    select jsonb_build_object(
      'members_with_device', (select count(*) from latest),
      'devices', (select count(*) from d),
      'platform', coalesce((select jsonb_agg(jsonb_build_object('label', platform, 'count', c) order by c desc) from (select platform, count(*) c from latest group by 1) t), '[]'),
      'os', coalesce((select jsonb_agg(jsonb_build_object('label', os, 'count', c) order by c desc) from (select coalesce(os, 'Unknown') os, count(*) c from latest group by 1 order by 2 desc limit 8) t), '[]'),
      'browser', coalesce((select jsonb_agg(jsonb_build_object('label', browser, 'count', c) order by c desc) from (select coalesce(browser, 'Unknown') browser, count(*) c from latest where platform = 'web' group by 1 order by 2 desc limit 8) t), '[]'),
      'models', coalesce((select jsonb_agg(jsonb_build_object('label', model, 'count', c) order by c desc) from (select model, count(*) c from latest where model is not null group by 1 order by 2 desc limit 8) t), '[]'),
      'app_versions', coalesce((select jsonb_agg(jsonb_build_object('label', app_version, 'count', c) order by c desc) from (select app_version, count(*) c from latest where platform <> 'web' and app_version is not null group by 1 order by 2 desc) t), '[]'),
      'multi_device', (select count(*) from (select user_id from d group by 1 having count(*) > 1) t),
      'active_24h', coalesce((select jsonb_agg(jsonb_build_object('label', platform, 'count', c) order by c desc) from (select platform, count(distinct user_id) c from d where last_seen > now() - interval '24 hours' group by 1) t), '[]')));
end $$;
revoke all on function public.admin_member_devices(uuid), public.admin_device_stats() from public, anon;
grant execute on function public.admin_member_devices(uuid), public.admin_device_stats() to authenticated;
