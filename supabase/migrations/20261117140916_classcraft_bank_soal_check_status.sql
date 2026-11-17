-- 20261117140916 - classcraft bank soal check status
alter table public.paket_soal add constraint paket_soal_status_check check (status in ('draft','final'));
