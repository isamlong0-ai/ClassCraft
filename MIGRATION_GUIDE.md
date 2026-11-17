# Migrasi Safe ke Production — Supabase

Panduan ini adalah alternatif **tanpa upgrade paket Pro/Branching**. Digunakan setiap kali kita mengubah skema/ RLS / fungsi / trigger di production. Ikuti urutannya per dokumen ini.

## A. Sebelum apply perubahan

1. **Backup dulu, selalu**
   - Admin → Backup & Restore → klik *Unduh Backup*.
   - Pastikan `Backup terakhir` muncul di halaman backup.
   - Untuk perubahan besar, gunakan juga snapshot cadangan (cold backup) sebelum eksekusi; cron backup otomatis tetap berjalan jika sudah terpasang.

2. **Siapkan migration file**
   - Buat file baru di `supabase/migrations/<YYYYMMDDHHMMSS>_classcraft_<deskripsi>.sql`.
   - Jangan hitung sendiri timestamp seperti `20261118000000` — pakai timestamp sesungguhnya `date -u +%Y%m%d%H%M%S` atau gunakan file yang sudah dibuat.
   - Update `supabase/schema.sql` agar mencerminkan hasil akhir state (tabel, kolom, index, constraint, policy, trigger) yang **identik** dengan migration file.

3. **Review manual migration**
   - Jangan ubah tabel production tanpa sadar efek samping (delete, drop, disable RLS, broadening policy).
   - Konversi semua nama tabel berdasarkan nama sejati di database.
   - Pastikan tidak ada objek sementara yang tertinggal (tabel temp, constraint salah nama, fungsi tanpa owner jelas).

4. **Cek data existing**
   - `SELECT count(*)` untuk tabel yang dirubah; bila ada data yang melanggar constraint baru (mis. skor di luar rentang), diperbaiki sebelum apply.
   - Pertimbangkan `CHECK` constraint dipasang setelah data bersih, bukan sebaliknya.

5. **Advise production**
   - Jalankan security/performance/health advisors (MCP `get_advisors`) sebelum dan sesudah apply.
   - Abaikan advisor yang tidak relevan, tapi tangani RLS missing, noindexes, duplicate RLS policies, dan sebagainya.

## B. Apply ke production

1. Hanya gunakan tool migration terpercaya (`apply_migration`) atau CLI/MCP.
   - Jangan coba-coba migrasi langsung di production dengan SQL sembarangan (tanpa transaksi, tanpa memvalidasi efek samping, tanpa backup).

2. Satu perubahan per migration — jangan campur DDL tanpa cadangan yang jelas.

3. Setelah apply: jalankan query pengecekan (hitung baris, tipe kolom, index ada, RLS enabled) untuk memastikan migrasi benar.

4. Jika sesuatu gagal: rollback dengan restore dari backup (lihat `RESTORE.md`) — **restore menimpa seluruh data**, jadi dokumentasikan sebelum menghapus.

## C. Setelah apply

1. Buat commit memuat migration file + `supabase/schema.sql`.
2. Push ke `main`. (GitHub Actions hanya triggered saat push/PR, tidak diperlukan schedule.)
3. Verifikasi app-level: buka halaman terlibat (admin-backup, guru-soal, guru-jurnal) dan pastikan tidak ada console error.
4. Update dokumentasi jika diperlukan (`KEEPALIVE.md`, `RESTORE.md`).

## D. Catatan penting

- **Data produksi TIDAK pernah bawa data uji**. Backup/restore dikerjakan dari luar aplikasi ke proyek tujuan baru/cadangan.
- **Edge Functions** (mis. `keepalive`, `restore-auth-users`, `backup-now`) diperbarui terpisah dari migrasi database; referensi fungsi disimpan di repo jika ada, tetapi konfigurasi runtime (versi, verifyJWT) tidak ada di repo — dicatat disini bila berubah.
- Bila ingin memastikan perubahan aman sebelum ke production, siapkan draft di luar produksi (staging project terpisah, bila tersedia); jangan ubah production langsung untuk uji coba.
