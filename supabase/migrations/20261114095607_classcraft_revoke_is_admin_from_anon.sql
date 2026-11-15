-- =============================================================
-- 20261114095607 - classcraft_revoke_is_admin_from_anon
-- Batasi fungsi is_admin() hanya untuk pengguna yang login.
-- =============================================================

revoke all on function public.is_admin() from anon, public;
grant execute on function public.is_admin() to authenticated;
