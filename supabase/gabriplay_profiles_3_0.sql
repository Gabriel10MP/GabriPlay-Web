-- GabriPlay Perfiles 3.0
-- Ejecutar en Supabase SQL Editor después de gabriplay_profiles_2_0.sql.
-- Economía segura: puntos por sugerencias aprobadas y catálogo de cosméticos.

create table if not exists public.gabriplay_points_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null check (amount <> 0),
  reason text not null,
  reference_id uuid,
  created_at timestamptz not null default now()
);
create unique index if not exists gabriplay_points_once_per_event
  on public.gabriplay_points_ledger(user_id, reason, reference_id)
  where reference_id is not null;
alter table public.gabriplay_points_ledger enable row level security;
drop policy if exists "Users can read own GabriPlay points" on public.gabriplay_points_ledger;
create policy "Users can read own GabriPlay points"
  on public.gabriplay_points_ledger for select to authenticated
  using (auth.uid() = user_id);

create table if not exists public.gabriplay_cosmetics (
  code text primary key,
  name text not null,
  description text not null default '',
  category text not null check (category in ('name_effect','avatar_frame','profile_background')),
  price integer not null check (price >= 0),
  active boolean not null default true
);
insert into public.gabriplay_cosmetics(code,name,description,category,price) values
 ('name_crimson','Crimson animado','Degradado rojo con brillo en movimiento','name_effect',100),
 ('name_ice','Hielo azul','Degradado azul frío animado','name_effect',150),
 ('name_gold','Oro imperial','Degradado dorado animado','name_effect',200),
 ('name_sakura','Sakura','Rosa suave con destellos animados','name_effect',175),
 ('frame_crimson','Marco Crimson','Borde rojo para tu avatar','avatar_frame',125),
 ('frame_onyx','Marco Ónix','Marco oscuro con reflejo metálico','avatar_frame',175)
on conflict (code) do update set
 name=excluded.name,description=excluded.description,category=excluded.category,price=excluded.price;

alter table public.gabriplay_cosmetics enable row level security;
drop policy if exists "Cosmetics catalog is public" on public.gabriplay_cosmetics;
create policy "Cosmetics catalog is public"
  on public.gabriplay_cosmetics for select to anon, authenticated using (active);

create table if not exists public.gabriplay_user_cosmetics (
  user_id uuid not null references auth.users(id) on delete cascade,
  cosmetic_code text not null references public.gabriplay_cosmetics(code),
  purchased_at timestamptz not null default now(),
  equipped boolean not null default false,
  primary key (user_id, cosmetic_code)
);
alter table public.gabriplay_user_cosmetics enable row level security;
drop policy if exists "Users can read equipped cosmetics" on public.gabriplay_user_cosmetics;
create policy "Users can read equipped cosmetics"
  on public.gabriplay_user_cosmetics for select to anon, authenticated
  using (equipped or auth.uid() = user_id);

create or replace function public.gabriplay_award_approved_suggestion_points()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.status = 'approved' and old.status is distinct from 'approved'
     and new.user_id is not null then
    insert into public.gabriplay_points_ledger(user_id, amount, reason, reference_id)
    values (new.user_id, 25, 'approved_suggestion', new.id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;
drop trigger if exists gabriplay_award_suggestion_points on public.suggestions;
create trigger gabriplay_award_suggestion_points
after update of status on public.suggestions
for each row execute function public.gabriplay_award_approved_suggestion_points();

create or replace function public.gabriplay_buy_cosmetic(target_code text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  buyer uuid := auth.uid();
  item public.gabriplay_cosmetics%rowtype;
  balance integer;
begin
  if buyer is null then raise exception 'Debes iniciar sesión.'; end if;
  select * into item from public.gabriplay_cosmetics
    where code = target_code and active = true;
  if not found then raise exception 'Este complemento no está disponible.'; end if;
  perform 1 from auth.users where id = buyer for update;
  if exists(select 1 from public.gabriplay_user_cosmetics where user_id=buyer and cosmetic_code=target_code) then
    raise exception 'Ya tienes este complemento.';
  end if;
  select coalesce(sum(amount),0)::integer into balance
    from public.gabriplay_points_ledger where user_id=buyer;
  if balance < item.price then raise exception 'No tienes puntos suficientes.'; end if;
  insert into public.gabriplay_user_cosmetics(user_id,cosmetic_code)
    values(buyer,target_code);
  insert into public.gabriplay_points_ledger(user_id,amount,reason,reference_id)
    values(buyer,-item.price,'cosmetic_purchase',gen_random_uuid());
  return jsonb_build_object('success',true,'balance',balance-item.price,'cosmetic',target_code);
end;
$$;

create or replace function public.gabriplay_equip_cosmetic(target_code text)
returns boolean language plpgsql security definer set search_path = ''
as $$
declare
  buyer uuid := auth.uid();
  item_category text;
begin
  if buyer is null then raise exception 'Debes iniciar sesión.'; end if;
  select c.category into item_category
  from public.gabriplay_cosmetics c
  join public.gabriplay_user_cosmetics uc on uc.cosmetic_code=c.code
  where uc.user_id=buyer and uc.cosmetic_code=target_code and c.active=true;
  if not found then raise exception 'No tienes ese complemento.'; end if;
  update public.gabriplay_user_cosmetics uc set equipped=false
  from public.gabriplay_cosmetics c
  where uc.user_id=buyer and uc.cosmetic_code=c.code and c.category=item_category;
  update public.gabriplay_user_cosmetics set equipped=true
  where user_id=buyer and cosmetic_code=target_code;
  return true;
end;
$$;

create or replace function public.gabriplay_points_balance()
returns integer language sql stable security definer set search_path = ''
as $$
  select coalesce(sum(amount),0)::integer
  from public.gabriplay_points_ledger where user_id=auth.uid();
$$;

revoke all on function public.gabriplay_award_approved_suggestion_points() from public;
revoke all on function public.gabriplay_buy_cosmetic(text) from public;
revoke all on function public.gabriplay_equip_cosmetic(text) from public;
revoke all on function public.gabriplay_points_balance() from public;
grant execute on function public.gabriplay_buy_cosmetic(text) to authenticated;
grant execute on function public.gabriplay_equip_cosmetic(text) to authenticated;
grant execute on function public.gabriplay_points_balance() to authenticated;
notify pgrst, 'reload schema';
