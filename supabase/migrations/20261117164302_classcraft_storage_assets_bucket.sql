-- 20261117164302 - classcraft storage assets bucket
insert into storage.buckets (id, name, public)
values ('sekolah-assets', 'sekolah-assets', true)
on conflict (id) do nothing;

do 
begin
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='sekolah_assets_read') then
    create policy sekolah_assets_read on storage.objects for select to authenticated using (bucket_id = 'sekolah-assets');
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='sekolah_assets_insert') then
    create policy sekolah_assets_insert on storage.objects for insert to authenticated with check (bucket_id = 'sekolah-assets');
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='sekolah_assets_update') then
    create policy sekolah_assets_update on storage.objects for update to authenticated using (bucket_id = 'sekolah-assets') with check (bucket_id = 'sekolah-assets');
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='sekolah_assets_delete') then
    create policy sekolah_assets_delete on storage.objects for delete to authenticated using (bucket_id = 'sekolah-assets');
  end if;
end ;
