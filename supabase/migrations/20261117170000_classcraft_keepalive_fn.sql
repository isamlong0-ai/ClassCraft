-- 20261117170000 - classcraft keepalive fn
create or replace function public.keepalive()
returns integer
language sql
security definer
set search_path = public
as  select 1 ;

revoke all on function public.keepalive() from public;
grant execute on function public.keepalive() to anon;
grant execute on function public.keepalive() to authenticated;
