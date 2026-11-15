-- =============================================================
-- 20261114095509 - classcraft_drop_password_hash_column
-- Kredensial kini dikelola Supabase Auth; kolom password_hash
-- pada public.guru tidak lagi dipakai.
-- =============================================================

alter table public.guru drop column if exists password_hash;
