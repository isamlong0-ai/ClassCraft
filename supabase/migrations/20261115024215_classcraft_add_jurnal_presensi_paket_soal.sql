-- =============================================================
-- 20261115024215 - classcraft_add_jurnal_presensi_paket_soal
-- Menyelaraskan repo dengan tabel yang sebelumnya dibuat langsung
-- di database (di luar sistem migrasi): jurnal_mengajar, presensi,
-- paket_soal. Idempotent (aman dijalankan ulang pada database yang
-- sudah memiliki tabel-tabel ini).
-- =============================================================

-- -------------------------------------------------------------
-- Tabel: jurnal_mengajar (Jurnal Mengajar Harian)
-- -------------------------------------------------------------
create table if not exists public.jurnal_mengajar (
    id                uuid primary key default gen_random_uuid(),
    guru_id           uuid not null references public.guru(id) on delete cascade,
    rombel_id         uuid not null references public.rombel(id) on delete cascade,
    mapel             text not null default '',
    tanggal           date not null default current_date,
    jam_ke            text not null default '1-2',
    tahun_ajaran      text not null default '2025/2026',
    semester          text not null default 'Ganjil' check (semester in ('Ganjil', 'Genap')),
    materi            text not null,
    kegiatan          text default '',
    kehadiran_ringkas text default '',
    catatan_kejadian  text default '-',
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now()
);

create index if not exists idx_jurnal_guru_tgl on public.jurnal_mengajar(guru_id, tanggal);
create index if not exists idx_jurnal_rombel   on public.jurnal_mengajar(rombel_id);
create index if not exists idx_jurnal_ta_sem   on public.jurnal_mengajar(tahun_ajaran, semester);

-- -------------------------------------------------------------
-- Tabel: presensi (Presensi / Absensi Siswa)
-- -------------------------------------------------------------
create table if not exists public.presensi (
    id           uuid primary key default gen_random_uuid(),
    rombel_id    uuid not null references public.rombel(id) on delete cascade,
    siswa_id     uuid not null references public.siswa(id) on delete cascade,
    guru_id      uuid references public.guru(id) on delete set null,
    mapel        text not null default '',
    tanggal      date not null default current_date,
    tahun_ajaran text not null default '2025/2026',
    semester     text not null default 'Ganjil' check (semester in ('Ganjil', 'Genap')),
    status       text not null default 'H' check (status in ('H', 'S', 'I', 'A')),
    keterangan   text default '',
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    unique (rombel_id, siswa_id, tanggal, mapel)
);

-- Kolom created_at untuk tabel yang sudah terlanjur dibuat tanpa kolom ini.
alter table public.presensi add column if not exists created_at timestamptz not null default now();

create index if not exists idx_presensi_rombel_tgl on public.presensi(rombel_id, tanggal);
create index if not exists idx_presensi_siswa      on public.presensi(siswa_id);
create index if not exists idx_presensi_ta_sem     on public.presensi(tahun_ajaran, semester);

-- -------------------------------------------------------------
-- Tabel: paket_soal (Bank Soal & Asesmen)
-- -------------------------------------------------------------
create table if not exists public.paket_soal (
    id            uuid primary key default gen_random_uuid(),
    guru_id       uuid not null references public.guru(id) on delete cascade,
    tahun_ajaran  text not null default '2025/2026',
    semester      text not null default 'Ganjil' check (semester in ('Ganjil', 'Genap')),
    jenis_asesmen text not null default 'Sumatif Lingkup Materi',
    tingkat       text not null default 'Kelas 7',
    mapel         text not null default '',
    tanggal_ujian date default current_date,
    alokasi_waktu text not null default '90 Menit',
    daftar_soal   jsonb not null default '[]'::jsonb,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

create index if not exists idx_paket_soal_guru   on public.paket_soal(guru_id);
create index if not exists idx_paket_soal_ta_sem on public.paket_soal(tahun_ajaran, semester);

-- -------------------------------------------------------------
-- Trigger updated_at otomatis
-- -------------------------------------------------------------
create or replace function public.cc_set_updated_at()
returns trigger language plpgsql
as $fn$
begin
    new.updated_at = now();
    return new;
end $fn$;

do $trg$
declare t text;
begin
    foreach t in array array['jurnal_mengajar', 'presensi', 'paket_soal'] loop
        execute format('drop trigger if exists trg_%1$s_updated on public.%1$s;', t);
        execute format('create trigger trg_%1$s_updated before update on public.%1$s for each row execute function public.cc_set_updated_at();', t);
    end loop;
end $trg$;

-- -------------------------------------------------------------
-- RLS: baca untuk pengguna login, tulis untuk pemilik data / admin
-- -------------------------------------------------------------
alter table public.jurnal_mengajar enable row level security;
alter table public.presensi       enable row level security;
alter table public.paket_soal     enable row level security;

do $pol$
declare t text;
begin
    foreach t in array array['jurnal_mengajar', 'presensi', 'paket_soal'] loop
        execute format('drop policy if exists "read_%1$s" on public.%1$s;', t);
        execute format('drop policy if exists "write_%1$s" on public.%1$s;', t);
    end loop;
end $pol$;

create policy read_jurnal_mengajar on public.jurnal_mengajar for select to authenticated using (true);
create policy write_jurnal_mengajar on public.jurnal_mengajar for all to authenticated
    using (guru_id = auth.uid() or public.is_admin())
    with check (guru_id = auth.uid() or public.is_admin());

create policy read_presensi on public.presensi for select to authenticated using (true);
create policy write_presensi on public.presensi for all to authenticated
    using (guru_id = auth.uid() or public.is_admin())
    with check (guru_id = auth.uid() or public.is_admin());

create policy read_paket_soal on public.paket_soal for select to authenticated using (true);
create policy write_paket_soal on public.paket_soal for all to authenticated
    using (guru_id = auth.uid() or public.is_admin())
    with check (guru_id = auth.uid() or public.is_admin());
