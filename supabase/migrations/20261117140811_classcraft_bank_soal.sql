-- 20261117090000 - classcraft bank soal & reusable items

-- Kolom tambahan modul_ajar (simpan struktur RPP)
alter table public.modul_ajar
  add column if not exists tingkat text,
  add column if not exists tahun_ajaran text,
  add column if not exists updated_at timestamptz not null default now();

-- Tabel bank_soal (butir master)
create table if not exists public.bank_soal (
  id uuid primary key default gen_random_uuid(),
  guru_id uuid not null references public.guru(id) on delete cascade,
  mapel text not null default '',
  tingkat text not null default 'Kelas 7',
  elemen text default '',
  tp text default '',
  indikator text default '',
  bentuk text not null default 'PG' check (bentuk in ('PG','URAIAN')),
  level_kognitif text default 'L1 (LotS - Pengetahuan/Pemahaman)',
  tingkat_kesulitan text not null default 'menengah' check (tingkat_kesulitan in ('mudah','menengah','sulit')),
  stimulus text default '',
  pertanyaan text not null default '',
  opsi_a text default '',
  opsi_b text default '',
  opsi_c text default '',
  opsi_d text default '',
  kunci text default '',
  skor int not null default 1,
  tags text[] not null default '{}',
  sumber text not null default 'manual' check (sumber in ('manual','otomatis')),
  status text not null default 'draft' check (status in ('draft','validasi')),
  tahun_ajaran text not null default '2025/2026',
  semester text not null default 'Ganjil' check (semester in ('Ganjil','Genap')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Pivot paket <-> butir
create table if not exists public.paket_soal_butir (
  id uuid primary key default gen_random_uuid(),
  paket_id uuid not null references public.paket_soal(id) on delete cascade,
  butir_id uuid not null references public.bank_soal(id) on delete restrict,
  urutan int not null default 0,
  skor_override int,
  created_at timestamptz not null default now(),
  unique (paket_id, butir_id)
);

-- Kolom tambahan paket_soal
alter table public.paket_soal
  add column if not exists kode_paket text,
  add column if not exists acak_soal boolean not null default false,
  add column if not exists acak_opsi boolean not null default false,
  add column if not exists komposisi jsonb not null default '{}'::jsonb,
  add column if not exists status text not null default 'draft',
  add column if not exists snapshot jsonb;

alter table public.paket_soal
  add constraint paket_soal_status_check check (status in ('draft','final'));

-- Indexes
create index if not exists idx_bank_soal_guru_mapel on public.bank_soal(guru_id, mapel);
create index if not exists idx_bank_soal_tingkat on public.bank_soal(tingkat);
create index if not exists idx_bank_soal_ta_sem on public.bank_soal(tahun_ajaran, semester);
create index if not exists idx_paket_soal_butir_paket on public.paket_soal_butir(paket_id);
create index if not exists idx_paket_soal_butir_butir on public.paket_soal_butir(butir_id);
create index if not exists idx_modul_ajar_ta on public.modul_ajar(tahun_ajaran, semester);

-- Trigger updated_at
do $$
declare t text;
begin
  foreach t in array array['jurnal_mengajar','presensi','paket_soal','bank_soal','modul_ajar'] loop
    execute format('drop trigger if exists trg_%1$s_updated on public.%1$s;', t);
    execute format('create trigger trg_%1$s_updated before update on public.%1$s for each row execute function public.cc_set_updated_at();', t);
  end loop;
end $$;

-- RLS
alter table public.bank_soal enable row level security;
alter table public.paket_soal_butir enable row level security;

create policy read_bank_soal on public.bank_soal for select to authenticated using (true);
create policy write_bank_soal on public.bank_soal for all to authenticated
  using (guru_id = auth.uid() or public.is_admin())
  with check (guru_id = auth.uid() or public.is_admin());

create policy read_paket_soal_butir on public.paket_soal_butir for select to authenticated using (true);
create policy write_paket_soal_butir on public.paket_soal_butir for all to authenticated
  using (exists (select 1 from public.paket_soal p where p.id = paket_soal_butir.paket_id and (p.guru_id = auth.uid() or public.is_admin())))
  with check (exists (select 1 from public.paket_soal p where p.id = paket_soal_butir.paket_id and (p.guru_id = auth.uid() or public.is_admin())));