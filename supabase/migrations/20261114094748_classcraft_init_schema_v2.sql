-- =============================================================
-- 20261114094748 - classcraft_init_schema_v2
-- Skema awal ClassCraft SMP (versi awal: kredensial di tabel guru).
-- Catatan: migrasi berikutnya memindahkan kredensial ke Supabase Auth
-- dan mengeraskan RLS. Urutan migrasi menghasilkan skema final yang aman.
-- =============================================================

create extension if not exists pgcrypto with schema extensions;

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

create table if not exists public.guru (
    id            uuid primary key default gen_random_uuid(),
    username      text unique not null,
    password_hash text not null,
    role          text not null default 'guru' check (role in ('admin', 'guru')),
    nama          text not null,
    mapel         text default '',
    pangkat       text default '-',
    gol           text default '-',
    aktif         boolean not null default true,
    created_at    timestamptz not null default now()
);

create table if not exists public.rombel (
    id           uuid primary key default gen_random_uuid(),
    tingkat      text not null,
    nama         text unique not null,
    wali_id      uuid references public.guru(id) on delete set null,
    tahun_ajaran text,
    created_at   timestamptz not null default now()
);

create table if not exists public.siswa (
    id         uuid primary key default gen_random_uuid(),
    rombel_id  uuid not null references public.rombel(id) on delete cascade,
    nisn       text not null,
    nipd       text default '-',
    nama       text not null,
    jk         text not null default 'L' check (jk in ('L', 'P')),
    created_at timestamptz not null default now(),
    unique (rombel_id, nisn)
);

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

create index if not exists idx_guru_role        on public.guru(role);
create index if not exists idx_rombel_wali      on public.rombel(wali_id);
create index if not exists idx_siswa_rombel     on public.siswa(rombel_id);
create index if not exists idx_modul_ajar_guru  on public.modul_ajar(guru_id);

create or replace function public.login_guru(p_username text, p_password text)
returns table (id uuid, username text, role text, nama text, mapel text, pangkat text, gol text)
language sql security definer set search_path = public, extensions
as $fn$
    select g.id, g.username, g.role, g.nama, g.mapel, g.pangkat, g.gol
    from public.guru g
    where g.username = p_username
      and g.aktif = true
      and g.password_hash = crypt(p_password, g.password_hash);
$fn$;

create or replace function public.set_guru_password(p_guru_id uuid, p_password text)
returns void language sql security definer set search_path = public, extensions
as $fn$
    update public.guru set password_hash = crypt(p_password, gen_salt('bf')) where id = p_guru_id;
$fn$;

create or replace function public.create_guru(
    p_username text, p_password text, p_role text default 'guru',
    p_nama text default '', p_mapel text default '', p_pangkat text default '-', p_gol text default '-'
)
returns table (id uuid, username text, role text, nama text, mapel text, pangkat text, gol text)
language plpgsql security definer set search_path = public, extensions
as $fn$
begin
    return query
    insert into public.guru (username, password_hash, role, nama, mapel, pangkat, gol)
    values (p_username, crypt(p_password, gen_salt('bf')), coalesce(p_role, 'guru'), p_nama,
            coalesce(p_mapel, ''), coalesce(p_pangkat, '-'), coalesce(p_gol, '-'))
    returning guru.id, guru.username, guru.role, guru.nama, guru.mapel, guru.pangkat, guru.gol;
end $fn$;

create or replace function public.reset_guru_password(p_username text, p_password text)
returns void language sql security definer set search_path = public, extensions
as $fn$
    update public.guru set password_hash = crypt(p_password, gen_salt('bf')) where username = p_username;
$fn$;

create or replace function public.change_guru_password(p_username text, p_old text, p_new text)
returns boolean language plpgsql security definer set search_path = public, extensions
as $fn$
begin
    if not exists (
        select 1 from public.guru where username = p_username and password_hash = crypt(p_old, password_hash)
    ) then
        return false;
    end if;
    update public.guru set password_hash = crypt(p_new, gen_salt('bf')) where username = p_username;
    return true;
end $fn$;

alter table public.sekolah    enable row level security;
alter table public.guru       enable row level security;
alter table public.rombel     enable row level security;
alter table public.siswa      enable row level security;
alter table public.modul_ajar enable row level security;

do $ddl$
declare t text;
begin
    foreach t in array array['sekolah', 'guru', 'rombel', 'siswa', 'modul_ajar'] loop
        execute format('drop policy if exists "demo_all_%1$s" on public.%1$s;', t);
        execute format('create policy "demo_all_%1$s" on public.%1$s for all to anon, authenticated using (true) with check (true);', t);
    end loop;
end $ddl$;

insert into public.sekolah (nama, npsn, kepsek, nip_kepsek, tahun_ajaran, semester)
select 'SMP Negeri 1 Indonesia', '10203040', 'Dr. H. Ahmad Dahlan M.Pd', '196805121992031002', '2025/2026', 'Ganjil'
where not exists (select 1 from public.sekolah);

insert into public.guru (username, password_hash, role, nama, mapel, pangkat, gol)
select 'admin', crypt('admin123', gen_salt('bf')), 'admin', 'Administrator Sekolah', 'Sistem', '-', '-'
where not exists (select 1 from public.guru where username = 'admin');

insert into public.guru (username, password_hash, role, nama, mapel, pangkat, gol)
select '198001012005011001', crypt('guru123', gen_salt('bf')), 'guru', 'Budi Santoso S.Pd', 'Pendidikan Pancasila', 'Pembina', 'IV/a'
where not exists (select 1 from public.guru where username = '198001012005011001');

insert into public.rombel (tingkat, nama, wali_id, tahun_ajaran)
select 'Kelas 7', '7-A', (select id from public.guru where username = '198001012005011001'), '2025/2026'
where not exists (select 1 from public.rombel where nama = '7-A');

insert into public.siswa (rombel_id, nisn, nipd, nama, jk)
select (select id from public.rombel where nama = '7-A'), '0081234561', '232407001', 'Ahmad Dahlan', 'L'
where not exists (select 1 from public.siswa where nisn = '0081234561');

insert into public.siswa (rombel_id, nisn, nipd, nama, jk)
select (select id from public.rombel where nama = '7-A'), '0081234562', '232407002', 'Siti Walidah', 'P'
where not exists (select 1 from public.siswa where nisn = '0081234562');
