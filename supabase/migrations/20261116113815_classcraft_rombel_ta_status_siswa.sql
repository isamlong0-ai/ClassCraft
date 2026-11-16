-- =============================================================
-- 20261116113815 - classcraft_rombel_ta_status_siswa
-- Tahap 1 pengelolaan siswa/rombel antar tahun ajaran. Idempotent.
--   1) rombel: rapikan tingkat dari nama, backfill tahun_ajaran,
--      jadikan NOT NULL, unique (nama, tahun_ajaran).
--   2) siswa: tambah status/tanggal_keluar/keterangan, rombel_id
--      boleh NULL, unique(nisn) global, index status.
-- =============================================================

-- 1a. Rapikan tingkat dari nama (mis. '8-A' -> 'Kelas 8')
update public.rombel
   set tingkat = 'Kelas ' || substring(nama from '^([789])')
 where substring(nama from '^([789])') is not null
   and tingkat is distinct from ('Kelas ' || substring(nama from '^([789])'));

-- 1b. Backfill tahun_ajaran dari profil sekolah
update public.rombel
   set tahun_ajaran = coalesce(
         (select s.tahun_ajaran from public.sekolah s order by s.updated_at desc nulls last limit 1),
         '2025/2026')
 where tahun_ajaran is null or tahun_ajaran = '';

alter table public.rombel alter column tahun_ajaran set not null;

-- 1c. unique (nama, tahun_ajaran) menggantikan unique(nama) global
alter table public.rombel drop constraint if exists rombel_nama_key;
do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.rombel'::regclass and conname = 'rombel_nama_ta_key'
    ) then
        alter table public.rombel add constraint rombel_nama_ta_key unique (nama, tahun_ajaran);
    end if;
end $$;

-- 2a. Kolom status siswa
alter table public.siswa add column if not exists status text not null default 'aktif';
alter table public.siswa add column if not exists tanggal_keluar date;
alter table public.siswa add column if not exists keterangan text default '';

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.siswa'::regclass and conname = 'siswa_status_check'
    ) then
        alter table public.siswa add constraint siswa_status_check
            check (status in ('aktif', 'lulus', 'pindah', 'berhenti'));
    end if;
end $$;

-- 2b. rombel_id boleh NULL (siswa lulus/pindah/berhenti tidak lagi di kelas)
alter table public.siswa alter column rombel_id drop not null;

-- 2c. NISN unik global (satu identitas siswa = satu baris)
alter table public.siswa drop constraint if exists siswa_rombel_id_nisn_key;
do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.siswa'::regclass and conname = 'siswa_nisn_key'
    ) then
        alter table public.siswa add constraint siswa_nisn_key unique (nisn);
    end if;
end $$;

create index if not exists idx_siswa_status on public.siswa(status);
