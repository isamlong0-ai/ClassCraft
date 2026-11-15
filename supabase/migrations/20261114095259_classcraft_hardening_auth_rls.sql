-- =============================================================
-- 20261114095259 - classcraft_hardening_auth_rls
-- Pindahkan kredensial ke Supabase Auth, buat RPC admin baru,
-- dan terapkan RLS ketat (baca: authenticated; tulis: admin).
-- =============================================================

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public, auth
as $fn$
  select exists (
    select 1 from public.guru g
    where g.id = auth.uid() and g.role = 'admin' and g.aktif = true
  );
$fn$;

do $mig$
declare r record; v_email text;
begin
  for r in select * from public.guru loop
    if not exists (select 1 from auth.users where id = r.id) then
      v_email := lower(r.username) || '@classcraft.local';
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous
      ) values (
        '00000000-0000-0000-0000-000000000000', r.id, 'authenticated', 'authenticated',
        v_email, r.password_hash, now(), now(), now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('username', r.username, 'nama', r.nama), false, false
      );
      insert into auth.identities (
        provider_id, user_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at, id
      ) values (
        r.id::text, r.id,
        jsonb_build_object('sub', r.id::text, 'email', v_email, 'email_verified', true),
        'email', now(), now(), now(), gen_random_uuid()
      );
    end if;
  end loop;
end $mig$;

alter table public.guru drop constraint if exists guru_id_auth_fkey;
alter table public.guru add constraint guru_id_auth_fkey
  foreign key (id) references auth.users(id) on delete cascade;

drop function if exists public.login_guru(text, text);
drop function if exists public.set_guru_password(uuid, text);
drop function if exists public.create_guru(text, text, text, text, text, text, text);
drop function if exists public.reset_guru_password(text, text);
drop function if exists public.change_guru_password(text, text, text);

create or replace function public.admin_create_guru(
  p_username text, p_password text, p_role text default 'guru',
  p_nama text default '', p_mapel text default '', p_pangkat text default '-', p_gol text default '-'
)
returns table (id uuid, username text, role text, nama text, mapel text, pangkat text, gol text)
language plpgsql security definer set search_path = public, auth, extensions
as $fn$
declare v_id uuid; v_email text;
begin
  if not public.is_admin() then raise exception 'Akses ditolak: khusus admin'; end if;
  v_id := gen_random_uuid();
  v_email := lower(p_username) || '@classcraft.local';
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    v_email, crypt(p_password, gen_salt('bf')), now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('username', p_username, 'nama', p_nama), false, false
  );
  insert into auth.identities (
    provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at, id
  ) values (
    v_id::text, v_id,
    jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true),
    'email', now(), now(), now(), gen_random_uuid()
  );
  return query
  insert into public.guru (id, username, role, nama, mapel, pangkat, gol)
  values (v_id, p_username, coalesce(p_role, 'guru'), p_nama,
          coalesce(p_mapel, ''), coalesce(p_pangkat, '-'), coalesce(p_gol, '-'))
  returning guru.id, guru.username, guru.role, guru.nama, guru.mapel, guru.pangkat, guru.gol;
end $fn$;

create or replace function public.admin_reset_guru_password(p_username text, p_password text)
returns void language plpgsql security definer set search_path = public, auth, extensions
as $fn$
begin
  if not public.is_admin() then raise exception 'Akses ditolak: khusus admin'; end if;
  update auth.users u
     set encrypted_password = crypt(p_password, gen_salt('bf')), updated_at = now()
    from public.guru g
   where g.id = u.id and g.username = p_username;
end $fn$;

revoke all on function public.admin_create_guru(text, text, text, text, text, text, text) from anon, public;
revoke all on function public.admin_reset_guru_password(text, text) from anon, public;
grant execute on function public.admin_create_guru(text, text, text, text, text, text, text) to authenticated;
grant execute on function public.admin_reset_guru_password(text, text) to authenticated;
grant execute on function public.is_admin() to authenticated;

do $pol$
declare t text;
begin
  foreach t in array array['sekolah', 'guru', 'rombel', 'siswa', 'modul_ajar'] loop
    execute format('drop policy if exists "demo_all_%1$s" on public.%1$s;', t);
    execute format('drop policy if exists "read_%1$s" on public.%1$s;', t);
    execute format('drop policy if exists "admin_%1$s" on public.%1$s;', t);
  end loop;
end $pol$;

create policy read_sekolah    on public.sekolah    for select to authenticated using (true);
create policy read_guru       on public.guru       for select to authenticated using (true);
create policy read_rombel     on public.rombel     for select to authenticated using (true);
create policy read_siswa      on public.siswa      for select to authenticated using (true);
create policy read_modul      on public.modul_ajar for select to authenticated using (true);

create policy admin_sekolah   on public.sekolah    for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_guru      on public.guru       for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_rombel    on public.rombel     for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_siswa     on public.siswa      for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy write_modul     on public.modul_ajar for all to authenticated using (true) with check (true);
