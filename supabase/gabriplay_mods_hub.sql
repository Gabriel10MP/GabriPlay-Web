-- GabriPlay Mods Hub · catálogo público y gestión exclusiva del creador
-- Ejecutar una sola vez en Supabase SQL Editor.

create table if not exists public.gabriplay_mods (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 2 and 90),
  summary text not null check (char_length(trim(summary)) between 10 and 220),
  description text not null check (char_length(trim(description)) between 10 and 2500),
  category text not null default 'MOD',
  version_label text not null default 'No indicada',
  download_url text not null,
  tutorial_url text,
  featured boolean not null default false,
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.gabriplay_mods enable row level security;
revoke all on public.gabriplay_mods from anon, authenticated;

create or replace function public.gabriplay_mods_feed()
returns jsonb language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',m.id,'title',m.title,'summary',m.summary,'description',m.description,
    'category',m.category,'version_label',m.version_label,'download_url',m.download_url,
    'tutorial_url',m.tutorial_url,'featured',m.featured,'created_at',m.created_at,'updated_at',m.updated_at
  ) order by m.featured desc,m.updated_at desc),'[]'::jsonb)
  from public.gabriplay_mods m where m.published=true;
$$;

create or replace function public.gabriplay_mods_admin_list()
returns jsonb language sql stable security definer set search_path = ''
as $$
  select case when public.gabriplay_is_creator() then
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',m.id,'title',m.title,'summary',m.summary,'description',m.description,
      'category',m.category,'version_label',m.version_label,'download_url',m.download_url,
      'tutorial_url',m.tutorial_url,'featured',m.featured,'published',m.published,
      'created_at',m.created_at,'updated_at',m.updated_at
    ) order by m.updated_at desc) from public.gabriplay_mods m),'[]'::jsonb)
  else '[]'::jsonb end;
$$;

create or replace function public.gabriplay_mods_create(
  p_title text,p_summary text,p_description text,p_category text,p_version text,
  p_download_url text,p_tutorial_url text,p_featured boolean,p_published boolean
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare new_id uuid;
begin
  if not public.gabriplay_is_creator() then raise exception 'Solo el creador puede publicar mods.'; end if;
  if char_length(trim(coalesce(p_title,''))) not between 2 and 90 then raise exception 'El título debe tener entre 2 y 90 caracteres.'; end if;
  if char_length(trim(coalesce(p_summary,''))) not between 10 and 220 then raise exception 'El resumen debe tener entre 10 y 220 caracteres.'; end if;
  if char_length(trim(coalesce(p_description,''))) not between 10 and 2500 then raise exception 'La descripción debe tener entre 10 y 2500 caracteres.'; end if;
  if coalesce(p_download_url,'') !~ '^https://[^[:space:]]+$' then raise exception 'El enlace de descarga debe ser HTTPS.'; end if;
  if coalesce(p_tutorial_url,'')<>'' and p_tutorial_url !~ '^https://[^[:space:]]+$' then raise exception 'El enlace de guía debe ser HTTPS.'; end if;
  -- Limpia las recomendaciones anteriores que no forman parte de esta selección.
delete from public.gabriplay_mods where lower(title) in ('lspdfr','menyoo pc');

insert into public.gabriplay_mods(title,summary,description,category,version_label,download_url,tutorial_url,featured,published)
select * from (values
('VisualV','Renueva la iluminación, el clima y los colores de Los Santos.','Modificación gráfica con versiones separadas para GTA V Legacy y Enhanced. Mejora los efectos meteorológicos, la corrección de color y distintos detalles visuales. Comprueba los requisitos de la edición que tengas instalada.','GRÁFICOS','Legacy 1.0.630 · Enhanced 2.0.640','https://www.gta5-mods.com/misc/visualv','',true,true),
('NaturalVision','Un acabado visual más cinematográfico para el mundo de GTA V.','Proyecto de Razed Mods con dos ediciones: NaturalVision Evolved para GTA V Legacy y NaturalVision Enhanced para GTA V Enhanced. Revisa los requisitos y el rendimiento antes de instalarlo.','GRÁFICOS','Legacy · Enhanced','https://razedmods.com/','',true,true),
('Andre’s Map Editor','Crea escenas y composiciones personalizadas dentro del juego.','Editor de mapas actualizado que permite colocar, mover y guardar objetos y composiciones para crear escenarios propios y preparar capturas o vídeos. Revisa los requisitos de ScriptHookVDotNet y LemonUI en la página del autor.','CREATIVIDAD','Versión 3.0 · julio 2026','https://www.gta5-mods.com/scripts/andre-s-map-editor','',true,true),
('Persistence V4','Conserva tus vehículos personalizados entre sesiones.','Herramienta de persistencia para guardar la ubicación y las modificaciones de tus vehículos en el modo Historia. La ficha indica compatibilidad con Legacy y Enhanced; comprueba comentarios y requisitos actuales.','VEHÍCULO','Versión 6.0 · julio 2026','https://www.gta5-mods.com/scripts/persistence-v4-vehicle-persistence-mod','',true,true),
('Ambient FX','Mejora algunos efectos ambientales de los vehículos.','Pequeño complemento que modifica efectos de humo y partículas ambientales. Es un proyecto veterano, así que verifica su compatibilidad con la versión actual del juego antes de instalarlo.','EFECTOS','Versión 1.1.1','https://www.gta5-mods.com/scripts/ambient-fx','',true,true)
) as v(title,summary,description,category,version_label,download_url,tutorial_url,featured,published)
where not exists(select 1 from public.gabriplay_mods m where lower(m.title)=lower(v.title));
revoke all on function public.gabriplay_mods_feed() from public;
revoke all on function public.gabriplay_mods_admin_list() from public;
revoke all on function public.gabriplay_mods_create(text,text,text,text,text,text,text,boolean,boolean) from public;
revoke all on function public.gabriplay_mods_update(uuid,text,text,text,text,text,text,text,boolean,boolean) from public;
revoke all on function public.gabriplay_mods_delete(uuid) from public;
grant execute on function public.gabriplay_mods_feed() to anon,authenticated;
grant execute on function public.gabriplay_mods_admin_list() to authenticated;
grant execute on function public.gabriplay_mods_create(text,text,text,text,text,text,text,boolean,boolean) to authenticated;
grant execute on function public.gabriplay_mods_update(uuid,text,text,text,text,text,text,text,boolean,boolean) to authenticated;
grant execute on function public.gabriplay_mods_delete(uuid) to authenticated;
notify pgrst,'reload schema';
