-- GabriPlay · Panel exclusivo del creador
-- Ejecutar después de gabriplay_profiles_3_0.sql.
-- Las operaciones se validan en servidor; no confiar en controles del navegador.

create table if not exists public.gabriplay_creator_audit (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id),
  target_user_id uuid not null references auth.users(id),
  action text not null check (action in ('points_granted','cosmetic_gifted')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.gabriplay_creator_audit enable row level security;
revoke all on public.gabriplay_creator_audit from anon, authenticated;

create or replace function public.gabriplay_is_creator()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and lower(p.username) = 'gabri10'
  ) and public.is_gabriplay_admin(auth.uid());
$$;

create or replace function public.gabriplay_creator_list_users()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare result jsonb;
begin
  if not public.gabriplay_is_creator() then raise exception 'Acceso exclusivo del creador.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id, 'username', p.username, 'display_name', p.display_name
  ) order by lower(coalesce(p.username,''))), '[]'::jsonb)
  into result from public.profiles p;
  return result;
end;
$$;

create or replace function public.gabriplay_creator_grant_points(
  target_user_id uuid, points_amount integer, note text default 'Regalo del creador'
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare clean_note text := left(coalesce(nullif(trim(note),''),'Regalo del creador'),160);
begin
  if not public.gabriplay_is_creator() then raise exception 'Acceso exclusivo del creador.'; end if;
  if points_amount is null or points_amount < 1 or points_amount > 1000000 then
    raise exception 'La cantidad debe estar entre 1 y 1.000.000 puntos.';
  end if;
  if not exists(select 1 from auth.users u where u.id=target_user_id) then
    raise exception 'No se encuentra esa cuenta.';
  end if;
  insert into public.gabriplay_points_ledger(user_id,amount,reason,reference_id)
  values(target_user_id,points_amount,'creator_gift',gen_random_uuid());
  insert into public.gabriplay_creator_audit(actor_id,target_user_id,action,details)
  values(auth.uid(),target_user_id,'points_granted',jsonb_build_object('amount',points_amount,'note',clean_note));
  return jsonb_build_object('success',true);
end;
$$;

create or replace function public.gabriplay_creator_gift_cosmetic(
  target_user_id uuid, target_code text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare item_name text;
begin
  if not public.gabriplay_is_creator() then raise exception 'Acceso exclusivo del creador.'; end if;
  if not exists(select 1 from auth.users u where u.id=target_user_id) then
    raise exception 'No se encuentra esa cuenta.';
  end if;
  select name into item_name from public.gabriplay_cosmetics
  where code=target_code and active=true;
  if not found then raise exception 'Ese cosmético no está disponible.'; end if;
  insert into public.gabriplay_user_cosmetics(user_id,cosmetic_code,equipped)
  values(target_user_id,target_code,false)
  on conflict(user_id,cosmetic_code) do nothing;
  if not found then raise exception 'Ese usuario ya tiene el cosmético.'; end if;
  insert into public.gabriplay_creator_audit(actor_id,target_user_id,action,details)
  values(auth.uid(),target_user_id,'cosmetic_gifted',jsonb_build_object('code',target_code,'name',item_name));
  return jsonb_build_object('success',true,'name',item_name);
end;
$$;

create or replace function public.gabriplay_creator_history()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare result jsonb;
begin
  if not public.gabriplay_is_creator() then raise exception 'Acceso exclusivo del creador.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'action', a.action, 'details', a.details,
    'created_at', a.created_at, 'username', p.username, 'display_name', p.display_name
  ) order by a.created_at desc), '[]'::jsonb)
  into result
  from (select * from public.gabriplay_creator_audit order by created_at desc limit 100) a
  join public.profiles p on p.id=a.target_user_id;
  return result;
end;
$$;

revoke all on function public.gabriplay_is_creator() from public;
revoke all on function public.gabriplay_creator_list_users() from public;
revoke all on function public.gabriplay_creator_grant_points(uuid,integer,text) from public;
revoke all on function public.gabriplay_creator_gift_cosmetic(uuid,text) from public;
revoke all on function public.gabriplay_creator_history() from public;
grant execute on function public.gabriplay_is_creator() to authenticated;
grant execute on function public.gabriplay_creator_list_users() to authenticated;
grant execute on function public.gabriplay_creator_grant_points(uuid,integer,text) to authenticated;
grant execute on function public.gabriplay_creator_gift_cosmetic(uuid,text) to authenticated;
grant execute on function public.gabriplay_creator_history() to authenticated;
notify pgrst, 'reload schema';
