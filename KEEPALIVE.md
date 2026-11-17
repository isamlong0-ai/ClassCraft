# Supabase Keep-Alive (GitHub Actions)

Supabase Free-tier akan **di-pause otomatis** jika tidak ada aktivitas. Workflow `.github/workflows/supabase-keepalive.yml` memanggil RPC `keepalive()` (hanya `SELECT 1`) setiap hari sehingga proyek tetap aktif.

## Cara kerja
- RPC `public.keepalive()` mengeksekusi `select 1`; aman & tidak mengubah data.
- Dapat dipanggil oleh role **anon** (tanpa login).
- Workflow `supabase-keepalive`:
  - berjalan setiap hari (`17 03 * * *` UTC),
  - bisa di-trigger manual dari tab **Actions → Supabase Keep-Alive → Run workflow**.

## Konfigurasi (opsional)
- Jika ingin override URL/key, buat **Variables**/**Secrets** repo:
  - `SUPABASE_URL` (default: `https://dfmzgyxrdifzlogjxuwi.supabase.co`)
  - `SUPABASE_ANON_KEY` (default: publishable key yang sudah publik)

## Troubleshooting
- Jika gagal HTTP 401/403: periksa bahwa RPC `keepalive()` sudah di-apply (migration `20261117170000_classcraft_keepalive_fn.sql` atau yang lebih baru).
- Jika gagal HTTP ≠ 200: lihat `$http_code` yang ditampilkan; RPC kemungkinan belum ada atau URL salah.

## Alternatif
- Gunakan Durable Cron dari Supabase sendiri (Dashboard) atau paket Pro agar tidak auto-pause (turunkan ke Pro jika ingin selalu aktif + backup terjadwal).