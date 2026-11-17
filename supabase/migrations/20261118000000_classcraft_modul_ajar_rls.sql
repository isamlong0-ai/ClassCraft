-- 20261118000000 - classcraft modul_ajar rls
drop policy if exists write_modul on public.modul_ajar;
create policy write_modul on public.modul_ajar for all to authenticated using (guru_id = auth.uid() or public.is_admin()) with check (guru_id = auth.uid() or public.is_admin());
