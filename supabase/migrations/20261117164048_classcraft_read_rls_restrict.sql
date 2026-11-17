-- 20261118013000 - classcraft read rls restrict
drop policy if exists read_jurnal_mengajar on public.jurnal_mengajar;
create policy read_jurnal_mengajar on public.jurnal_mengajar for select to authenticated
    using (guru_id = auth.uid() or public.is_admin());

drop policy if exists read_presensi on public.presensi;
create policy read_presensi on public.presensi for select to authenticated
    using (guru_id = auth.uid() or public.is_admin());

drop policy if exists read_bank_soal on public.bank_soal;
create policy read_bank_soal on public.bank_soal for select to authenticated
    using (guru_id = auth.uid() or public.is_admin());

drop policy if exists read_modul on public.modul_ajar;
create policy read_modul on public.modul_ajar for select to authenticated
    using (guru_id = auth.uid() or public.is_admin());

drop policy if exists read_paket_soal on public.paket_soal;
create policy read_paket_soal on public.paket_soal for select to authenticated
    using (guru_id = auth.uid() or public.is_admin());

drop policy if exists read_paket_soal_butir on public.paket_soal_butir;
create policy read_paket_soal_butir on public.paket_soal_butir for select to authenticated
    using (exists (select 1 from public.paket_soal p where p.id = paket_soal_butir.paket_id and (p.guru_id = auth.uid() or public.is_admin())));
