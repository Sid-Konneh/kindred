-- Kindred: let users list their own photo folder, so "Delete account" can remove their photos.
drop policy if exists "photos read own folder" on storage.objects;
create policy "photos read own folder" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
