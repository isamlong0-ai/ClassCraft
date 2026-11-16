-- =============================================================
-- 20261116114405 - classcraft_anggota_rombel
-- Tahap 2: tabel riwayat penempatan siswa per rombel per tahun ajaran.
-- Idempotent. Membuat tabel, backfill dari siswa.rombel_id, dan RLS.
-- =============================================================

create table if not exists public.anggota_rombel (
    id             uuid primary key default gen_random_uuid(),
    siswa_id       uuid not null references public.siswa(id)  on delete restrict,
    rombel_id      uuid not null references public.rombel(id) on delete restrict,
    tahun_ajaran   text not null,
    tanggal_masuk  date not null default current_date,
    tanggal_keluar date,
    keterangan     text default '',
    created_at     timestamptz not null default now(),
    unique (siswa_id, tahun_ajaran)
);

-- Index FK (Postgres tidak otomatis meng-index kolom FK).
-- siswa_id sudah tercakup oleh unique(siswa_id, tahun_ajaran).
create index if not exists idx_anggota_rombel_rombel on public.anggota_rombel(rombel_id);
create index if not exists idx_anggota_rombel_ta     on public.anggota_rombel(tahun_ajaran);

-- Backfill dari penempatan saat ini (siswa.rombel_id).
insert into public.anggota_rombel (siswa_id, rombel_id, tahun_ajaran, tanggal_masuk)
select s.id, s.rombel_id, r.tahun_ajaran, coalesce(s.created_at::date, current_date)
  from public.siswa s
  join public.rombel r on r.id = s.rombel_id
 where s.rombel_id is not null
on conflict (siswa_id, tahun_ajaran) do nothing;

-- RLS: baca untuk user login, tulis hanya admin.
alter table public.anggota_rombel enable row level security;

drop policy if exists read_anggota_rombel  on public.anggota_rombel;
drop policy if exists admin_anggota_rombel on public.anggota_rombel;
create policy read_anggota_rombel  on public.anggota_rombel for select to authenticated using (true);
create policy admin_anggota_rombel on public.anggota_rombel for all    to authenticated
    using (public.is_admin()) with check (public.is_admin());
