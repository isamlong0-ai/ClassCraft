# Restore ClassCraft SMP (Backup ke Proyek Baru)

Backup berisi **semua tabel** (JSON) dan daftar **Auth user** (`authUsers`). Password **tidak** ikut tersimpan karena disimpan terenkripsi di Supabase Auth dan tidak dapat dibaca.

## Isi file backup (.json)
- `tables.<nama_tabel>[]` – isi setiap tabel (sekolah, guru, rombel, siswa, anggota_rombel, modul_ajar, jurnal_mengajar, presensi, paket_soal_butir, bank_soal, paket_soal).
- `files[]` – isi bucket **sekolah-assets** (KOP/TTD) sebagai base64.
- `authUsers[]` – daftar user (username, role, email, dsb) yang harus dibuat ulang sebagai Auth user.
- `authRestoreNote` – ringkasan prosedur.

## Prosedur restore ke proyek baru
1. **Buat Auth user** di Dashboard Supabase (Authentication → Users → Add User) untuk setiap `authUsers[]`.
   - Email: `<username>@classcraft.local` (lowercase).
   - Password: sementara (akan di-reset nanti).
2. **Isi tabel `sekolah`** dahulu (restore melakukannya otomatis).
3. **Jalankan restore** dari halaman Admin → Backup & Restore:
   - Upload file backup, masukkan password admin, pilih "Pilih File & Restore".
   - Tabel `guru` di-restore dengan `upsert`; jika Auth user belum ada, baris guru tersebut akan gagal (FK error) — artinya langkah 1 harus dikerjakan dahulu.
4. **Verifikasi**:
   - Setiap guru bisa login (reset password lewat Dashboard atau fitur Lupa Password).
   - Profil, data siswa, presensi, jurnal, bank soal, paket soal kembali utuh.
5. **KOP/TTD** tersimpan di bucket **sekolah-assets**; backup ikut menyertakan objek storage (base64) dan restore akan meng-upload ulang otomatis.

## Catatan
- Restore **menghapus & menimpa** seluruh data di proyek tujuan. Gunakan pada proyek kosong atau cadangan.
- Auth user untuk role **admin** juga harus dibuat ulang (atau gunakan seed untuk membuat akun admin default: lihat `supabase/schema.sql` bagian seed).
- Periksa urutan: tabel `guru` di-restore dengan `upsert onConflict: 'id'`. Jika ada baris guru yang Auth-nya tidak ada, akan dilaporkan di alert; perbaiki dengan langkah 1.