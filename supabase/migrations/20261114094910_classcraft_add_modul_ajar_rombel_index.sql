-- =============================================================
-- 20261114094910 - classcraft_add_modul_ajar_rombel_index
-- Index bantu untuk pencarian modul ajar per rombel.
-- =============================================================

create index if not exists idx_modul_ajar_rombel on public.modul_ajar(rombel_id);
