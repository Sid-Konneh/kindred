-- Kindred: reject malformed and throwaway email addresses at the database (the app also checks the
-- domain can receive mail and suggests fixes for typos like gmial.com), and require real first names.
create or replace function private.email_problem(p_email text) returns text
language plpgsql immutable set search_path = public as $$
declare e text := lower(btrim(coalesce(p_email, ''))); dom text := split_part(e, '@', 2);
begin
  if e !~ '^[a-z0-9._%+''-]+@[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\.[a-z]{2,}$'
     or e ~ '\.\.' or split_part(e, '@', 1) ~ '(^\.|\.$)' or char_length(e) > 254 then
    return 'invalid';
  end if;
  if dom = any (array['mailinator.com','yopmail.com','10minutemail.com','guerrillamail.com','guerrillamail.net','sharklasers.com',
      'tempmail.com','temp-mail.org','tempmail.net','tempmailo.com','throwawaymail.com','trashmail.com','getnada.com','nada.email',
      'dispostable.com','maildrop.cc','fakeinbox.com','mintemail.com','emailondeck.com','mohmal.com','burnermail.io','mailnesia.com',
      'mytemp.email','tempr.email','discard.email','spamgourmet.com','getairmail.com','moakt.com','tmail.ws','emailfake.com','1secmail.com',
      'guerrillamailblock.com','mailcatch.com','inboxkitten.com','tempinbox.com','dropmail.me','fakemail.net','byom.de','33mail.com']) then
    return 'disposable';
  end if;
  return null;
end $$;

create or replace function public.check_signup_email() returns trigger
language plpgsql security definer set search_path = public as $$
declare p text;
begin
  if new.email like '%@kindred.test' then return new; end if;   -- test and reviewer accounts
  p := private.email_problem(new.email);
  if p = 'invalid' then raise exception 'Kindred: please use a valid email address' using errcode = 'check_violation'; end if;
  if p = 'disposable' then raise exception 'Kindred: temporary email addresses are not allowed' using errcode = 'check_violation'; end if;
  return new;
end $$;
drop trigger if exists check_signup_email on auth.users;
create trigger check_signup_email before insert or update of email on auth.users
  for each row execute function public.check_signup_email();
revoke all on function public.check_signup_email() from public, anon, authenticated;

create or replace function public.guard_profile() returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'UPDATE' and old.birthdate is not null and new.birthdate is distinct from old.birthdate then
    raise exception 'Date of birth cannot be changed' using errcode = 'check_violation';
  end if;
  if new.birthdate is not null and new.birthdate > (current_date - interval '18 years')::date then
    raise exception 'You must be 18 or older to use Kindred' using errcode = 'check_violation';
  end if;
  if (tg_op = 'INSERT' or new.name is distinct from old.name) and new.name !~ '^[[:alpha:]][[:alpha:] ''.-]{1,39}$' then
    raise exception 'Please use your real first name (letters only)' using errcode = 'check_violation';
  end if;
  if new.onboarded and (new.birthdate is null or new.gender is null) then
    raise exception 'Profile is incomplete' using errcode = 'check_violation';
  end if;
  return new;
end $$;
