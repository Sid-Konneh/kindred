-- Push notifications that reach a CLOSED app: Web Push for the website and the iPhone home-screen app, and
-- Firebase Cloud Messaging for the Android app once it is configured. Every alert row (likes, matches, messages,
-- migration 017) and every call that starts ringing or is missed is handed to the "push" edge function, which
-- sends it to the recipient's registered devices. Keys live in Vault (names starting push_), never in this file:
--   push_hook_secret      shared secret between these triggers and the edge function
--   push_vapid_public / push_vapid_private / push_contact   Web Push signing keys and contact address
--   push_fcm_service_account   Firebase service account JSON (optional, enables Android pushes)
create extension if not exists pg_net;

create table if not exists public.push_devices (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  kind       text not null check (kind in ('web','fcm')),
  endpoint   text not null unique,     -- the Web Push endpoint URL, or the FCM registration token
  p256dh     text,                     -- Web Push encryption keys
  auth       text,
  created_at timestamptz not null default now(),
  last_seen  timestamptz not null default now()
);
create index if not exists push_devices_user_idx on public.push_devices (user_id);
alter table public.push_devices enable row level security;
revoke all on public.push_devices from anon, authenticated;

create or replace function public.register_push(p_kind text, p_endpoint text, p_p256dh text default null, p_auth text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Please sign in again.'; end if;
  if p_kind not in ('web','fcm') or coalesce(char_length(p_endpoint), 0) not between 10 and 1000 then raise exception 'Invalid device.'; end if;
  insert into public.push_devices (user_id, kind, endpoint, p256dh, auth) values (auth.uid(), p_kind, p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update set user_id = auth.uid(), kind = excluded.kind, p256dh = excluded.p256dh, auth = excluded.auth, last_seen = now();
  -- at most 10 devices per member
  delete from public.push_devices where user_id = auth.uid()
     and id not in (select id from public.push_devices where user_id = auth.uid() order by last_seen desc limit 10);
end $$;

-- Called on sign-out, so the next person to sign in on a shared phone doesn't get this member's alerts.
create or replace function public.unregister_push(p_endpoint text) returns void
language sql security definer set search_path = public as $$
  delete from public.push_devices where endpoint = p_endpoint and user_id = auth.uid();
$$;
revoke all on function public.register_push(text, text, text, text), public.unregister_push(text) from public, anon;
grant execute on function public.register_push(text, text, text, text), public.unregister_push(text) to authenticated;

-- The edge function reads its keys through this (service role only).
create or replace function public.push_config() returns jsonb
language sql stable security definer set search_path = public, vault as $$
  select coalesce(jsonb_object_agg(name, decrypted_secret), '{}'::jsonb) from vault.decrypted_secrets where name like 'push\_%';
$$;
revoke all on function public.push_config() from public, anon, authenticated;
grant execute on function public.push_config() to service_role;

create or replace function private.push_send(p_to uuid, p_payload jsonb) returns void
language plpgsql security definer set search_path = public, vault as $$
declare v_secret text;
begin
  if not exists (select 1 from public.push_devices where user_id = p_to) then return; end if;
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'push_hook_secret';
  if v_secret is null then return; end if; -- push not set up
  perform net.http_post(
    url := 'https://febcajqqmswcfzsawxmy.supabase.co/functions/v1/push',
    body := p_payload || jsonb_build_object('to', p_to),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', v_secret),
    timeout_milliseconds := 8000);
exception when others then null; -- a push problem must never block a like, match, message or call
end $$;
revoke all on function private.push_send(uuid, jsonb) from public, anon, authenticated;

create or replace function public.push_notification() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform private.push_send(new.recipient, jsonb_build_object(
    'kind', new.kind, 'title', new.title, 'body', new.body, 'match_id', new.match_id,
    'link', case when new.match_id is null then 'discover' else 'chat/' || new.match_id end,
    'tag', coalesce(new.match_id::text, new.kind)));
  return null;
end $$;
drop trigger if exists notifications_push on public.notifications;
create trigger notifications_push after insert on public.notifications for each row execute function public.push_notification();

-- Ringing calls, and calls that stopped ringing unanswered (the "is calling you" alert becomes "Missed call").
create or replace function public.push_call() returns trigger
language plpgsql security definer set search_path = public as $$
declare n text;
begin
  select name into n from public.profiles where id = new.caller;
  if tg_op = 'INSERT' and new.status = 'ringing' then
    perform private.push_send(new.callee, jsonb_build_object(
      'kind', 'call', 'title', coalesce(n, 'Your match') || ' is calling you', 'body', case when new.video then 'Kindred video call' else 'Kindred voice call' end,
      'match_id', new.match_id, 'link', 'chat/' || new.match_id, 'tag', 'call-' || new.id));
  elsif tg_op = 'UPDATE' and old.status = 'ringing' and new.status in ('missed', 'cancelled') then
    perform private.push_send(new.callee, jsonb_build_object(
      'kind', 'missed_call', 'title', 'Missed call from ' || coalesce(n, 'your match'), 'body', 'Tap to open the chat.',
      'match_id', new.match_id, 'link', 'chat/' || new.match_id, 'tag', 'call-' || new.id));
  end if;
  return null;
end $$;
drop trigger if exists calls_push on public.calls;
create trigger calls_push after insert or update of status on public.calls for each row execute function public.push_call();

revoke all on function public.push_notification(), public.push_call() from public, anon, authenticated;
