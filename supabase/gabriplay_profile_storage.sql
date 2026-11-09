-- GabriPlay: almacenamiento de fotos de perfil y banners
-- Ejecutar una sola vez en Supabase > SQL Editor.
-- Los archivos son públicos para que los avatares se vean sin iniciar sesión.
-- Cada usuario solo puede subir, reemplazar o borrar archivos dentro de su propia carpeta UUID.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-media',
  'profile-media',
  true,
  5242880,
  array['image/png', 'image/jpeg', 'image/webp', 'image/gif']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Profile media is publicly readable" on storage.objects;
create policy "Profile media is publicly readable"
on storage.objects for select
to public
using (bucket_id = 'profile-media');

drop policy if exists "Users upload their own profile media" on storage.objects;
create policy "Users upload their own profile media"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'profile-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users update their own profile media" on storage.objects;
create policy "Users update their own profile media"
on storage.objects for update
to authenticated
using (
  bucket_id = 'profile-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'profile-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users delete their own profile media" on storage.objects;
create policy "Users delete their own profile media"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'profile-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

