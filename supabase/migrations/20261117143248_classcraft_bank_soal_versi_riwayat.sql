-- 20261117143248 - classcraft bank soal versi riwayat
alter table public.bank_soal
  add column if not exists versi int not null default 1,
  add column if not exists riwayat jsonb not null default '[]'::jsonb;
