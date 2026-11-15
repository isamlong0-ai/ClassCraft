-- =============================================================
-- 20261115024706 - classcraft_dedup_and_fk_hardening
-- Tindak lanjut audit:
--   1) jurnal_mengajar: tambah unique (guru_id, tanggal, rombel_id,
--      jam_ke) agar tidak ada duplikat.
--   2) presensi.guru_id: jadikan NOT NULL + ON DELETE RESTRICT agar
--      tidak ada baris "yatim" (guru_id NULL) yang tak bisa diedit
--      selain oleh admin.
-- Idempotent (aman dijalankan ulang).
-- =============================================================

-- 1) Bersihkan duplikat jurnal (pertahankan baris terbaru) sebelum constraint.
delete from public.jurnal_mengajar j
using public.jurnal_mengajar k
where j.ctid < k.ctid
  and j.guru_id = k.guru_id
  and j.tanggal = k.tanggal
  and j.rombel_id = k.rombel_id
  and j.jam_ke = k.jam_ke;

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.jurnal_mengajar'::regclass
          and conname = 'jurnal_mengajar_natural_key'
    ) then
        alter table public.jurnal_mengajar
            add constraint jurnal_mengajar_natural_key
            unique (guru_id, tanggal, rombel_id, jam_ke);
    end if;
end $$;

-- 2) presensi.guru_id: NOT NULL + ON DELETE RESTRICT
delete from public.presensi where guru_id is null;

alter table public.presensi alter column guru_id set not null;

do $$
begin
    if exists (
        select 1 from pg_constraint
        where conrelid = 'public.presensi'::regclass
          and conname = 'presensi_guru_id_fkey'
          and pg_get_constraintdef(oid) ilike '%ON DELETE SET NULL%'
    ) then
        alter table public.presensi drop constraint presensi_guru_id_fkey;
    end if;

    if not exists (
        select 1 from pg_constraint
        where conrelid = 'public.presensi'::regclass
          and conname = 'presensi_guru_id_fkey'
    ) then
        alter table public.presensi
            add constraint presensi_guru_id_fkey
            foreign key (guru_id) references public.guru(id) on delete restrict;
    end if;
end $$;
