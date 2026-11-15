-- =============================================================
-- 20261114095442 - classcraft_fix_auth_token_columns
-- GoTrue gagal login bila kolom token bernilai NULL. Isi dengan
-- string kosong dan pastikan admin_create_guru mengisinya juga.
-- =============================================================

update auth.users set
  confirmation_token        = coalesce(confirmation_token, ''),
  recovery_token            = coalesce(recovery_token, ''),
  email_change              = coalesce(email_change, ''),
  email_change_token_new    = coalesce(email_change_token_new, ''),
  email_change_token_current= coalesce(email_change_token_current, ''),
  phone_change              = coalesce(phone_change, ''),
  phone_change_token        = coalesce(phone_change_token, ''),
  reauthentication_token    = coalesce(reauthentication_token, '')
where email like '%@classcraft.local';

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
    raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    v_email, crypt(p_password, gen_salt('bf')), now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('username', p_username, 'nama', p_nama), false, false,
    '', '', '', ''
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
