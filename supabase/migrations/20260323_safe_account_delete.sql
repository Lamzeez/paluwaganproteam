alter table public.profiles
  add column if not exists is_deleted boolean not null default false,
  add column if not exists deleted_at timestamp with time zone null;

comment on column public.profiles.is_deleted is
'Marks a profile as anonymized after a safe account deletion flow.';

comment on column public.profiles.deleted_at is
'Timestamp when the profile was anonymized by the safe account deletion flow.';
