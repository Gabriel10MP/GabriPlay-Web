-- GabriPlay: ampliación de perfiles personalizables
-- Ejecutar después de gabriplay_profiles.sql en Supabase > SQL Editor.
-- Las columnas son públicas porque la tabla profiles ya tiene lectura pública;
-- no guardes aquí correo, teléfono, dirección ni otros datos privados.

alter table public.profiles
  add column if not exists banner_url text,
  add column if not exists website_url text,
  add column if not exists youtube_url text,
  add column if not exists twitch_url text;

alter table public.profiles
  drop constraint if exists profiles_avatar_url_length,
  drop constraint if exists profiles_banner_url_length,
  drop constraint if exists profiles_website_url_length,
  drop constraint if exists profiles_youtube_url_length,
  drop constraint if exists profiles_twitch_url_length;

alter table public.profiles
  add constraint profiles_avatar_url_length check (avatar_url is null or char_length(avatar_url) <= 1000),
  add constraint profiles_banner_url_length check (banner_url is null or char_length(banner_url) <= 1000),
  add constraint profiles_website_url_length check (website_url is null or char_length(website_url) <= 500),
  add constraint profiles_youtube_url_length check (youtube_url is null or char_length(youtube_url) <= 500),
  add constraint profiles_twitch_url_length check (twitch_url is null or char_length(twitch_url) <= 500);

notify pgrst, 'reload schema';
