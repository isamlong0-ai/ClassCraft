-- =============================================================
-- 20261116114532 - classcraft_drop_siswa_rombel_id
-- Tahap 2 lanjutan: penempatan siswa kini di tabel anggota_rombel,
-- kolom tunggal siswa.rombel_id tidak lagi dipakai. Idempotent.
-- Dijalankan SETELAH anggota_rombel dibuat + di-backfill dan aplikasi
-- sudah membaca/menulis lewat anggota_rombel.
-- =============================================================
drop index if exists public.idx_siswa_rombel;
alter table public.siswa drop column if exists rombel_id;
