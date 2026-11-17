# Restore ClassCraft SMP (Backup ke Proyek Baru)

Backup berisi **semua tabel** (JSON), **file storage** (`files[]`: KOP/TTD), dan **daftar Auth user** (`authUsers[]` + `tables.guru`). Password **tidak** ikut tersimpan (tidak bisa dibaca dari Supabase Auth), sehingga restore ke proyek baru **membuat ulang Auth user** dengan password sementara acak.

## Isi file backup (.json)
- `tables.<nama_tabel>[]` – isi setiap tabel (sekolah, guru, rombel, siswa, anggota_rombel, modul_ajar, jurnal_mengajar, presensi, paket_soal_butir, bank_soal, paket_soal).
- `files[]` – isi bucket **sekolah-assets** (KOP/TTD) sebagai base64.
- `authUsers[]` – daftar user (username, role, email, dsb) sebagai referensi.

## Prosedur restore ke proyek baru
1. **Login sebagai admin** di proyek baru (akun admin harus sudah ada/dibuat terlebih dahulu).
2. Halaman Admin → **Backup & Restore** → upload file backup, masukkan password admin, klik **Pilih File & Restore**.
3. Halaman otomatis memanggil Edge Function **`restore-auth-users`** (admin-only, memakai service role) untuk:
   - membuat Auth user email `<username>@classcraft.local` **dengan id yang sama seperti di backup** (FK aman),
   - memberikan **password sementara acak** (ditampilkan di halaman),
   - melewati user yang sudah ada (tidak mengubah passwordnya).
4. Kemudian file storage di-upload ulang ke bucket `sekolah-assets`, diikuti restore data tabel.
5. **Verifikasi**: gunakan password sementara masing-masing guru untuk login pertama; guru dapat meminta reset password lewat fitur Lupa Password.

## Catatan
- Restore **menghapus & menimpa** seluruh data di proyek tujuan (kecuali user admin). Gunakan pada proyek kosong/cadangan.
- Akun admin juga diikutkan saat membuat Auth user jika belum ada — pastikan project tujuan sudah memiliki akun admin dengan username `admin` yang aktif (atau buat lewat Dashboard).
- Password sementara ditampilkan sekali di layar; tidak disimpan setelah reload.
- Jika Edge Function `restore-auth-users` belum aktif, restore **dibatalkan** sebelum menghapus data, dan akan muncul pesan — periksa apakah fungsi sudah dideploy (`KEEPALIVE.md` / Edge Functions).