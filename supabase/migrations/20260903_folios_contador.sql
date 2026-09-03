-- Aplicada el 2026-09-03. Contador de folios por iglesia y serie.
--
-- Antes el cliente hacía `max(folio_seq) + 1` y guardaba: entre la lectura y
-- la escritura caben otras capturas, así que dos personas a la vez obtenían el
-- mismo folio. El contador vive aquí para que "dame el siguiente" y "apúntalo"
-- sean un solo paso indivisible.
--
-- Series separadas para ingresos y gastos: son dos talonarios distintos.
create table if not exists public.folios_contador (
    church_id  uuid        not null references public.iglesias(id) on delete cascade,
    serie      text        not null check (serie in ('ingreso', 'gasto')),
    ultimo     integer     not null default 0,
    updated_at timestamptz not null default now(),
    primary key (church_id, serie)
);

-- Nadie toca la tabla directamente: RLS activo y sin políticas, así que el
-- único camino son las funciones de abajo, que sí comprueban quién llama.
alter table public.folios_contador enable row level security;

-- Entrega el siguiente folio de una serie y lo reserva en el mismo statement.
-- `on conflict do update ... returning` bloquea la fila mientras la actualiza,
-- que es lo que hace imposible que dos llamadas simultáneas reciban el mismo
-- número.
create or replace function public.siguiente_folio(p_church_id uuid, p_serie text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_nuevo integer;
begin
    if p_serie not in ('ingreso', 'gasto') then
        raise exception 'Serie de folio no válida: %', p_serie;
    end if;

    -- SECURITY DEFINER salta RLS, así que la pertenencia se comprueba a mano.
    if not exists (
        select 1 from public.perfiles
        where id = auth.uid() and church_id = p_church_id
    ) then
        raise exception 'Sin acceso a esta iglesia';
    end if;

    insert into public.folios_contador as fc (church_id, serie, ultimo)
    values (p_church_id, p_serie, 1)
    on conflict (church_id, serie)
    do update set ultimo = fc.ultimo + 1, updated_at = now()
    returning fc.ultimo into v_nuevo;

    return v_nuevo;
end;
$$;

-- Solo mira en qué número va la serie, sin consumirlo. Para que la hoja de
-- captura pueda enseñar un folio previsto sin gastarlo si el usuario cancela.
create or replace function public.folio_previsto(p_church_id uuid, p_serie text)
returns integer
language plpgsql
security definer
stable
set search_path = public
as $$
declare
    v_ultimo integer;
begin
    if not exists (
        select 1 from public.perfiles
        where id = auth.uid() and church_id = p_church_id
    ) then
        raise exception 'Sin acceso a esta iglesia';
    end if;

    select ultimo into v_ultimo
    from public.folios_contador
    where church_id = p_church_id and serie = p_serie;

    return coalesce(v_ultimo, 0) + 1;
end;
$$;

revoke all on function public.siguiente_folio(uuid, text) from public, anon;
revoke all on function public.folio_previsto(uuid, text)  from public, anon;
grant execute on function public.siguiente_folio(uuid, text) to authenticated;
grant execute on function public.folio_previsto(uuid, text)  to authenticated;
