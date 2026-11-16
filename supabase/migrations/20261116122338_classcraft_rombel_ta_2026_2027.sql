-- =============================================================
-- 20261116122338 - classcraft_rombel_ta_2026_2027
-- Revisi Tahap 3: batalkan pemisahan tahun ajaran per tingkat.
-- Semua rombel (Kelas 7, 8, 9) dikembalikan ke tahun ajaran aktif
-- 2026/2027. Perubahan otomatis mengikuti ke anggota_rombel lewat
-- FK komposit ON UPDATE CASCADE. Idempotent.
-- =============================================================
update public.rombel
   set tahun_ajaran = '2026/2027'
 where tahun_ajaran <> '2026/2027';
