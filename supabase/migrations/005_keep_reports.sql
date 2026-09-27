-- Kindred: a report survives the reporter deleting their account (the reporter link is cleared instead).
alter table public.reports alter column reporter drop not null;
alter table public.reports drop constraint if exists reports_reporter_fkey;
alter table public.reports add constraint reports_reporter_fkey foreign key (reporter) references public.profiles(id) on delete set null;
