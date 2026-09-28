-- Alerts for likes, matches and messages. Triggers write one row for the person being alerted, and each of
-- their devices listens to its own rows over Realtime while Kindred is open or in the background.
-- Clients never write this table. Likes carry no name or match: swipes are private, so the alert only says
-- "Someone liked you". Calls need no row here; the apps already hear ringing calls on the calls table.
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  recipient  uuid not null references public.profiles(id) on delete cascade,
  kind       text not null check (kind in ('like','super','match','message')),
  match_id   uuid references public.matches(id) on delete cascade,
  title      text not null,
  body       text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists notifications_recipient_idx on public.notifications (recipient, created_at desc);
alter table public.notifications enable row level security;
drop policy if exists notifications_own_select on public.notifications;
create policy notifications_own_select on public.notifications for select to authenticated
  using (recipient = (select auth.uid()));
revoke insert, update, delete on public.notifications from anon, authenticated;
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; end $$;

-- Rows are only needed long enough to reach an open app, so old ones are pruned as new ones arrive.
create or replace function private.notify(p_to uuid, p_kind text, p_match uuid, p_title text, p_body text) returns void
language sql security definer set search_path = public as $$
  delete from public.notifications where recipient = p_to and created_at < now() - interval '3 days';
  insert into public.notifications (recipient, kind, match_id, title, body) values (p_to, p_kind, p_match, p_title, coalesce(p_body, ''));
$$;
revoke all on function private.notify(uuid, text, uuid, text, text) from public, anon, authenticated;

-- A like or super like. If they had already liked back, swipe() creates a match and that alert is sent instead.
create or replace function public.notify_like() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.action not in ('like','super') then return null; end if;
  if tg_op = 'UPDATE' and old.action in ('like','super') then return null; end if;
  if exists (select 1 from public.swipes where swiper = new.target and target = new.swiper and action in ('like','super')) then return null; end if;
  if private.blocked_between(new.swiper, new.target) then return null; end if;
  perform private.notify(new.target, new.action, null,
    case new.action when 'super' then 'Someone super liked you 🌟' else 'Someone liked you 💘' end,
    'Keep swiping in Discover. They could be next.');
  return null;
end $$;
drop trigger if exists swipes_notify on public.swipes;
create trigger swipes_notify after insert or update of action on public.swipes
  for each row execute function public.notify_like();

create or replace function public.notify_match() returns trigger
language plpgsql security definer set search_path = public as $$
declare na text; nb text;
begin
  select name into na from public.profiles where id = new.user_a;
  select name into nb from public.profiles where id = new.user_b;
  perform private.notify(new.user_a, 'match', new.id, 'It''s a match! 💞', 'You and ' || coalesce(nb, 'your match') || ' liked each other. Say hello!');
  perform private.notify(new.user_b, 'match', new.id, 'It''s a match! 💞', 'You and ' || coalesce(na, 'your match') || ' liked each other. Say hello!');
  return null;
end $$;
drop trigger if exists matches_notify on public.matches;
create trigger matches_notify after insert on public.matches
  for each row execute function public.notify_match();

create or replace function public.notify_message() returns trigger
language plpgsql security definer set search_path = public as $$
declare mt public.matches; other uuid; n text;
begin
  select * into mt from public.matches where id = new.match_id;
  if mt.id is null then return null; end if;
  other := case when mt.user_a = new.sender then mt.user_b else mt.user_a end;
  if private.blocked_between(new.sender, other) then return null; end if;
  select name into n from public.profiles where id = new.sender;
  perform private.notify(other, 'message', new.match_id, coalesce(n, 'New message'),
    case new.kind when 'image' then '📷 Photo' when 'video' then '🎥 Video'
         else case when char_length(new.body) > 120 then left(new.body, 117) || '…' else new.body end end);
  return null;
end $$;
drop trigger if exists messages_notify on public.messages;
create trigger messages_notify after insert on public.messages
  for each row execute function public.notify_message();

revoke all on function public.notify_like(), public.notify_match(), public.notify_message() from public, anon, authenticated;
