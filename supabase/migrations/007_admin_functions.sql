-- Kindred: admin console functions. Every function checks the caller's role first (private.require_admin).

-- Who am I? Returns null (not an error) for non-admins so the page can show "no access".
create or replace function public.admin_me() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('role', a.role, 'email', u.email, 'name', p.name)
    from public.admins a join auth.users u on u.id = a.user_id left join public.profiles p on p.id = a.user_id
   where a.user_id = auth.uid();
$$;

create or replace function public.admin_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r jsonb;
begin
  perform private.require_admin();
  with m as (select * from public.profiles where not is_test)
  select jsonb_build_object(
    'members', (select count(*) from m),
    'onboarded', (select count(*) from m where onboarded),
    'new_7d', (select count(*) from m where created_at > now() - interval '7 days'),
    'new_30d', (select count(*) from m where created_at > now() - interval '30 days'),
    'active_24h', (select count(*) from m where last_active > now() - interval '24 hours'),
    'active_7d', (select count(*) from m where last_active > now() - interval '7 days'),
    'suspended', (select count(*) from m where banned_at is not null),
    'test_accounts', (select count(*) from public.profiles where is_test),
    'women', (select count(*) from m where gender = 'woman'),
    'men', (select count(*) from m where gender = 'man'),
    'matches', (select count(*) from public.matches mt join m on m.id = mt.user_a),
    'matches_7d', (select count(*) from public.matches mt join m on m.id = mt.user_a where mt.created_at > now() - interval '7 days'),
    'messages', (select count(*) from public.messages x join m on m.id = x.sender),
    'messages_7d', (select count(*) from public.messages x join m on m.id = x.sender where x.created_at > now() - interval '7 days'),
    'likes', (select count(*) from public.swipes s join m on m.id = s.swiper where s.action in ('like','super')),
    'passes', (select count(*) from public.swipes s join m on m.id = s.swiper where s.action = 'pass'),
    'reports_open', (select count(*) from public.reports where status = 'open'),
    'reports_total', (select count(*) from public.reports),
    'signups_daily', (select coalesce(jsonb_agg(jsonb_build_object('day', d::date, 'count', (select count(*) from m where m.created_at::date = d::date)) order by d), '[]')
                        from generate_series(current_date - 29, current_date, interval '1 day') d),
    'top_cities', (select coalesce(jsonb_agg(jsonb_build_object('label', city, 'count', c) order by c desc, city), '[]')
                     from (select city, count(*) c from m where city is not null group by city order by c desc, city limit 8) t),
    'looking_for', (select coalesce(jsonb_agg(jsonb_build_object('label', looking_for, 'count', c) order by c desc), '[]')
                      from (select looking_for, count(*) c from m where looking_for is not null group by looking_for) t),
    'age_groups', (select jsonb_agg(jsonb_build_object('label', g, 'count', (select count(*) from m where birthdate is not null and
                      case g when '18–24' then date_part('year', age(birthdate)) between 18 and 24
                             when '25–34' then date_part('year', age(birthdate)) between 25 and 34
                             when '35–44' then date_part('year', age(birthdate)) between 35 and 44
                             else date_part('year', age(birthdate)) >= 45 end)) order by ord)
                     from (values ('18–24',1),('25–34',2),('35–44',3),('45+',4)) v(g, ord))
  ) into r;
  return r;
end $$;

create or replace function public.admin_reports(p_status text default 'open', p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform private.require_admin();
  return coalesce((
    select jsonb_agg(row order by (row->>'created_at') desc) from (
      select jsonb_build_object(
        'id', r.id, 'reason', r.reason, 'details', r.details, 'status', r.status, 'created_at', r.created_at,
        'evidence', r.evidence, 'resolution_note', r.resolution_note, 'resolved_at', r.resolved_at,
        'resolved_by', (select email from auth.users where id = r.resolved_by),
        'reporter', case when r.reporter is null then null else jsonb_build_object('id', rp.id, 'name', rp.name, 'email', ru.email) end,
        'reported', jsonb_build_object('id', dp.id, 'name', dp.name, 'email', du.email, 'photos', dp.photos, 'city', dp.city,
                      'banned_at', dp.banned_at, 'reports_against', (select count(*) from public.reports x where x.reported = r.reported))
      ) as row
      from public.reports r
      join public.profiles dp on dp.id = r.reported
      left join auth.users du on du.id = r.reported
      left join public.profiles rp on rp.id = r.reporter
      left join auth.users ru on ru.id = r.reporter
      where p_status = 'all' or r.status = p_status
      order by r.created_at desc
      limit least(greatest(coalesce(p_limit, 100), 1), 500)) t), '[]');
end $$;

create or replace function public.admin_resolve_report(p_id uuid, p_status text, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare who uuid;
begin
  perform private.require_admin();
  if p_status not in ('open','reviewed','actioned') then raise exception 'Unknown status'; end if;
  update public.reports set status = p_status, resolution_note = nullif(btrim(p_note), ''),
         resolved_by = case when p_status = 'open' then null else auth.uid() end,
         resolved_at = case when p_status = 'open' then null else now() end
   where id = p_id returning reported into who;
  if not found then raise exception 'Report not found'; end if;
  perform private.audit('report_' || p_status, who, jsonb_build_object('report', p_id, 'note', p_note));
end $$;

create or replace function public.admin_members(p_search text default null, p_filter text default 'all', p_limit int default 50, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare q text := nullif(btrim(p_search), '');
begin
  perform private.require_admin();
  return (
    with base as (
      select p.*, u.email, u.last_sign_in_at, a.role as admin_role,
             (select count(*) from public.reports x where x.reported = p.id) as reports_against
        from public.profiles p join auth.users u on u.id = p.id left join public.admins a on a.user_id = p.id
       where (q is null or p.name ilike '%' || q || '%' or u.email ilike '%' || q || '%' or p.city ilike '%' || q || '%')
         and case p_filter when 'suspended' then p.banned_at is not null
                           when 'test' then p.is_test
                           when 'incomplete' then not p.onboarded
                           when 'reported' then exists (select 1 from public.reports x where x.reported = p.id)
                           when 'admins' then a.role is not null
                           else true end)
    select jsonb_build_object(
      'total', (select count(*) from base),
      'rows', coalesce((select jsonb_agg(jsonb_build_object(
          'id', id, 'name', name, 'email', email, 'age', date_part('year', age(birthdate))::int, 'gender', gender, 'city', city,
          'photo', photos[1], 'onboarded', onboarded, 'banned_at', banned_at, 'is_test', is_test, 'created_at', created_at,
          'last_active', last_active, 'reports_against', reports_against, 'admin_role', admin_role) order by created_at desc)
        from (select * from base order by created_at desc limit least(greatest(coalesce(p_limit, 50), 1), 200) offset greatest(coalesce(p_offset, 0), 0)) pg), '[]')));
end $$;

create or replace function public.admin_member(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform private.require_admin();
  return (select jsonb_build_object(
      'id', p.id, 'name', p.name, 'email', u.email, 'age', date_part('year', age(p.birthdate))::int, 'birthdate', p.birthdate,
      'gender', p.gender, 'show_me', p.show_me, 'city', p.city, 'job', p.job, 'bio', p.bio, 'interests', p.interests,
      'languages', p.languages, 'looking_for', p.looking_for, 'religion', p.religion, 'photos', p.photos,
      'onboarded', p.onboarded, 'is_test', p.is_test, 'banned_at', p.banned_at, 'ban_reason', p.ban_reason,
      'created_at', p.created_at, 'last_active', p.last_active, 'last_sign_in_at', u.last_sign_in_at,
      'email_confirmed', u.email_confirmed_at is not null, 'admin_role', a.role,
      'counts', jsonb_build_object(
        'matches', (select count(*) from public.matches where p.id in (user_a, user_b)),
        'messages_sent', (select count(*) from public.messages where sender = p.id),
        'likes_given', (select count(*) from public.swipes where swiper = p.id and action in ('like','super')),
        'likes_received', (select count(*) from public.swipes where target = p.id and action in ('like','super')),
        'reports_made', (select count(*) from public.reports where reporter = p.id),
        'reports_against', (select count(*) from public.reports where reported = p.id),
        'blocked_by', (select count(*) from public.blocks where blocked = p.id)),
      'reports_against', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'reason', r.reason, 'status', r.status, 'created_at', r.created_at) order by r.created_at desc)
                                     from public.reports r where r.reported = p.id), '[]'))
    from public.profiles p join auth.users u on u.id = p.id left join public.admins a on a.user_id = p.id
   where p.id = p_id);
end $$;

create or replace function public.admin_suspend(p_user uuid, p_reason text) returns void
language plpgsql security definer set search_path = public, auth as $$
declare my_role text := private.require_admin();
begin
  if p_user = auth.uid() then raise exception 'You cannot suspend yourself'; end if;
  if exists (select 1 from public.admins where user_id = p_user) and my_role <> 'super_admin' then raise exception 'Only a super admin can suspend another admin'; end if;
  if coalesce(btrim(p_reason), '') = '' then raise exception 'Give a reason for the suspension'; end if;
  update public.profiles set banned_at = now(), ban_reason = btrim(p_reason) where id = p_user;
  if not found then raise exception 'Member not found'; end if;
  update auth.users set banned_until = 'infinity' where id = p_user;   -- blocks sign-in and token refresh
  delete from auth.sessions where user_id = p_user;                     -- signs them out everywhere
  perform private.audit('suspend', p_user, jsonb_build_object('reason', p_reason));
end $$;

create or replace function public.admin_unsuspend(p_user uuid) returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  perform private.require_admin();
  update public.profiles set banned_at = null, ban_reason = null where id = p_user;
  if not found then raise exception 'Member not found'; end if;
  update auth.users set banned_until = null where id = p_user;
  perform private.audit('unsuspend', p_user, null);
end $$;

create or replace function public.admin_remove_photo(p_user uuid, p_url text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform private.require_admin();
  update public.profiles set photos = array_remove(photos, p_url) where id = p_user and p_url = any(photos);
  if not found then raise exception 'Photo not found on this profile'; end if;
  perform private.audit('remove_photo', p_user, jsonb_build_object('url', p_url));
end $$;

create or replace function public.admin_delete_member(p_user uuid) returns void
language plpgsql security definer set search_path = public, auth as $$
declare nm text; em text;
begin
  perform private.require_admin(true);
  if p_user = auth.uid() then raise exception 'You cannot delete your own account here'; end if;
  select p.name, u.email into nm, em from public.profiles p join auth.users u on u.id = p.id where p.id = p_user;
  if nm is null then raise exception 'Member not found'; end if;
  perform private.audit('delete_member', p_user, jsonb_build_object('name', nm, 'email', em));
  delete from auth.users where id = p_user;   -- cascades to profile, matches, messages, admin role
end $$;

create or replace function public.admin_set_test(p_user uuid, p_is_test boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform private.require_admin(true);
  update public.profiles set is_test = p_is_test where id = p_user;
  if not found then raise exception 'Member not found'; end if;
  perform private.audit(case when p_is_test then 'mark_test' else 'unmark_test' end, p_user, null);
end $$;

create or replace function public.admin_team() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('user_id', a.user_id, 'role', a.role, 'email', u.email, 'name', p.name,
            'added_by', (select email from auth.users where id = a.added_by), 'created_at', a.created_at,
            'last_sign_in_at', u.last_sign_in_at) order by a.role desc, a.created_at)
    from public.admins a join auth.users u on u.id = a.user_id left join public.profiles p on p.id = a.user_id), '[]');
end $$;

create or replace function public.admin_add(p_email text, p_role text) returns void
language plpgsql security definer set search_path = public, auth as $$
declare uid uuid;
begin
  perform private.require_admin(true);
  if p_role not in ('super_admin','moderator') then raise exception 'Role must be super_admin or moderator'; end if;
  select id into uid from auth.users where lower(email) = lower(btrim(p_email));
  if uid is null then raise exception 'No Kindred account uses that email. Ask them to sign up first.'; end if;
  insert into public.admins (user_id, role, added_by) values (uid, p_role, auth.uid())
  on conflict (user_id) do update set role = excluded.role;
  perform private.audit('admin_add', uid, jsonb_build_object('role', p_role, 'email', p_email));
end $$;

create or replace function public.admin_remove(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform private.require_admin(true);
  if (select role from public.admins where user_id = p_user) = 'super_admin'
     and (select count(*) from public.admins where role = 'super_admin') <= 1 then
    raise exception 'Kindred must keep at least one super admin';
  end if;
  delete from public.admins where user_id = p_user;
  if not found then raise exception 'Not an admin'; end if;
  perform private.audit('admin_remove', p_user, null);
end $$;

create or replace function public.admin_audit_log(p_limit int default 200) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'admin_email', admin_email, 'action', action, 'target', target,
            'target_name', target_name, 'details', details, 'created_at', created_at) order by created_at desc)
    from (select * from public.admin_audit order by created_at desc limit least(greatest(coalesce(p_limit, 200), 1), 1000)) t), '[]');
end $$;

revoke all on function public.admin_me(), public.admin_stats(), public.admin_reports(text, int), public.admin_resolve_report(uuid, text, text),
  public.admin_members(text, text, int, int), public.admin_member(uuid), public.admin_suspend(uuid, text), public.admin_unsuspend(uuid),
  public.admin_remove_photo(uuid, text), public.admin_delete_member(uuid), public.admin_set_test(uuid, boolean),
  public.admin_team(), public.admin_add(text, text), public.admin_remove(uuid), public.admin_audit_log(int) from public, anon;
grant execute on function public.admin_me(), public.admin_stats(), public.admin_reports(text, int), public.admin_resolve_report(uuid, text, text),
  public.admin_members(text, text, int, int), public.admin_member(uuid), public.admin_suspend(uuid, text), public.admin_unsuspend(uuid),
  public.admin_remove_photo(uuid, text), public.admin_delete_member(uuid), public.admin_set_test(uuid, boolean),
  public.admin_team(), public.admin_add(text, text), public.admin_remove(uuid), public.admin_audit_log(int) to authenticated;
