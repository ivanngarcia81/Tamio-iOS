-- Aplicada el 2026-09-07. Amplía el contador de folios a los documentos de
-- Secretaría.
--
-- Comprobado después de aplicarla, con las dos consultas del final:
--   acta 2026 → 2 · carta 2026 → 5 · ingreso y gasto intactas en el año 0.
-- Y ninguna serie por debajo de lo emitido: cero filas, que es lo correcto.
-- La siguiente carta será CAR-2026-0006 y la siguiente acta ACTA-2026-003,
-- exactamente los que salían antes: la semilla no mueve nada de lo emitido.
--
-- El contador del 3 de septiembre resolvió los movimientos: "dame el siguiente"
-- y "apúntalo" son un solo statement, así que dos capturas simultáneas no
-- pueden recibir el mismo número. Cartas, actas, traslados y solicitudes se
-- quedaron fuera y siguen contando en el cliente, cada app a su manera.
--
-- **Ya se rompió.** En la base de la iglesia hay CUATRO actas con el folio
-- ACTA-2026-001: el web numera con `count(*)` de las actas del año, así que
-- borrar una —o crear desde dos sitios sin sincronizar— repite el número. Y el
-- iOS ni siquiera lleva serie: numeraba "2026-08", año y mes, con lo que dos
-- actas del mismo mes nacen iguales por diseño.
--
-- Un folio repetido es un documento que no se puede citar, y estos se aprueban,
-- se firman y se entregan.

-- ---------------------------------------------------------------------------
-- 1. El contador, ahora por AÑO
-- ---------------------------------------------------------------------------
--
-- Las series de Secretaría empiezan por uno cada año —ACTA-2026-001 y
-- ACTA-2027-001 son dos documentos distintos, no un choque—, cosa que el
-- contador plano no sabe hacer. Los movimientos NO reinician: su folio ya sale
-- "2026-0141 → 2027-0142" y cambiarlo ahora renumeraría lo emitido.
--
-- Por eso el año entra como columna con default 0: las filas que ya existen
-- —ingreso y gasto— se quedan en el año 0, que significa "esta serie no
-- reinicia", y `siguiente_folio` sigue funcionando exactamente igual para
-- ellas. Las nuevas usan su año de verdad.
alter table public.folios_contador
    add column if not exists anio integer not null default 0;

alter table public.folios_contador drop constraint if exists folios_contador_pkey;
alter table public.folios_contador add primary key (church_id, serie, anio);

alter table public.folios_contador drop constraint if exists folios_contador_serie_check;
alter table public.folios_contador add constraint folios_contador_serie_check
    check (serie in ('ingreso', 'gasto',
                     'carta', 'acta', 'traslado_salida', 'traslado_entrada', 'solicitud'));

-- ---------------------------------------------------------------------------
-- 2. La semilla, que es lo que no puede salir mal
-- ---------------------------------------------------------------------------
--
-- El contador arranca en cero. Si se dejara así, la primera carta que lo use
-- saldría CAR-2026-0001 y chocaría con la que ya existe con ese folio. Se
-- siembra con el máximo que cada iglesia tiene HOY, contando también lo
-- borrado: ese número se emitió y está citado en algún papel.
--
-- Cartas, traslados y solicitudes guardan su `numero_seq`, así que el máximo se
-- lee directo. Las actas no lo tienen —el web las numera contando— y hay que
-- sacarlo del propio folio, aceptando solo los que tienen la forma buena: los
-- que escribió el iOS ("2026-08") no son de esta serie y no deben contar.

insert into public.folios_contador (church_id, serie, anio, ultimo)
select church_id, 'carta', substr(fecha_emision, 1, 4)::int, max(numero_seq)
  from public.cartas
 where fecha_emision is not null and numero_seq is not null
 group by church_id, substr(fecha_emision, 1, 4)
on conflict (church_id, serie, anio)
do update set ultimo = greatest(public.folios_contador.ultimo, excluded.ultimo);

insert into public.folios_contador (church_id, serie, anio, ultimo)
select church_id, 'traslado_salida', substr(fecha_solicitud, 1, 4)::int, max(numero_seq)
  from public.traslados_salida
 where fecha_solicitud is not null and numero_seq is not null
 group by church_id, substr(fecha_solicitud, 1, 4)
on conflict (church_id, serie, anio)
do update set ultimo = greatest(public.folios_contador.ultimo, excluded.ultimo);

insert into public.folios_contador (church_id, serie, anio, ultimo)
select church_id, 'traslado_entrada', substr(creado_en, 1, 4)::int, max(numero_seq)
  from public.traslados_entrada
 where creado_en is not null and numero_seq is not null
 group by church_id, substr(creado_en, 1, 4)
on conflict (church_id, serie, anio)
do update set ultimo = greatest(public.folios_contador.ultimo, excluded.ultimo);

insert into public.folios_contador (church_id, serie, anio, ultimo)
select church_id, 'solicitud', substr(fecha_solicitud, 1, 4)::int, max(numero_seq)
  from public.solicitudes
 where fecha_solicitud is not null and numero_seq is not null
 group by church_id, substr(fecha_solicitud, 1, 4)
on conflict (church_id, serie, anio)
do update set ultimo = greatest(public.folios_contador.ultimo, excluded.ultimo);

-- Las actas, del folio. `ACTA-2026-001` → 1. Lo que no tenga esa forma se
-- queda fuera del máximo a propósito.
insert into public.folios_contador (church_id, serie, anio, ultimo)
select church_id,
       'acta',
       substr(folio, 6, 4)::int,
       max(substr(folio, 11)::int)
  from public.actas
 where folio ~ '^ACTA-[0-9]{4}-[0-9]+$'
 group by church_id, substr(folio, 6, 4)
on conflict (church_id, serie, anio)
do update set ultimo = greatest(public.folios_contador.ultimo, excluded.ultimo);

-- ---------------------------------------------------------------------------
-- 3. Las funciones con año
-- ---------------------------------------------------------------------------
--
-- `siguiente_folio` y `folio_previsto` se quedan COMO ESTÁN: las llaman los
-- movimientos desde las dos apps, y una firma que cambia es una app que deja de
-- funcionar hasta que se actualice. Estas dos son sus hermanas con año.

create or replace function public.siguiente_folio_anual(
    p_church_id uuid, p_serie text, p_anio integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_nuevo integer;
begin
    if p_serie not in ('carta', 'acta', 'traslado_salida', 'traslado_entrada', 'solicitud') then
        raise exception 'Serie anual no válida: %', p_serie;
    end if;
    if p_anio < 2000 or p_anio > 2999 then
        raise exception 'Año fuera de rango: %', p_anio;
    end if;

    -- SECURITY DEFINER salta RLS, así que la pertenencia se comprueba a mano,
    -- igual que en `siguiente_folio`.
    if not exists (
        select 1 from public.perfiles
        where id = auth.uid() and church_id = p_church_id
    ) then
        raise exception 'Sin acceso a esta iglesia';
    end if;

    insert into public.folios_contador as fc (church_id, serie, anio, ultimo)
    values (p_church_id, p_serie, p_anio, 1)
    on conflict (church_id, serie, anio)
    do update set ultimo = fc.ultimo + 1, updated_at = now()
    returning fc.ultimo into v_nuevo;

    return v_nuevo;
end;
$$;

-- Mira en qué número va la serie sin consumirlo, para enseñar un folio previsto
-- que no se gasta si quien lo ve cancela.
create or replace function public.folio_previsto_anual(
    p_church_id uuid, p_serie text, p_anio integer)
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
    where church_id = p_church_id and serie = p_serie and anio = p_anio;

    return coalesce(v_ultimo, 0) + 1;
end;
$$;

revoke all on function public.siguiente_folio_anual(uuid, text, integer) from public, anon;
revoke all on function public.folio_previsto_anual(uuid, text, integer)  from public, anon;
grant execute on function public.siguiente_folio_anual(uuid, text, integer) to authenticated;
grant execute on function public.folio_previsto_anual(uuid, text, integer)  to authenticated;

-- ---------------------------------------------------------------------------
-- Comprobación. Se corre a mano DESPUÉS de aplicar, y no cambia nada.
-- ---------------------------------------------------------------------------
--
--   select serie, anio, ultimo from public.folios_contador order by serie, anio;
--
-- Lo que tiene que salir, para la iglesia que ya tiene datos:
--   · una fila 'carta' del año en curso con el número de la última carta,
--   · una fila 'acta' con el máximo de las ACTA-AAAA-NNN,
--   · 'ingreso' y 'gasto' intactas, con anio = 0.
--
-- Y que ninguna serie quede POR DEBAJO de lo emitido:
--
--   select c.church_id, substr(c.fecha_emision,1,4) anio,
--          max(c.numero_seq) emitido, f.ultimo contador
--     from public.cartas c
--     left join public.folios_contador f
--       on f.church_id = c.church_id and f.serie = 'carta'
--      and f.anio = substr(c.fecha_emision,1,4)::int
--    group by c.church_id, substr(c.fecha_emision,1,4), f.ultimo
--   having f.ultimo is null or f.ultimo < max(c.numero_seq);
--
-- Cero filas es lo correcto. Una sola fila significa que alguien va a recibir
-- un folio ya usado.
