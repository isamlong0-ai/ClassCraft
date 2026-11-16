-- =============================================================
-- 20261116115205 - classcraft_anggota_rombel_ta_fk
-- Tahap 3: jamin konsistensi anggota_rombel.tahun_ajaran dengan
-- rombel.tahun_ajaran lewat FK komposit (mencegah data melenceng).
-- ON UPDATE CASCADE: mengubah TA rombel otomatis mengikuti penempatan.
-- Idempotent.
-- =============================================================

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.rombel'::regclass and conname = 'rombel_id_ta_key'
    ) then
        alter table public.rombel add constraint rombel_id_ta_key unique (id, tahun_ajaran);
    end if;
end $$;

alter table public.anggota_rombel drop constraint if exists anggota_rombel_rombel_id_fkey;

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.anggota_rombel'::regclass and conname = 'anggota_rombel_rombel_ta_fkey'
    ) then
        alter table public.anggota_rombel add constraint anggota_rombel_rombel_ta_fkey
            foreign key (rombel_id, tahun_ajaran)
            references public.rombel(id, tahun_ajaran)
            on update cascade on delete restrict;
    end if;
end $$;
