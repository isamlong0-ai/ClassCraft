/* =============================================================
 * ClassCraft SMP - Konfigurasi Supabase
 * -------------------------------------------------------------
 * Diisi dari dashboard Supabase (Project Settings > API).
 * Selama dua nilai ini kosong, aplikasi otomatis berjalan dalam
 * mode offline memakai localStorage.
 *
 * Catatan keamanan: kunci di bawah adalah kunci publik (publishable)
 * yang memang aman dipakai di sisi klien. Akses data dibatasi oleh
 * Row Level Security (RLS) di database.
 * ============================================================= */
window.CC_CONFIG = {
    SUPABASE_URL: 'https://dfmzgyxrdifzlogjxuwi.supabase.co',
    SUPABASE_ANON_KEY: 'sb_publishable_8S5NrIjfV6BRmpVblz8kzA__QD6ZGvt'
};
