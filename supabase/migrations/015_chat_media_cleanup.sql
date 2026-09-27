-- Chat photos/videos whose message is gone (unmatch, account deletion, or an upload whose message never
-- got saved). SQL can't delete storage files, so the chat-media-cleanup edge function removes these.
create index if not exists messages_media_path_idx on public.messages (media_path) where media_path is not null;
create or replace function public.chat_media_orphans(p_limit int default 500)
returns table (name text)
language sql stable security definer set search_path = public as $$
  select o.name from storage.objects o
   where o.bucket_id = 'chat-media'
     and o.created_at < now() - interval '10 minutes'
     and not exists (select 1 from public.messages m where m.media_path = o.name)
   limit least(greatest(coalesce(p_limit, 500), 1), 1000);
$$;
revoke all on function public.chat_media_orphans(int) from public, anon, authenticated;
grant execute on function public.chat_media_orphans(int) to service_role;
