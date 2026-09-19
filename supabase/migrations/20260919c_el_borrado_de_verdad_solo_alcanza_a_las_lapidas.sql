-- Una fila viva no se borra. El borrado de verdad solo alcanza a las lápidas.
--
-- Es el §5 de `docs/PERMISOS-EN-EL-SERVIDOR.md`, lo último que quedaba del
-- reparto por rol. El §4 cerró el rastro de auditoría; esto cierra las otras
-- veinte tablas.
--
-- ── El agujero, medido el 19-sep-2026 ──────────────────────────────────────
--
-- Las veinte tablas de datos tienen política de DELETE y `authenticated` tiene
-- el permiso. Desde el 15-sep esas políticas miran el rol, así que un borrado
-- lo puede hacer quien escribe en esa área... **y eso NO es lo mismo que poder
-- dar de baja.** Los dos guardas que existen —`frenar_borrado_tesorero` en
-- `transactions` y `frenar_baja_tesorero` en `members`— son BEFORE **UPDATE**:
-- frenan la lápida, no el borrado. Un tesorero con `tesorero_puede_eliminar`
-- apagado no puede dar de baja un movimiento y sí puede **eliminar la fila
-- entera**, que además no deja rastro ni se propaga a los demás aparatos.
--
-- ── Por qué esta forma y no quitar el DELETE ───────────────────────────────
--
-- Porque hay un borrado de verdad que SÍ es legítimo, y solo uno. Buscado en
-- los dos repos, no supuesto:
--
--   | app | borrados remotos |
--   |---|---|
--   | iOS | **ninguno**. `eliminar(id:)` es un `update deleted = true` (`SupabaseMovimientosRepository.swift:149`) |
--   | web | **uno**: `compactarBase`, que purga en la nube las lápidas de más de 90 días |
--
-- Y la compactación solo manda los `uid` de filas que ella misma seleccionó
-- con `deleted = 1`. O sea que «solo se borra lo que ya tiene lápida» es
-- exactamente lo que las dos apps hacen hoy, dicho en el servidor.
--
-- ── Por qué un disparador y no acotar la política ──────────────────────────
--
-- Porque una política que descarta la fila **no avisa**: el `delete` afecta a
-- cero filas y PostgREST contesta 204. Está medido en este repo el 19-sep, con
-- las dos formas, y es la razón por la que el §4 se cerró con un `revoke` y no
-- con un `drop policy`. Aquí no se puede usar el permiso —la compactación lo
-- necesita—, así que el guarda va donde puede LANZAR: un `BEFORE DELETE` que
-- contesta `42501` cuando la fila está viva.
--
-- ── A quién no le quita nada ───────────────────────────────────────────────
--
-- A nadie. iOS no borra de verdad; el web solo purga lápidas; `service_role` y
-- `postgres` están exentos, que es lo que usan las Edge Functions
-- (`borrar-cuenta`) y las migraciones. Comprobado además que **entre estas
-- tablas no hay ninguna clave foránea**, así que ninguna purga puede arrastrar
-- en cascada a una fila viva de otra tabla: la única `on delete cascade` del
-- esquema cuelga de `iglesias` y de `auth.users`, y las dos las mueve
-- `service_role`.
--
-- ── `registro` no entra, y no por olvido ───────────────────────────────────
--
-- Su cierre es MÁS duro: no tiene permiso de DELETE en absoluto
-- (`20260919b`). Ponerle este disparador dejaría escrito que borrar una lápida
-- suya es aceptable, y no lo es: la bitácora ya no se purga en ninguno de los
-- dos clientes.

create or replace function public.solo_se_borra_lo_enterrado()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
  if current_user in ('postgres', 'service_role') then
    return old;
  end if;

  if not old.deleted then
    raise exception 'Una fila viva de «%» no se borra: primero se le pone la lápida', tg_table_name
      using errcode = '42501',
            hint = 'El borrado de verdad solo alcanza a las lápidas, que es lo único que purga la compactación.';
  end if;

  return old;
end
$fn$;

comment on function public.solo_se_borra_lo_enterrado() is
  'Guarda del §5 (19-sep-2026): un DELETE solo puede alcanzar filas con deleted = true. Lo vivo se da de baja; purgar es otra cosa. Exentos postgres y service_role.';

-- **Las tablas se BUSCAN, no se escriben a mano.** Es la misma trampa que el
-- web documenta en `verificar-borrado`: quien añade una tabla piensa en
-- crearla, sincronizarla y pintarla, y la lista de guardas vive en otro sitio.
-- Si el número no es el esperado, esto se planta en vez de dejar tablas fuera
-- en silencio.
do $$
declare
  t text;
  n int := 0;
begin
  for t in
    select c.relname
    from pg_class c
    join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public' and c.relkind = 'r'
      and c.relname <> 'registro'
      and exists (select 1 from information_schema.columns k
                  where k.table_schema = 'public' and k.table_name = c.relname
                    and k.column_name = 'deleted')
    order by c.relname
  loop
    execute format('drop trigger if exists a1_solo_se_borra_lo_enterrado on public.%I', t);
    execute format('create trigger a1_solo_se_borra_lo_enterrado before delete on public.%I '
                   'for each row execute function public.solo_se_borra_lo_enterrado()', t);
    n := n + 1;
  end loop;

  if n <> 20 then
    raise exception 'Se esperaban 20 tablas con lápida y salieron %. Míralo antes de aplicar.', n;
  end if;
end $$;

-- ── Cómo se comprueba ──────────────────────────────────────────────────────
--
-- `supabase/pruebas/borrado_de_verdad.sql`, que mide las dos caras por rol
-- —una fila viva no se borra, una con lápida sí— y además **la cobertura**:
-- toda tabla con `deleted` tiene que llevar el guarda. Esa última fila es la
-- que caza la tabla nueva que nadie acordó proteger.
--
-- ── Lo que esto NO es ──────────────────────────────────────────────────────
--
-- No es el permiso de dar de baja. Quién puede poner la lápida sigue estando
-- donde estaba: en las políticas por área del 15-sep y en los dos disparadores
-- de `tesorero_puede_eliminar`. Esto solo impide que el borrado de verdad se
-- use para saltárselos.
