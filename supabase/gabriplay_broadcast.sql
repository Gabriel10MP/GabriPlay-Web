-- GabriPlay Broadcast · canal unidireccional del creador con reacciones emoji
-- Ejecutar en Supabase SQL Editor después de las migraciones anteriores.

create table if not exists public.gabriplay_broadcast_posts (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 1 and 100),
  body text not null check (char_length(trim(body)) between 1 and 5000),
  allowed_emojis text[] not null default array['🔥','❤️','👀','🎮'],
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gabriplay_broadcast_emojis_check
    check (cardinality(allowed_emojis) between 1 and 8)
);
create table if not exists public.gabriplay_broadcast_reactions (
  post_id uuid not null references public.gabriplay_broadcast_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key(post_id,user_id)
);
alter table public.gabriplay_broadcast_posts enable row level security;
alter table public.gabriplay_broadcast_reactions enable row level security;
revoke all on public.gabriplay_broadcast_posts from anon, authenticated;
revoke all on public.gabriplay_broadcast_reactions from anon, authenticated;

create or replace function public.gabriplay_broadcast_feed()
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id',p.id,'title',p.title,'body',p.body,'emojis',p.allowed_emojis,
      'created_at',p.created_at,'updated_at',p.updated_at,
      'counts',coalesce((
        select jsonb_object_agg(x.emoji,x.total)
        from (select r.emoji,count(*)::integer as total
              from public.gabriplay_broadcast_reactions r
              where r.post_id=p.id group by r.emoji) x
      ),'{}'::jsonb),
      'my_reaction',(
        select r.emoji from public.gabriplay_broadcast_reactions r
        where r.post_id=p.id and r.user_id=auth.uid()
      )
    ) order by p.created_at desc
  ),'[]'::jsonb)
  from public.gabriplay_broadcast_posts p
  where p.published=true;
$$;

create or replace function public.gabriplay_broadcast_create(
  post_title text, post_body text, reaction_emojis text[]
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare new_id uuid;
begin
  if not public.gabriplay_is_creator() then raise exception 'Solo el creador puede publicar.'; end if;
  if char_length(trim(coalesce(post_title,''))) not between 1 and 100 then raise exception 'El título debe tener entre 1 y 100 caracteres.'; end if;
  if char_length(trim(coalesce(post_body,''))) not between 1 and 5000 then raise exception 'El mensaje debe tener entre 1 y 5000 caracteres.'; end if;
  if reaction_emojis is null or cardinality(reaction_emojis) not between 1 and 8 then raise exception 'Elige entre 1 y 8 emojis.'; end if;
  if exists(select 1 from unnest(reaction_emojis) e where e is null or char_length(e)>16 or trim(e)='') then raise exception 'Hay un emoji no válido.'; end if;
  if cardinality(array(select distinct e from unnest(reaction_emojis) e)) <> cardinality(reaction_emojis) then raise exception 'No repitas emojis.'; end if;
  insert into public.gabriplay_broadcast_posts(title,body,allowed_emojis)
  values(trim(post_title),trim(post_body),reaction_emojis) returning id into new_id;
  return new_id;
end;
$$;

create or replace function public.gabriplay_broadcast_update(
  target_post_id uuid, post_title text, post_body text, reaction_emojis text[]
)
returns boolean
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.gabriplay_is_creator() then raise exception 'Solo el creador puede editar.'; end if;
  if char_length(trim(coalesce(post_title,''))) not between 1 and 100 then raise exception 'El título debe tener entre 1 y 100 caracteres.'; end if;
  if char_length(trim(coalesce(post_body,''))) not between 1 and 5000 then raise exception 'El mensaje debe tener entre 1 y 5000 caracteres.'; end if;
  if reaction_emojis is null or cardinality(reaction_emojis) not between 1 and 8 then raise exception 'Elige entre 1 y 8 emojis.'; end if;
  if exists(select 1 from unnest(reaction_emojis) e where char_length(e)>16 or trim(e)='') then raise exception 'Hay un emoji no válido.'; end if;
  if cardinality(array(select distinct e from unnest(reaction_emojis) e)) <> cardinality(reaction_emojis) then raise exception 'No repitas emojis.'; end if;
  update public.gabriplay_broadcast_posts
  set title=trim(post_title),body=trim(post_body),allowed_emojis=reaction_emojis,updated_at=now()
  where id=target_post_id;
  if not found then raise exception 'No se encuentra la publicación.'; end if;
  delete from public.gabriplay_broadcast_reactions
  where post_id=target_post_id and not (emoji=any(reaction_emojis));
  return true;
end;
$$;

create or replace function public.gabriplay_broadcast_delete(target_post_id uuid)
returns boolean
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.gabriplay_is_creator() then raise exception 'Solo el creador puede eliminar.'; end if;
  delete from public.gabriplay_broadcast_posts where id=target_post_id;
  if not found then raise exception 'No se encuentra la publicación.'; end if;
  return true;
end;
$$;

create or replace function public.gabriplay_broadcast_toggle_reaction(
  target_post_id uuid, reaction_emoji text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare removed boolean := false;
begin
  if auth.uid() is null then raise exception 'Inicia sesión para reaccionar.'; end if;
  if not exists(
    select 1 from public.gabriplay_broadcast_posts p
    where p.id=target_post_id and p.published=true
      and reaction_emoji=any(p.allowed_emojis)
  ) then raise exception 'Ese emoji no está disponible para esta publicación.'; end if;
  if exists(select 1 from public.gabriplay_broadcast_reactions
            where post_id=target_post_id and user_id=auth.uid() and emoji=reaction_emoji) then
    delete from public.gabriplay_broadcast_reactions
    where post_id=target_post_id and user_id=auth.uid();
    removed:=true;
  else
    insert into public.gabriplay_broadcast_reactions(post_id,user_id,emoji)
    values(target_post_id,auth.uid(),reaction_emoji)
    on conflict(post_id,user_id) do update set emoji=excluded.emoji,created_at=now();
  end if;
  return jsonb_build_object('removed',removed);
end;
$$;

revoke all on function public.gabriplay_broadcast_feed() from public;
revoke all on function public.gabriplay_broadcast_create(text,text,text[]) from public;
revoke all on function public.gabriplay_broadcast_update(uuid,text,text,text[]) from public;
revoke all on function public.gabriplay_broadcast_delete(uuid) from public;
revoke all on function public.gabriplay_broadcast_toggle_reaction(uuid,text) from public;
grant execute on function public.gabriplay_broadcast_feed() to anon,authenticated;
grant execute on function public.gabriplay_broadcast_create(text,text,text[]) to authenticated;
grant execute on function public.gabriplay_broadcast_update(uuid,text,text,text[]) to authenticated;
grant execute on function public.gabriplay_broadcast_delete(uuid) to authenticated;
grant execute on function public.gabriplay_broadcast_toggle_reaction(uuid,text) to authenticated;
notify pgrst, 'reload schema';
