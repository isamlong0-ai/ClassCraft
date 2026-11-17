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
-- Tabel: siswa (identitas; penempatan kelas ada di anggota_rombel)
-- -------------------------------------------------------------
create table if not exists public.siswa (
    id             uuid primary key default gen_random_uuid(),
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
-- Tabel: anggota_rombel (riwayat penempatan siswa per rombel per TA)
-- Satu siswa = satu penempatan per tahun ajaran.
-- -------------------------------------------------------------
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

-- -------------------------------------------------------------
-- Tabel: modul_ajar (hasil generator ATP / RPP yang disimpan)
-- -------------------------------------------------------------
create table if not exists public.modul_ajar (
    id         uuid primary key default gen_random_uuid(),
    guru_id    uuid references public.guru(id) on delete set null,
    rombel_id  uuid references public.rombel(id) on delete set null,
    mapel      text,
    tingkat    text,
    semester   text,
    model      text,
    tahun_ajaran text,
    konten     jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
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
-- daftar_soal (jsonb) = cache/snapshot untuk butir tanpa butir_id (legacy/inline).
--   Butir dengan butir_id direferensikan lewat paket_soal_butir -> bank_soal.
--   final dipakai dokumen via snapshot (beku); draft direkonsiliasi otomatis.
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
    kode_paket    text,
    acak_soal     boolean not null default false,
    acak_opsi     boolean not null default false,
    komposisi     jsonb not null default '{}'::jsonb,
    status        text not null default 'draft' check (status in ('draft','final')),
    snapshot      jsonb,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

-- -------------------------------------------------------------
-- Tabel: bank_soal (butir soal reusable)
-- -------------------------------------------------------------
create table if not exists public.bank_soal (
    id                 uuid primary key default gen_random_uuid(),
    guru_id            uuid not null references public.guru(id) on delete cascade,
    mapel              text not null default '',
    tingkat            text not null default 'Kelas 7',
    elemen             text default '',
    tp                 text default '',
    indikator          text default '',
    bentuk             text not null default 'PG' check (bentuk in ('PG','URAIAN')),
    level_kognitif     text default 'L1 (LotS - Pengetahuan/Pemahaman)',
    tingkat_kesulitan  text not null default 'menengah' check (tingkat_kesulitan in ('mudah','menengah','sulit')),
    stimulus           text default '',
    pertanyaan         text not null default '',
    opsi_a             text default '',
    opsi_b             text default '',
    opsi_c             text default '',
    opsi_d             text default '',
    kunci              text default '',
    skor               int not null default 1,
    tags               text[] not null default '{}',
    sumber             text not null default 'manual' check (sumber in ('manual','otomatis')),
    status             text not null default 'draft' check (status in ('draft','validasi')),
    tahun_ajaran       text not null default '2025/2026',
    semester           text not null default 'Ganjil' check (semester in ('Ganjil','Genap')),
    versi              int not null default 1,
    riwayat            jsonb not null default '[]'::jsonb,
    created_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now()
);

-- -------------------------------------------------------------
-- Tabel: paket_soal_butir (pivot paket <-> butir bank)
-- -------------------------------------------------------------
create table if not exists public.paket_soal_butir (
    id            uuid primary key default gen_random_uuid(),
    paket_id      uuid not null references public.paket_soal(id) on delete cascade,
    butir_id      uuid not null references public.bank_soal(id) on delete restrict,
    urutan        int not null default 0,
    skor_override int,
    created_at    timestamptz not null default now(),
    unique (paket_id, butir_id)
);

-- -------------------------------------------------------------
-- Index bantu
-- -------------------------------------------------------------
create index if not exists idx_guru_role         on public.guru(role);
create index if not exists idx_rombel_wali       on public.rombel(wali_id);
create index if not exists idx_siswa_status      on public.siswa(status);
create index if not exists idx_anggota_rombel_rombel on public.anggota_rombel(rombel_id);
create index if not exists idx_anggota_rombel_ta     on public.anggota_rombel(tahun_ajaran);
create index if not exists idx_modul_ajar_guru   on public.modul_ajar(guru_id);
create index if not exists idx_modul_ajar_rombel on public.modul_ajar(rombel_id);

create index if not exists idx_jurnal_guru_tgl     on public.jurnal_mengajar(guru_id, tanggal);
create index if not exists idx_jurnal_rombel       on public.jurnal_mengajar(rombel_id);
create index if not exists idx_jurnal_ta_sem       on public.jurnal_mengajar(tahun_ajaran, semester);
create index if not exists idx_presensi_rombel_tgl on public.presensi(rombel_id, tanggal);
create index if not exists idx_presensi_guru        on public.presensi(guru_id);
create index if not exists idx_presensi_siswa      on public.presensi(siswa_id);
create index if not exists idx_presensi_ta_sem     on public.presensi(tahun_ajaran, semester);
create index if not exists idx_paket_soal_guru     on public.paket_soal(guru_id);
create index if not exists idx_paket_soal_ta_sem   on public.paket_soal(tahun_ajaran, semester);
create index if not exists idx_bank_soal_guru_mapel   on public.bank_soal(guru_id, mapel);
create index if not exists idx_bank_soal_tingkat       on public.bank_soal(tingkat);
create index if not exists idx_bank_soal_ta_sem        on public.bank_soal(tahun_ajaran, semester);
create index if not exists idx_paket_soal_butir_paket  on public.paket_soal_butir(paket_id);
create index if not exists idx_paket_soal_butir_butir  on public.paket_soal_butir(butir_id);
create index if not exists idx_modul_ajar_ta          on public.modul_ajar(tahun_ajaran, semester);

-- Hubungkan profil guru ke user Auth
alter table public.guru drop constraint if exists guru_id_auth_fkey;
alter table public.guru add constraint guru_id_auth_fkey
    foreign key (id) references auth.users(id) on delete cascade;

-- Jamin konsistensi tahun ajaran penempatan dengan rombelnya (FK komposit).
-- ON UPDATE CASCADE: mengubah TA rombel otomatis mengikuti penempatan.
alter table public.rombel drop constraint if exists rombel_id_ta_key;
alter table public.rombel add constraint rombel_id_ta_key unique (id, tahun_ajaran);

alter table public.anggota_rombel drop constraint if exists anggota_rombel_rombel_id_fkey;
alter table public.anggota_rombel drop constraint if exists anggota_rombel_rombel_ta_fkey;
alter table public.anggota_rombel add constraint anggota_rombel_rombel_ta_fkey
    foreign key (rombel_id, tahun_ajaran)
    references public.rombel(id, tahun_ajaran)
    on update cascade on delete restrict;

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

-- -------------------------------------------------------------
-- RPC admin: kenaikan kelas massal + pengecualian
-- Default: tingkat+1 (mis. 7-A -> 8-A); Kelas 9 -> lulus.
-- Pengecualian per siswa: naik/tinggal/lulus/pindah/berhenti.
-- -------------------------------------------------------------
create or replace function public.admin_naik_kelas(
    p_dari_ta      text,
    p_ke_ta        text,
    p_pengecualian jsonb default '{}'::jsonb,
    p_aktifkan     boolean default true
)
returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
    r record;
    v_aksi text;
    v_default text;
    v_num int;
    v_suffix text;
    v_target_nama text;
    v_target_tingkat text;
    v_target_rombel uuid;
    v_today date := current_date;
    -- Semester otomatis: 6 bulan awal tahun (Jan-Jun) Genap, sisanya (Jul-Des) Ganjil.
    v_semester text := case when extract(month from current_date) <= 6 then 'Genap' else 'Ganjil' end;
    v_naik int := 0; v_tinggal int := 0; v_lulus int := 0; v_pindah int := 0; v_berhenti int := 0;
begin
    if not public.is_admin() then raise exception 'Akses ditolak: khusus admin'; end if;
    if coalesce(p_dari_ta, '') = '' or coalesce(p_ke_ta, '') = '' then
        raise exception 'Tahun ajaran asal dan tujuan wajib diisi';
    end if;
    if p_dari_ta = p_ke_ta then
        raise exception 'Tahun ajaran asal dan tujuan harus berbeda';
    end if;

    for r in
        select a.id as anggota_id, a.siswa_id, rm.nama as nama, rm.tingkat as tingkat
          from public.anggota_rombel a
          join public.rombel rm on rm.id = a.rombel_id
          join public.siswa s on s.id = a.siswa_id
         where a.tahun_ajaran = p_dari_ta
           and s.status = 'aktif'
    loop
        v_default := case when r.tingkat = 'Kelas 9' then 'lulus' else 'naik' end;
        v_aksi := coalesce(nullif(p_pengecualian ->> r.siswa_id::text, ''), v_default);

        -- tutup penempatan tahun ajaran asal
        update public.anggota_rombel set tanggal_keluar = v_today where id = r.anggota_id;

        if v_aksi = 'lulus' then
            update public.siswa set status = 'lulus',   tanggal_keluar = v_today where id = r.siswa_id;
            v_lulus := v_lulus + 1;
        elsif v_aksi = 'pindah' then
            update public.siswa set status = 'pindah',  tanggal_keluar = v_today where id = r.siswa_id;
            v_pindah := v_pindah + 1;
        elsif v_aksi = 'berhenti' then
            update public.siswa set status = 'berhenti', tanggal_keluar = v_today where id = r.siswa_id;
            v_berhenti := v_berhenti + 1;
        else
            if v_aksi = 'tinggal' then
                v_target_nama := r.nama;
                v_target_tingkat := r.tingkat;
                v_tinggal := v_tinggal + 1;
            else
                v_num := nullif(substring(r.nama from '^[0-9]+'), '')::int;
                v_suffix := substring(r.nama from '^[0-9]+(.*)$');
                if v_num is not null then
                    v_target_nama := (v_num + 1)::text || coalesce(v_suffix, '');
                    v_target_tingkat := 'Kelas ' || (v_num + 1)::text;
                else
                    v_target_nama := r.nama;
                    v_target_tingkat := r.tingkat;
                end if;
                v_naik := v_naik + 1;
            end if;

            select id into v_target_rombel
              from public.rombel
             where nama = v_target_nama and tahun_ajaran = p_ke_ta
             limit 1;
            if v_target_rombel is null then
                insert into public.rombel (tingkat, nama, tahun_ajaran)
                values (v_target_tingkat, v_target_nama, p_ke_ta)
                returning id into v_target_rombel;
            end if;

            insert into public.anggota_rombel (siswa_id, rombel_id, tahun_ajaran, tanggal_masuk)
            values (r.siswa_id, v_target_rombel, p_ke_ta, v_today)
            on conflict (siswa_id, tahun_ajaran)
            do update set rombel_id = excluded.rombel_id, tanggal_keluar = null;
        end if;
    end loop;

    if p_aktifkan then
        update public.sekolah
           set tahun_ajaran = p_ke_ta, semester = v_semester, updated_at = now()
         where id is not null;
    end if;

    return jsonb_build_object(
        'naik', v_naik, 'tinggal', v_tinggal, 'lulus', v_lulus,
        'pindah', v_pindah, 'berhenti', v_berhenti, 'semester', v_semester
    );
end $$;

-- -------------------------------------------------------------
-- RPC admin: hapus guru beserta akun Auth-nya
-- Tolak: admin, akun sendiri, atau guru yang punya catatan presensi.
-- -------------------------------------------------------------
create or replace function public.admin_delete_guru(p_username text)
returns void
language plpgsql security definer
set search_path = public, auth
as $$
declare
    v_id uuid;
    v_role text;
    v_presensi int;
begin
    if not public.is_admin() then raise exception 'Akses ditolak: khusus admin'; end if;

    select id, role into v_id, v_role from public.guru where username = p_username;
    if v_id is null then raise exception 'Guru dengan NIP % tidak ditemukan', p_username; end if;
    if v_id = auth.uid() then raise exception 'Tidak dapat menghapus akun yang sedang Anda gunakan.'; end if;
    if v_role = 'admin' then raise exception 'Akun admin tidak dapat dihapus.'; end if;

    select count(*) into v_presensi from public.presensi where guru_id = v_id;
    if v_presensi > 0 then
        raise exception 'Guru memiliki % catatan presensi. Tidak dapat dihapus agar data presensi siswa tetap utuh.', v_presensi;
    end if;

    -- hapus user Auth; FK guru_id_auth_fkey (on delete cascade) menghapus profil guru.
    delete from auth.users where id = v_id;
end $$;

-- Batasi hak eksekusi: hanya user yang login
revoke all on function public.admin_create_guru(text, text, text, text, text, text, text) from anon, public;
revoke all on function public.admin_reset_guru_password(text, text) from anon, public;
revoke all on function public.admin_naik_kelas(text, text, jsonb, boolean) from anon, public;
revoke all on function public.admin_delete_guru(text) from anon, public;
grant execute on function public.admin_create_guru(text, text, text, text, text, text, text) to authenticated;
grant execute on function public.admin_reset_guru_password(text, text) to authenticated;
grant execute on function public.admin_naik_kelas(text, text, jsonb, boolean) to authenticated;
grant execute on function public.admin_delete_guru(text) to authenticated;
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
    foreach t in array array['jurnal_mengajar', 'presensi', 'paket_soal', 'bank_soal', 'modul_ajar'] loop
        execute format('drop trigger if exists trg_%1$s_updated on public.%1$s;', t);
        execute format('create trigger trg_%1$s_updated before update on public.%1$s for each row execute function public.cc_set_updated_at();', t);
    end loop;
end $$;

-- =============================================================
-- Row Level Security
-- Baca: semua user yang login. Tulis: hanya admin.
-- =============================================================
alter table public.sekolah        enable row level security;
alter table public.guru           enable row level security;
alter table public.rombel         enable row level security;
alter table public.siswa          enable row level security;
alter table public.anggota_rombel enable row level security;
alter table public.modul_ajar     enable row level security;

do $$
declare t text;
begin
    foreach t in array array['sekolah', 'guru', 'rombel', 'siswa', 'anggota_rombel', 'modul_ajar'] loop
        execute format('drop policy if exists "demo_all_%1$s" on public.%1$s;', t);
        execute format('drop policy if exists "read_%1$s" on public.%1$s;', t);
        execute format('drop policy if exists "admin_%1$s" on public.%1$s;', t);
    end loop;
end $$;

create policy read_sekolah on public.sekolah    for select to authenticated using (true);
create policy read_guru    on public.guru       for select to authenticated using (true);
create policy read_rombel  on public.rombel     for select to authenticated using (true);
create policy read_siswa   on public.siswa      for select to authenticated using (true);
create policy read_modul   on public.modul_ajar for select to authenticated using (guru_id = auth.uid() or public.is_admin());
create policy read_anggota_rombel on public.anggota_rombel for select to authenticated using (true);

create policy admin_sekolah on public.sekolah    for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_guru    on public.guru       for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_rombel  on public.rombel     for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_siswa   on public.siswa      for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_anggota_rombel on public.anggota_rombel for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy write_modul   on public.modul_ajar for all to authenticated
    using (guru_id = auth.uid() or public.is_admin()) with check (guru_id = auth.uid() or public.is_admin());

-- Modul jurnal/presensi/paket soal: baca untuk user login,
-- tulis hanya oleh pemilik data (guru_id = auth.uid()) atau admin.
alter table public.jurnal_mengajar enable row level security;
alter table public.presensi       enable row level security;
alter table public.paket_soal     enable row level security;

create policy read_jurnal_mengajar on public.jurnal_mengajar for select to authenticated using (guru_id = auth.uid() or public.is_admin());
create policy write_jurnal_mengajar on public.jurnal_mengajar for all to authenticated
    using (guru_id = auth.uid() or public.is_admin()) with check (guru_id = auth.uid() or public.is_admin());

create policy read_presensi on public.presensi for select to authenticated using (guru_id = auth.uid() or public.is_admin());
create policy write_presensi on public.presensi for all to authenticated
    using (guru_id = auth.uid() or public.is_admin()) with check (guru_id = auth.uid() or public.is_admin());

create policy read_paket_soal on public.paket_soal for select to authenticated using (guru_id = auth.uid() or public.is_admin());
create policy write_paket_soal on public.paket_soal for all to authenticated
    using (guru_id = auth.uid() or public.is_admin()) with check (guru_id = auth.uid() or public.is_admin());

alter table public.bank_soal enable row level security;
alter table public.paket_soal_butir enable row level security;

create policy read_bank_soal on public.bank_soal for select to authenticated using (guru_id = auth.uid() or public.is_admin());
create policy write_bank_soal on public.bank_soal for all to authenticated
    using (guru_id = auth.uid() or public.is_admin()) with check (guru_id = auth.uid() or public.is_admin());

create policy read_paket_soal_butir on public.paket_soal_butir for select to authenticated using (exists (select 1 from public.paket_soal p where p.id = paket_soal_butir.paket_id and (p.guru_id = auth.uid() or public.is_admin())));
create policy write_paket_soal_butir on public.paket_soal_butir for all to authenticated
    using (exists (select 1 from public.paket_soal p where p.id = paket_soal_butir.paket_id and (p.guru_id = auth.uid() or public.is_admin())))
    with check (exists (select 1 from public.paket_soal p where p.id = paket_soal_butir.paket_id and (p.guru_id = auth.uid() or public.is_admin())));

-- =============================================================
-- Data awal (seed): sekolah, guru (+user Auth), rombel, siswa
-- =============================================================
insert into public.sekolah (nama, npsn, kepsek, nip_kepsek, tahun_ajaran, semester)
select 'SMP Negeri 1 Indonesia', '10203040', 'Dr. H. Ahmad Dahlan M.Pd', '196805121992031002', '2026/2027', 'Ganjil'
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
select 'Kelas 7', '7-A', (select id from public.guru where username = '198001012005011001'), '2026/2027'
where not exists (select 1 from public.rombel where nama = '7-A');

insert into public.siswa (nisn, nipd, nama, jk)
select '0081234561', '232407001', 'Ahmad Dahlan', 'L'
where not exists (select 1 from public.siswa where nisn = '0081234561');

insert into public.siswa (nisn, nipd, nama, jk)
select '0081234562', '232407002', 'Siti Walidah', 'P'
where not exists (select 1 from public.siswa where nisn = '0081234562');

-- Penempatan awal siswa seed di rombel 7-A (2026/2027).
insert into public.anggota_rombel (siswa_id, rombel_id, tahun_ajaran)
select s.id, r.id, '2026/2027'
  from public.siswa s
  cross join public.rombel r
 where s.nisn in ('0081234561', '0081234562')
   and r.nama = '7-A' and r.tahun_ajaran = '2026/2027'
   and not exists (
       select 1 from public.anggota_rombel a
        where a.siswa_id = s.id and a.tahun_ajaran = '2026/2027'
   );
