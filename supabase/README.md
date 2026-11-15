# Supabase — ClassCraft SMP

Folder ini adalah direktori Supabase proyek, dipakai oleh Supabase CLI dan oleh
**Supabase GitHub Integration** (Project Settings → Integrations → GitHub).

- **Project ref:** `dfmzgyxrdifzlogjxuwi`
- **Region:** `ap-southeast-1`

## Isi folder

| Berkas | Keterangan |
|---|---|
| `config.toml` | Konfigurasi proyek untuk CLI & Branching. |
| `migrations/` | Migrasi database (sumber kebenaran skema). |
| `schema.sql` | Referensi lengkap skema final (gabungan seluruh migrasi). Tidak dibaca oleh integrasi. |

## Riwayat migrasi

File di `migrations/` sengaja dibuat dengan **versi yang sama** seperti yang sudah
tercatat di `supabase_migrations.schema_migrations` pada database, sehingga repo
dan database berada pada kondisi yang selaras (tidak ada migrasi tertunda).

1. `20261114094748` — skema awal (`classcraft_init_schema_v2`)
2. `20261114094910` — index `modul_ajar(rombel_id)`
3. `20261114095259` — hardening: Supabase Auth + RLS ketat
4. `20261114095442` — perbaikan kolom token Auth (GoTrue)
5. `20261114095509` — hapus kolom `guru.password_hash`
6. `20261114095607` — cabut `is_admin()` dari `anon`
7. `20261115024215` — tabel `jurnal_mengajar`, `presensi`, `paket_soal` (+ RLS, index, trigger `updated_at`)
8. `20261115024237` — hapus policy warisan pada `jurnal_mengajar`

## Menghubungkan ke GitHub (dashboard)

1. Buka **Project Settings → Integrations**:
   `https://supabase.com/dashboard/project/dfmzgyxrdifzlogjxuwi/settings/integrations`
2. Bagian **GitHub Integration** → **Authorize GitHub** → **Authorize Supabase**.
3. Pilih repo **`isamlong0-ai/ClassCraft`**.
4. **Working directory:** `.` (folder `supabase/` ada di root repo).
5. Aktifkan opsi yang diinginkan, lalu **Enable integration**.

## Menjalankan secara lokal (opsional)

Butuh [Supabase CLI](https://supabase.com/docs/guides/cli):

```bash
supabase start                 # jalankan stack lokal
supabase db reset              # terapkan semua migrasi + seed
supabase db push --linked      # kirim migrasi ke database remote
```

> Catatan keamanan: kredensial login dikelola **Supabase Auth** dengan email
> internal `<username>@classcraft.local`. RLS: baca untuk pengguna login,
> tulis (guru/kelas/siswa/sekolah) hanya untuk admin.
