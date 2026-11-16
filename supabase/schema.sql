-- =============================================================
-- ClassCraft SMP - Skema Database Supabase (versi aman / hardened)
-- -------------------------------------------------------------
-- Model keamanan:
--   * Kredensial login dikelola Supabase Auth (schema `auth`).
--     Username/NIP dipetakan ke email internal: <username>@classcraft.local
--   * Tabel `public.guru` menyimpan profil + peran (admin/guru).
--   * RLS: hanya pengguna yang sudah login (authenticated) bisa membaca;
--     hanya admin yang bisa menulis data guru/kelas/siswa/sekolah.
-- Jalankan file ini di Supabase SQL Editor (atau via migration).
-- =============================================================

-- pgcrypto sudah tersedia di schema `extensions` pada Supabase.
create extension if not exists pgcrypto with schema extensions;

-- -------------------------------------------------------------
-- Tabel: sekolah (profil sekolah & pengaturan akademik)
-- -------------------------------------------------------------
create table if not exists public.sekolah (
    id           uuid primary key default gen_random_uuid(),
    nama         text not null default 'SMP Negeri 1 Indonesia',
    npsn         text default '',
    kepsek       text default '',
    nip_kepsek   text default '',
    tahun_ajaran text default '2025/2026',
    semester     text default 'Ganjil' check (semester in ('Ganjil', 'Genap')),
    img_kop      text default '',
    img_ttd      text default '',
    updated_at   timestamptz not null default now()
);

-- -------------------------------------------------------------
-- Tabel: guru (profil + peran; kredensial ada di auth.users)
-- id = auth.users.id
-- -------------------------------------------------------------
create table if not exists public.guru (
    id         uuid primary key default gen_random_uuid(),
    username   text unique not null,               -- NIP atau 'admin'
    role       text not null default 'guru' check (role in ('admin', 'guru')),
    nama       text not null,
    mapel      text default '',
    pangkat    text default '-',
    gol        text default '-',
    aktif      boolean not null default true,
    created_at timestamptz not null default now()
);

-- -------------------------------------------------------------
-- Tabel: rombel (kelas / rombongan belajar)
-- -------------------------------------------------------------
create table if not exists public.rombel (
    id           uuid primary key default gen_random_uuid(),
    tingkat      text not null,
    nama         text not null,
    wali_id      uuid references public.guru(id) on delete set null,
    tahun_ajaran text not null,
    created_at   timestamptz not null default now(),
    unique (nama, tahun_ajaran)
);

-- -------------------------------------------------------------
-- Tabel: siswa
-- -------------------------------------------------------------
create table if not exists public.siswa (
    id             uuid primary key default gen_random_uuid(),
    rombel_id      uuid references public.rombel(id) on delete cascade,
    nisn           text not null unique,
    nipd           text default '-',
    nama           text not null,
    jk             text not null default 'L' check (jk in ('L', 'P')),
    status         text not null default 'aktif' check (status in ('aktif', 'lulus', 'pindah', 'berhenti')),
    tanggal_keluar date,
    keterangan     text default '',
    created_at     timestamptz not null default now()
);

-- -------------------------------------------------------------
-- Tabel: modul_ajar (hasil generator ATP / RPP yang disimpan)
-- -------------------------------------------------------------
create table if not exists public.modul_ajar (
    id         uuid primary key default gen_random_uuid(),
    guru_id    uuid references public.guru(id) on delete set null,
    rombel_id  uuid references public.rombel(id) on delete set null,
    mapel      text,
    semester   text,
    model      text,
    konten     jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

-- -------------------------------------------------------------
-- Tabel: jurnal_mengajar (jurnal mengajar harian guru)
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
    updated_at        timestamptz not null default now(),
    unique (guru_id, tanggal, rombel_id, jam_ke)
);

-- -------------------------------------------------------------
-- Tabel: presensi (presensi / absensi siswa per pertemuan)
-- -------------------------------------------------------------
create table if not exists public.presensi (
    id           uuid primary key default gen_random_uuid(),
    rombel_id    uuid not null references public.rombel(id) on delete cascade,
    siswa_id     uuid not null references public.siswa(id) on delete cascade,
    guru_id      uuid not null references public.guru(id) on delete restrict,
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

-- -------------------------------------------------------------
-- Tabel: paket_soal (bank soal & dokumen asesmen)
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

-- -------------------------------------------------------------
-- Index bantu
-- -------------------------------------------------------------
create index if not exists idx_guru_role         on public.guru(role);
create index if not exists idx_rombel_wali       on public.rombel(wali_id);
create index if not exists idx_siswa_rombel      on public.siswa(rombel_id);
create index if not exists idx_siswa_status      on public.siswa(status);
create index if not exists idx_modul_ajar_guru   on public.modul_ajar(guru_id);
create index if not exists idx_modul_ajar_rombel on public.modul_ajar(rombel_id);

create index if not exists idx_jurnal_guru_tgl     on public.jurnal_mengajar(guru_id, tanggal);
create index if not exists idx_jurnal_rombel       on public.jurnal_mengajar(rombel_id);
create index if not exists idx_jurnal_ta_sem       on public.jurnal_mengajar(tahun_ajaran, semester);
create index if not exists idx_presensi_rombel_tgl on public.presensi(rombel_id, tanggal);
create index if not exists idx_presensi_siswa      on public.presensi(siswa_id);
create index if not exists idx_presensi_ta_sem     on public.presensi(tahun_ajaran, semester);
create index if not exists idx_paket_soal_guru     on public.paket_soal(guru_id);
create index if not exists idx_paket_soal_ta_sem   on public.paket_soal(tahun_ajaran, semester);

-- Hubungkan profil guru ke user Auth
alter table public.guru drop constraint if exists guru_id_auth_fkey;
alter table public.guru add constraint guru_id_auth_fkey
    foreign key (id) references auth.users(id) on delete cascade;

-- -------------------------------------------------------------
-- Fungsi bantu: apakah user yang login berperan admin?
-- -------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public, auth
as $$
    select exists (
        select 1 from public.guru g
        where g.id = auth.uid() and g.role = 'admin' and g.aktif = true
    );
$$;

-- -------------------------------------------------------------
-- RPC admin: buat guru (sekaligus user Auth)
-- -------------------------------------------------------------
create or replace function public.admin_create_guru(
    p_username text, p_password text, p_role text default 'guru',
    p_nama text default '', p_mapel text default '', p_pangkat text default '-', p_gol text default '-'
)
returns table (id uuid, username text, role text, nama text, mapel text, pangkat text, gol text)
language plpgsql security definer
set search_path = public, auth, extensions
as $$
declare v_id uuid; v_email text;
begin
    if not public.is_admin() then raise exception 'Akses ditolak: khusus admin'; end if;
    v_id := gen_random_uuid();
    v_email := lower(p_username) || '@classcraft.local';
    insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous,
        confirmation_token, recovery_token, email_change, email_change_token_new
    ) values (
        '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
        v_email, crypt(p_password, gen_salt('bf')), now(), now(), now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('username', p_username, 'nama', p_nama), false, false,
        '', '', '', ''
    );
    insert into auth.identities (
        provider_id, user_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at, id
    ) values (
        v_id::text, v_id,
        jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true),
        'email', now(), now(), now(), gen_random_uuid()
    );
    return query
    insert into public.guru (id, username, role, nama, mapel, pangkat, gol)
    values (v_id, p_username, coalesce(p_role, 'guru'), p_nama,
            coalesce(p_mapel, ''), coalesce(p_pangkat, '-'), coalesce(p_gol, '-'))
    returning guru.id, guru.username, guru.role, guru.nama, guru.mapel, guru.pangkat, guru.gol;
end $$;

-- -------------------------------------------------------------
-- RPC admin: reset password guru (update auth.users)
-- -------------------------------------------------------------
create or replace function public.admin_reset_guru_password(p_username text, p_password text)
returns void
language plpgsql security definer
set search_path = public, auth, extensions
as $$
begin
    if not public.is_admin() then raise exception 'Akses ditolak: khusus admin'; end if;
    update auth.users u
       set encrypted_password = crypt(p_password, gen_salt('bf')), updated_at = now()
      from public.guru g
     where g.id = u.id and g.username = p_username;
end $$;

-- Batasi hak eksekusi: hanya user yang login
revoke all on function public.admin_create_guru(text, text, text, text, text, text, text) from anon, public;
revoke all on function public.admin_reset_guru_password(text, text) from anon, public;
grant execute on function public.admin_create_guru(text, text, text, text, text, text, text) to authenticated;
grant execute on function public.admin_reset_guru_password(text, text) to authenticated;
grant execute on function public.is_admin() to authenticated;

-- -------------------------------------------------------------
-- Trigger: perbarui updated_at otomatis (modul jurnal/presensi/paket soal)
-- -------------------------------------------------------------
create or replace function public.cc_set_updated_at()
returns trigger language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end $$;

do $$
declare t text;
begin
    foreach t in array array['jurnal_mengajar', 'presensi', 'paket_soal'] loop
        execute format('drop trigger if exists trg_%1$s_updated on public.%1$s;', t);
        execute format('create trigger trg_%1$s_updated before update on public.%1$s for each row execute function public.cc_set_updated_at();', t);
    end loop;
end $$;

-- =============================================================
-- Row Level Security
-- Baca: semua user yang login. Tulis: hanya admin.
-- =============================================================
alter table public.sekolah    enable row level security;
alter table public.guru       enable row level security;
alter table public.rombel     enable row level security;
alter table public.siswa      enable row level security;
alter table public.modul_ajar enable row level security;

do $$
declare t text;
begin
    foreach t in array array['sekolah', 'guru', 'rombel', 'siswa', 'modul_ajar'] loop
        execute format('drop policy if exists "demo_all_%1$s" on public.%1$s;', t);
        execute format('drop policy if exists "read_%1$s" on public.%1$s;', t);
        execute format('drop policy if exists "admin_%1$s" on public.%1$s;', t);
    end loop;
end $$;

create policy read_sekolah on public.sekolah    for select to authenticated using (true);
create policy read_guru    on public.guru       for select to authenticated using (true);
create policy read_rombel  on public.rombel     for select to authenticated using (true);
create policy read_siswa   on public.siswa      for select to authenticated using (true);
create policy read_modul   on public.modul_ajar for select to authenticated using (true);

create policy admin_sekolah on public.sekolah    for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_guru    on public.guru       for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_rombel  on public.rombel     for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_siswa   on public.siswa      for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy write_modul   on public.modul_ajar for all to authenticated using (true) with check (true);

-- Modul jurnal/presensi/paket soal: baca untuk user login,
-- tulis hanya oleh pemilik data (guru_id = auth.uid()) atau admin.
alter table public.jurnal_mengajar enable row level security;
alter table public.presensi       enable row level security;
alter table public.paket_soal     enable row level security;

create policy read_jurnal_mengajar on public.jurnal_mengajar for select to authenticated using (true);
create policy write_jurnal_mengajar on public.jurnal_mengajar for all to authenticated
    using (guru_id = auth.uid() or public.is_admin()) with check (guru_id = auth.uid() or public.is_admin());

create policy read_presensi on public.presensi for select to authenticated using (true);
create policy write_presensi on public.presensi for all to authenticated
    using (guru_id = auth.uid() or public.is_admin()) with check (guru_id = auth.uid() or public.is_admin());

create policy read_paket_soal on public.paket_soal for select to authenticated using (true);
create policy write_paket_soal on public.paket_soal for all to authenticated
    using (guru_id = auth.uid() or public.is_admin()) with check (guru_id = auth.uid() or public.is_admin());

-- =============================================================
-- Data awal (seed): sekolah, guru (+user Auth), rombel, siswa
-- =============================================================
insert into public.sekolah (nama, npsn, kepsek, nip_kepsek, tahun_ajaran, semester)
select 'SMP Negeri 1 Indonesia', '10203040', 'Dr. H. Ahmad Dahlan M.Pd', '196805121992031002', '2025/2026', 'Ganjil'
where not exists (select 1 from public.sekolah);

-- Buat user Auth + profil untuk tiap guru seed
do $$
declare r record; v_email text; v_id uuid;
begin
    for r in select * from (values
        ('admin', 'admin123', 'admin', 'Administrator Sekolah', 'Sistem', '-', '-'),
        ('198001012005011001', 'guru123', 'guru', 'Budi Santoso S.Pd', 'Pendidikan Pancasila', 'Pembina', 'IV/a')
    ) as v(username, pass, role, nama, mapel, pangkat, gol) loop
        if not exists (select 1 from public.guru where username = r.username) then
            v_id := gen_random_uuid();
            v_email := lower(r.username) || '@classcraft.local';
            insert into auth.users (
                instance_id, id, aud, role, email, encrypted_password,
                email_confirmed_at, created_at, updated_at,
                raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous,
                confirmation_token, recovery_token, email_change, email_change_token_new
            ) values (
                '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
                v_email, crypt(r.pass, gen_salt('bf')), now(), now(), now(),
                '{"provider":"email","providers":["email"]}'::jsonb,
                jsonb_build_object('username', r.username, 'nama', r.nama), false, false,
                '', '', '', ''
            );
            insert into auth.identities (
                provider_id, user_id, identity_data, provider,
                last_sign_in_at, created_at, updated_at, id
            ) values (
                v_id::text, v_id,
                jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true),
                'email', now(), now(), now(), gen_random_uuid()
            );
            insert into public.guru (id, username, role, nama, mapel, pangkat, gol)
            values (v_id, r.username, r.role, r.nama, r.mapel, r.pangkat, r.gol);
        end if;
    end loop;
end $$;

insert into public.rombel (tingkat, nama, wali_id, tahun_ajaran)
select 'Kelas 7', '7-A', (select id from public.guru where username = '198001012005011001'), '2025/2026'
where not exists (select 1 from public.rombel where nama = '7-A');

insert into public.siswa (rombel_id, nisn, nipd, nama, jk)
select (select id from public.rombel where nama = '7-A'), '0081234561', '232407001', 'Ahmad Dahlan', 'L'
where not exists (select 1 from public.siswa where nisn = '0081234561');

insert into public.siswa (rombel_id, nisn, nipd, nama, jk)
select (select id from public.rombel where nama = '7-A'), '0081234562', '232407002', 'Siti Walidah', 'P'
where not exists (select 1 from public.siswa where nisn = '0081234562');
