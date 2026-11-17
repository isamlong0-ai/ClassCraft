-- 20261117174206 - classcraft auto backup setup
insert into storage.buckets (id, name, public)
values ('classcraft-backups', 'classcraft-backups', false)
on conflict (id) do nothing;

create table if not exists public.app_secrets (
  key text primary key,
  value text not null
);
alter table public.app_secrets enable row level security;
create policy read_app_secrets_admin on public.app_secrets for select to authenticated using (public.is_admin());

insert into public.app_secrets(key, value)
values ('cron_backup', encode(gen_random_bytes(24), 'base64'))
on conflict (key) do nothing;
