# Supabase Keep-Alive (cron eksternal + GitHub Action cadangan)

Supabase Free-tier akan **di-pause otomatis** jika tidak ada aktivitas. Pemicu **utama** dibuat sebagai **Edge Function publik** `keepalive`, yang bisa dipanggil penjadwal luar sehingga **tidak bergantung pada GitHub Actions** dan tidak terkena aturan "60 hari tanpa aktivitas repositori".

## Endpoint publik (tanpa API key)

```
https://dfmzgyxrdifzlogjxuwi.supabase.co/functions/v1/keepalive
```

- Method: POST (atau GET)
- Body: bebas (kosong/`{}`)
- Respons: `{"ok":true}` (HTTP 200)

Fungsi: `keepalive` (Edge Function, `verify_jwt: false`), hanya mengembalikan `{ok:true}`; tidak menyentuh data.

## Setup cron eksternal (disarankan, gratis)

1. Buka penyedia cron gratis, mis. **cron-job.org** (atau Cloudflare Worker cron / cronjob.io).
2. URL: `https://dfmzgyxrdifzlogjxuwi.supabase.co/functions/v1/keepalive`
3. Method: POST (atau GET).
4. Jadwal: setiap 12 jam (atau minimal tiap 1–2 hari).
5. Simpan → selesai. Tidak perlu API key/kredensial.

GitHub Actions dasarnya tidak lagi dipakai sebagai pemicu utama karena scheduled workflow GitHub dinonaktifkan setelah 60 hari tanpa commit/push; pemicu eksternal tidak bergantung pada itu.

## GitHub Action (cadangan, manual)

File `.github/workflows/supabase-keepalive.yml` dipertahankan sebagai cadangan **manual-only** (`workflow_dispatch`). Jalankan dari tab Actions jika perlu memverifikasi fungsi masih aktif.

## Verifikasi

```powershell
Invoke-WebRequest -Uri "https://dfmzgyxrdifzlogjxuwi.supabase.co/functions/v1/keepalive" -Method POST -UseBasicParsing
```

Hasil: HTTP 200, body `{"ok":true}`.

## Troubleshooting
- Periksa status function: dashboard Supabase → Edge Functions → `keepalive` → Logs.
- Jika dibalas 401/403, berarti fungsi tidak sengaja berganti `verify_jwt: true`; set ke `false` kembali atau hubungi admin.
- Jika 502/534, coba lagi dalam beberapa menit (mungkin cold start).
