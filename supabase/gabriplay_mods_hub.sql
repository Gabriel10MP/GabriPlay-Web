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
  insert into public.gabriplay_mods(title,summary,description,category,version_label,download_url,tutorial_url,featured,published)
  values(trim(p_title),trim(p_summary),trim(p_description),left(trim(coalesce(nullif(p_category,''),'MOD')),30),
    left(trim(coalesce(nullif(p_version,''),'No indicada')),40),trim(p_download_url),
    nullif(trim(coalesce(p_tutorial_url,'')),''),coalesce(p_featured,false),coalesce(p_published,true))
  returning id into new_id;
  return new_id;
end;
$$;

create or replace function public.gabriplay_mods_update(
  p_id uuid,p_title text,p_summary text,p_description text,p_category text,p_version text,
  p_download_url text,p_tutorial_url text,p_featured boolean,p_published boolean
) returns boolean language plpgsql security definer set search_path = ''
as $$
begin
  if not public.gabriplay_is_creator() then raise exception 'Solo el creador puede editar mods.'; end if;
  if char_length(trim(coalesce(p_title,''))) not between 2 and 90 then raise exception 'El título debe tener entre 2 y 90 caracteres.'; end if;
  if char_length(trim(coalesce(p_summary,''))) not between 10 and 220 then raise exception 'El resumen debe tener entre 10 y 220 caracteres.'; end if;
  if char_length(trim(coalesce(p_description,''))) not between 10 and 2500 then raise exception 'La descripción debe tener entre 10 y 2500 caracteres.'; end if;
  if coalesce(p_download_url,'') !~ '^https://[^[:space:]]+$' then raise exception 'El enlace de descarga debe ser HTTPS.'; end if;
  if coalesce(p_tutorial_url,'')<>'' and p_tutorial_url !~ '^https://[^[:space:]]+$' then raise exception 'El enlace de guía debe ser HTTPS.'; end if;
  update public.gabriplay_mods set title=trim(p_title),summary=trim(p_summary),description=trim(p_description),
    category=left(trim(coalesce(nullif(p_category,''),'MOD')),30),
    version_label=left(trim(coalesce(nullif(p_version,''),'No indicada')),40),
    download_url=trim(p_download_url),tutorial_url=nullif(trim(coalesce(p_tutorial_url,'')),''),
    featured=coalesce(p_featured,false),published=coalesce(p_published,true),updated_at=now()
  where id=p_id;
  if not found then raise exception 'No se encuentra ese mod.'; end if;
  return true;
end;
$$;

create or replace function public.gabriplay_mods_delete(p_id uuid)
returns boolean language plpgsql security definer set search_path = ''
as $$
begin
  if not public.gabriplay_is_creator() then raise exception 'Solo el creador puede eliminar mods.'; end if;
  delete from public.gabriplay_mods where id=p_id;
  if not found then raise exception 'No se encuentra ese mod.'; end if;
  return true;
end;
$$;

insert into public.gabriplay_mods(title,summary,description,category,version_label,download_url,tutorial_url,featured,published)
select * from (values
('Script Hook V','Librería fundamental para ejecutar muchos scripts de GTA V en PC.','Script Hook V permite que numerosos scripts creados por la comunidad funcionen en la versión de PC de GTA V. Comprueba siempre la compatibilidad con la versión actual del juego y consulta las notas del desarrollador.','HERRAMIENTA','Consultar web oficial','https://www.dev-c.com/gtav/scripthookv/','',true,true),
('OpenIV','Herramienta muy conocida para explorar y gestionar archivos del juego.','OpenIV es una herramienta utilizada por la comunidad para trabajar con archivos de GTA V. Antes de modificar nada, conserva una copia de seguridad y sigue las instrucciones de cada proyecto.','HERRAMIENTA','Consultar web oficial','https://openiv.com/','',true,true),
('Menyoo PC','Menú de entrenador para experimentar en el modo historia.','Menyoo PC ofrece opciones para explorar, crear escenas y experimentar en el modo historia de GTA V. Úsalo en el modo historia y evita utilizar modificaciones en GTA Online.','MENÚ / ENTRENADOR','Consultar página del proyecto','https://www.gta5-mods.com/scripts/menyoo-pc-sp','',true,true),
('LSPDFR','Convierte GTA V en una experiencia de simulación policial.','LSPDFR añade una experiencia de policía y emergencias a GTA V para PC, con funciones y complementos creados por la comunidad. Revisa los requisitos y compatibilidad antes de instalar.','GAMEPLAY','Consultar página del proyecto','https://www.lcpdfr.com/downloads/gta5mods/g17/7792-lspd-first-response/','',true,true),
('Heap Adjuster','Complemento de compatibilidad para determinadas configuraciones con muchos mods.','Heap Adjuster puede ayudar con problemas relacionados con el límite de memoria heap en instalaciones modificadas. Sigue las instrucciones de su página y no lo instales si no lo necesitas.','UTILIDAD','Consultar página del proyecto','https://www.gta5-mods.com/tools/heapadjuster','',true,true)
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
