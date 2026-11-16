-- =============================================================
-- 20261116115330 - classcraft_set_ta_rombel_per_tingkat
-- Tahap 3 (data): penetapan tahun ajaran contoh per tingkat:
--   Kelas 9 -> 2024/2025 (arsip), Kelas 8 tetap 2025/2026,
--   Kelas 7 -> 2026/2027 (berjalan).
-- Perubahan rombel.tahun_ajaran otomatis mengikuti ke anggota_rombel
-- lewat FK komposit ON UPDATE CASCADE. Idempotent.
-- =============================================================
update public.rombel set tahun_ajaran = '2024/2025'
 where tingkat = 'Kelas 9' and tahun_ajaran <> '2024/2025';

update public.rombel set tahun_ajaran = '2026/2027'
 where tingkat = 'Kelas 7' and tahun_ajaran <> '2026/2027';
