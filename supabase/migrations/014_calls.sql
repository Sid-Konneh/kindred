-- Voice & video calls between matches. The call itself is peer-to-peer WebRTC; this table only carries
-- the ringing / answer handshake (SDP) over Realtime and doubles as the call history shown in chat.
-- Clients never write it directly: start_call and update_call check membership, blocks, bans and transitions.
create table if not exists public.calls (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  caller uuid not null references public.profiles(id) on delete cascade,
  callee uuid not null references public.profiles(id) on delete cascade,
  video boolean not null default false,
  status text not null default 'ringing'
    check (status in ('ringing','accepted','declined','busy','missed','cancelled','ended','failed')),
  offer text check (char_length(offer) <= 30000),
  answer text check (char_length(answer) <= 30000),
  created_at timestamptz not null default now(),
  answered_at timestamptz,
  ended_at timestamptz,
  ended_by uuid
);
create index if not exists calls_callee_idx on public.calls (callee, created_at desc);
create index if not exists calls_caller_idx on public.calls (caller, created_at desc);
create index if not exists calls_match_idx on public.calls (match_id, created_at desc);
alter table public.calls enable row level security;
drop policy if exists calls_party_select on public.calls;
create policy calls_party_select on public.calls for select to authenticated
  using ((select auth.uid()) in (caller, callee));
revoke insert, update, delete on public.calls from anon, authenticated;
alter publication supabase_realtime add table public.calls;

create or replace function public.start_call(p_match uuid, p_video boolean, p_offer text)
returns public.calls
language plpgsql volatile security definer set search_path = public as $$
declare me uuid := auth.uid(); mt public.matches; other uuid; c public.calls;
begin
  if me is null then raise exception 'Please sign in again.'; end if;
  select * into mt from public.matches where id = p_match;
  if mt.id is null or me not in (mt.user_a, mt.user_b) then raise exception 'This match is no longer available.'; end if;
  other := case when mt.user_a = me then mt.user_b else mt.user_a end;
  if private.blocked_between(me, other) then raise exception 'This match is no longer available.'; end if;
  if exists (select 1 from public.profiles where id in (me, other) and banned_at is not null) then
    raise exception 'This account can''t make calls.'; end if;
  if p_offer is null or char_length(p_offer) < 20 then raise exception 'Call setup failed. Please try again.'; end if;
  if (select count(*) from public.calls where caller = me and created_at > now() - interval '10 minutes') >= 15 then
    raise exception 'Too many calls. Please wait a few minutes.'; end if;
  -- anything still "ringing" between these two is stale now
  update public.calls set status = 'missed', ended_at = now()
   where match_id = p_match and status = 'ringing';
  insert into public.calls (match_id, caller, callee, video, offer)
  values (p_match, me, other, coalesce(p_video, false), p_offer) returning * into c;
  return c;
end $$;
revoke all on function public.start_call(uuid, boolean, text) from public, anon;
grant execute on function public.start_call(uuid, boolean, text) to authenticated;

create or replace function public.update_call(p_call uuid, p_status text, p_answer text default null)
returns public.calls
language plpgsql volatile security definer set search_path = public as $$
declare me uuid := auth.uid(); c public.calls;
begin
  select * into c from public.calls where id = p_call for update;
  if c.id is null or me not in (c.caller, c.callee) then raise exception 'Call not found.'; end if;
  if c.status = 'ringing' and me = c.callee and p_status = 'accepted' then
    if p_answer is null or char_length(p_answer) < 20 then raise exception 'Call setup failed.'; end if;
    update public.calls set status = 'accepted', answer = p_answer, answered_at = now() where id = p_call returning * into c;
  elsif c.status = 'ringing' and me = c.callee and p_status in ('declined','busy','failed') then
    update public.calls set status = p_status, ended_at = now(), ended_by = me where id = p_call returning * into c;
  elsif c.status = 'ringing' and me = c.caller and p_status in ('cancelled','missed','failed') then
    update public.calls set status = p_status, ended_at = now(), ended_by = me where id = p_call returning * into c;
  elsif c.status = 'accepted' and p_status in ('ended','failed') then
    update public.calls set status = p_status, ended_at = now(), ended_by = me where id = p_call returning * into c;
  end if; -- anything else (e.g. both sides hanging up at once) is a no-op
  return c;
end $$;
revoke all on function public.update_call(uuid, text, text) from public, anon;
grant execute on function public.update_call(uuid, text, text) to authenticated;

-- Calls still ringing for me right now (server clock, so a phone with the wrong time doesn't see ghost calls)
create or replace function public.my_ringing_calls()
returns setof public.calls
language sql stable security definer set search_path = public as $$
  select * from public.calls
   where callee = auth.uid() and status = 'ringing' and created_at > now() - interval '45 seconds'
   order by created_at desc limit 1;
$$;
revoke all on function public.my_ringing_calls() from public, anon;
grant execute on function public.my_ringing_calls() to authenticated;
