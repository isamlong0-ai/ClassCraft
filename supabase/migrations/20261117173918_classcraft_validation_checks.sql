-- 20261117173918 - classcraft validation checks
alter table public.siswa add constraint siswa_nisn_format_check
  check (nisn is null or nisn ~ '^[0-9]{10}$');

alter table public.jurnal_mengajar add constraint jurnal_mengajar_jam_ke_format_check
  check (jam_ke ~ '^[0-9]+[[:space:]]*(-[[:space:]]*[0-9]+[[:space:]]*)?$');

alter table public.jurnal_mengajar add constraint jurnal_mengajar_materi_not_empty_check
  check (length(trim(materi)) > 0);

alter table public.bank_soal add constraint bank_soal_skor_range_check
  check (skor between 1 and 100);

alter table public.paket_soal_butir add constraint paket_soal_butir_urutan_nonneg_check
  check (urutan >= 0);

alter table public.paket_soal_butir add constraint paket_soal_butir_skor_override_range_check
  check (skor_override is null or skor_override between 0 and 100);
