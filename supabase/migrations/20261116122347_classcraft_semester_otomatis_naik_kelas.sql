-- =============================================================
-- 20261116122347 - classcraft_semester_otomatis_naik_kelas
-- Revisi Tahap 3: semester ditentukan otomatis dari tanggal.
--   6 bulan awal tahun (Jan-Jun)  -> 'Genap'
--   6 bulan berikutnya (Jul-Des)  -> 'Ganjil'
-- Berlaku pada cabang p_aktifkan di admin_naik_kelas.
-- =============================================================
create or replace function public.admin_naik_kelas(
    p_dari_ta      text,
    p_ke_ta        text,
    p_pengecualian jsonb default '{}'::jsonb,
    p_aktifkan     boolean default true
)
returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
    r record;
    v_aksi text;
    v_default text;
    v_num int;
    v_suffix text;
    v_target_nama text;
    v_target_tingkat text;
    v_target_rombel uuid;
    v_today date := current_date;
    v_semester text := case when extract(month from current_date) <= 6 then 'Genap' else 'Ganjil' end;
    v_naik int := 0; v_tinggal int := 0; v_lulus int := 0; v_pindah int := 0; v_berhenti int := 0;
begin
    if not public.is_admin() then raise exception 'Akses ditolak: khusus admin'; end if;
    if coalesce(p_dari_ta, '') = '' or coalesce(p_ke_ta, '') = '' then
        raise exception 'Tahun ajaran asal dan tujuan wajib diisi';
    end if;
    if p_dari_ta = p_ke_ta then
        raise exception 'Tahun ajaran asal dan tujuan harus berbeda';
    end if;

    for r in
        select a.id as anggota_id, a.siswa_id, rm.nama as nama, rm.tingkat as tingkat
          from public.anggota_rombel a
          join public.rombel rm on rm.id = a.rombel_id
          join public.siswa s on s.id = a.siswa_id
         where a.tahun_ajaran = p_dari_ta
           and s.status = 'aktif'
    loop
        v_default := case when r.tingkat = 'Kelas 9' then 'lulus' else 'naik' end;
        v_aksi := coalesce(nullif(p_pengecualian ->> r.siswa_id::text, ''), v_default);

        -- tutup penempatan tahun ajaran asal
        update public.anggota_rombel set tanggal_keluar = v_today where id = r.anggota_id;

        if v_aksi = 'lulus' then
            update public.siswa set status = 'lulus',   tanggal_keluar = v_today where id = r.siswa_id;
            v_lulus := v_lulus + 1;
        elsif v_aksi = 'pindah' then
            update public.siswa set status = 'pindah',  tanggal_keluar = v_today where id = r.siswa_id;
            v_pindah := v_pindah + 1;
        elsif v_aksi = 'berhenti' then
            update public.siswa set status = 'berhenti', tanggal_keluar = v_today where id = r.siswa_id;
            v_berhenti := v_berhenti + 1;
        else
            if v_aksi = 'tinggal' then
                v_target_nama := r.nama;
                v_target_tingkat := r.tingkat;
                v_tinggal := v_tinggal + 1;
            else
                v_num := nullif(substring(r.nama from '^[0-9]+'), '')::int;
                v_suffix := substring(r.nama from '^[0-9]+(.*)$');
                if v_num is not null then
                    v_target_nama := (v_num + 1)::text || coalesce(v_suffix, '');
                    v_target_tingkat := 'Kelas ' || (v_num + 1)::text;
                else
                    v_target_nama := r.nama;
                    v_target_tingkat := r.tingkat;
                end if;
                v_naik := v_naik + 1;
            end if;

            select id into v_target_rombel
              from public.rombel
             where nama = v_target_nama and tahun_ajaran = p_ke_ta
             limit 1;
            if v_target_rombel is null then
                insert into public.rombel (tingkat, nama, tahun_ajaran)
                values (v_target_tingkat, v_target_nama, p_ke_ta)
                returning id into v_target_rombel;
            end if;

            insert into public.anggota_rombel (siswa_id, rombel_id, tahun_ajaran, tanggal_masuk)
            values (r.siswa_id, v_target_rombel, p_ke_ta, v_today)
            on conflict (siswa_id, tahun_ajaran)
            do update set rombel_id = excluded.rombel_id, tanggal_keluar = null;
        end if;
    end loop;

    if p_aktifkan then
        update public.sekolah
           set tahun_ajaran = p_ke_ta, semester = v_semester, updated_at = now()
         where id is not null;
    end if;

    return jsonb_build_object(
        'naik', v_naik, 'tinggal', v_tinggal, 'lulus', v_lulus,
        'pindah', v_pindah, 'berhenti', v_berhenti, 'semester', v_semester
    );
end $$;
