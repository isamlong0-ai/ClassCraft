-- =============================================================
-- 20261115024237 - classcraft_drop_legacy_jurnal_policies
-- Tabel jurnal_mengajar sebelumnya dibuat di luar sistem migrasi
-- dengan nama policy lama (read_jurnal / write_jurnal). Migrasi
-- ini menghapus policy warisan tersebut agar tidak terjadi
-- duplikasi dengan policy baru
-- (read_jurnal_mengajar / write_jurnal_mengajar).
-- Aman dijalankan pada database baru (no-op).
-- =============================================================

drop policy if exists read_jurnal  on public.jurnal_mengajar;
drop policy if exists write_jurnal on public.jurnal_mengajar;
