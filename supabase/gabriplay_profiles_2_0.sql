-- GabriPlay Perfiles 2.0
-- Ejecutar en Supabase > SQL Editor.
-- Añade temas públicos y una función de solo lectura para mostrar insignias de administrador.

alter table public.profiles
  add column if not exists profile_theme text not null default 'crimson';

alter table public.profiles
  drop constraint if exists profiles_profile_theme_check;

alter table public.profiles
  add constraint profiles_profile_theme_check
  check (profile_theme in ('crimson', 'ocean', 'emerald'));

create or replace function public.is_gabriplay_admin(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.gabriplay_admins
    where user_id = target_user_id
  );
$$;

revoke all on function public.is_gabriplay_admin(uuid) from public;
grant execute on function public.is_gabriplay_admin(uuid) to anon, authenticated;

notify pgrst, 'reload schema';
