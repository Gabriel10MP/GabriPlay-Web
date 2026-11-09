-- GabriPlay: perfiles públicos de la comunidad
-- Ejecuta este archivo una sola vez en Supabase > SQL Editor.
-- No contiene claves privadas ni modifica las tablas de sugerencias existentes.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  display_name text not null,
  bio text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_length check (char_length(username) between 3 and 24),
  constraint profiles_display_name_length check (char_length(display_name) between 1 and 40),
  constraint profiles_bio_length check (char_length(bio) <= 160)
);

create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username));

alter table public.profiles enable row level security;

drop policy if exists "GabriPlay profiles are publicly readable" on public.profiles;
create policy "GabriPlay profiles are publicly readable"
  on public.profiles for select
  to anon, authenticated
  using (true);

drop policy if exists "GabriPlay users can insert their own profile" on public.profiles;
create policy "GabriPlay users can insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "GabriPlay users can update their own profile" on public.profiles;
create policy "GabriPlay users can update their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create or replace function public.gabriplay_create_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_username text;
  requested_name text;
begin
  requested_username := lower(coalesce(new.raw_user_meta_data ->> 'username', 'user_' || left(new.id::text, 8)));
  requested_name := coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), requested_username);

  insert into public.profiles (id, username, display_name)
  values (new.id, requested_username, requested_name)
  on conflict (id) do update
    set username = excluded.username,
        display_name = excluded.display_name,
        updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_gabriplay_auth_user_created on auth.users;
create trigger on_gabriplay_auth_user_created
  after insert or update of raw_user_meta_data on auth.users
  for each row execute procedure public.gabriplay_create_profile();

-- Crea perfiles para las cuentas que ya existían antes de instalar esta mejora.
insert into public.profiles (id, username, display_name)
select
  u.id,
  lower(coalesce(u.raw_user_meta_data ->> 'username', 'user_' || left(u.id::text, 8))),
  coalesce(nullif(u.raw_user_meta_data ->> 'display_name', ''), lower(coalesce(u.raw_user_meta_data ->> 'username', 'user_' || left(u.id::text, 8))))
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;

-- IMPORTANTE:
-- Revisa también las políticas RLS actuales de suggestions, suggestion_votes
-- y gabriplay_admins. El cliente solo filtra propuestas aprobadas para usuarios
-- normales, pero la protección real de propuestas pendientes/rechazadas debe
-- estar en RLS. Mantén las políticas de moderación restringidas a admins.
