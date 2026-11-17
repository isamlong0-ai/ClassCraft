-- 20261117174026 - classcraft system_monitor
create table if not exists public.system_monitor (
  id uuid primary key default gen_random_uuid(),
  checked_at timestamptz not null default now(),
  status text not null default 'ok' check (status in ('ok','error')),
  detail text default '',
  created_at timestamptz not null default now()
);
alter table public.system_monitor enable row level security;
create policy read_system_monitor on public.system_monitor for select to authenticated using (public.is_admin());
