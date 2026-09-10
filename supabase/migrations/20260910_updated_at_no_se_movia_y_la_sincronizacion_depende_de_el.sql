-- Aplicada el 2026-09-10.
--
-- **`updated_at` no se movía al ACTUALIZAR, y es el cursor de toda la
-- sincronización.**
--
-- Las veintitrés tablas lo tenían con `default now()`, que solo aplica al
-- INSERT. Ningún disparador lo mantenía, y la app nunca lo manda: el motor solo
-- lo LEE, para bajar (`.gt("updated_at", cursor).order("updated_at").limit(500)`).
--
-- O sea que un registro NUEVO llegaba a los demás aparatos, y **cualquier cambio
-- sobre uno que ya existía —editarlo o darlo de baja— no se enteraba nadie
-- más**. Borras un movimiento en el teléfono y el escritorio lo sigue enseñando
-- para siempre; corriges un importe y allá se queda el viejo.
--
-- **Cómo se destapó**, el 10 de septiembre: Iván borró todos los datos de la app
-- y los restauró desde un respaldo con contraseña. Al comparar contra la base,
-- las 34 filas resucitadas seguían con la marca de las 7:30 de esa mañana —antes
-- del borrado— y las 38 de baja con la de agosto. Habían cambiado dos veces en
-- el día y la marca no se movió ni una.
--
-- Y explica lo del 7 de septiembre que ya está en el traspaso: el servidor con
-- 66 filas marcadas de baja y el teléfono con sus movimientos intactos. No era
-- que el teléfono no obedeciera — es que nunca se enteró.

-- **`clock_timestamp()` y no `now()`.**
--
-- `now()` es la hora de la TRANSACCIÓN: un `update` masivo dentro de una sola
-- transacción deja a todas las filas con la misma marca al milisegundo. El
-- motor baja con `> cursor` y `limit 500`, así que si más de quinientas filas
-- comparten marca, al avanzar el cursor a ese valor **las que no cupieron no se
-- bajan nunca**. `clock_timestamp()` avanza dentro del propio statement y da un
-- valor distinto por fila, que es lo que esa paginación necesita.
--
-- (Lo correcto del todo sería que el cursor llevara también el `uid` como
-- desempate, como pide la guía de paginación. Eso es del lado de la app y queda
-- anotado; esto quita la causa de que haya empates.)
-- **`security invoker`, no `definer`, y sin `execute` para nadie.** La primera
-- versión salió `definer` por inercia y el linter de Supabase la marcó: una
-- función de DISPARADOR no necesita permisos elevados —corre dentro del UPDATE
-- de quien ya tenía derecho a hacerlo, que eso lo decide RLS— y lo único que
-- toca es `new`. Y una función que no es de la API no tiene por qué estar
-- expuesta en `/rest/v1/rpc`.
create or replace function public.marcar_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  -- **Lo que mande el cliente se ignora.** El campo significa "cuándo escribió
  -- esto el SERVIDOR": fiarse del reloj de un teléfono en un cursor de
  -- sincronización es como se consiguen filas que llegan del futuro y ya no
  -- vuelven a bajar nunca.
  new.updated_at := old.updated_at;

  -- Y solo se mueve si de verdad cambió algo. Un `update` que no toca nada no
  -- puede hacer que todos los aparatos se rebajen la fila otra vez.
  if new is distinct from old then
    new.updated_at := clock_timestamp();
  end if;

  return new;
end;
$$;

revoke all on function public.marcar_updated_at() from public, anon, authenticated;

comment on function public.marcar_updated_at() is
  'Mantiene updated_at en cada UPDATE. Es el cursor de la sincronización: sin '
  'esto, editar o dar de baja una fila no llega a los demás aparatos.';

-- Las veintitrés tablas que tienen `updated_at`. Van todas y no solo las que
-- hoy sincroniza el teléfono: una tabla con el campo y sin quien lo mantenga es
-- la misma trampa esperando a la siguiente entidad que se enchufe.
do $$
declare
  t text;
begin
  foreach t in array array[
    'actas', 'agenda', 'cartas', 'categorias_custom', 'corte_movimientos',
    'cortes', 'depositos_bancarios', 'folios_contador', 'iglesias', 'members',
    'mensajes', 'movimientos_recurrentes', 'parentescos', 'plantillas',
    'registro', 'servicio_asistencia', 'servicio_orden', 'servicio_puestos',
    'servicios', 'solicitudes', 'transactions', 'traslados_entrada',
    'traslados_salida'
  ]
  loop
    execute format(
      'drop trigger if exists marcar_updated_at on public.%I', t);
    execute format(
      'create trigger marcar_updated_at before update on public.%I
         for each row execute function public.marcar_updated_at()', t);
  end loop;
end
$$;

-- **Comprobado el 2026-09-10 sobre la base de la iglesia**, con las dos mitades
-- que importan y sin dejar rastro: el bloque se deshace solo porque termina en
-- un `raise`, y después se comprobó que ninguna fila quedaba con la marca de la
-- prueba.
--
--   do $$
--   declare v_uid text; t0 timestamptz; t1 timestamptz; t2 timestamptz; n int;
--   begin
--     select count(*) into n from information_schema.triggers
--      where trigger_schema='public' and trigger_name='marcar_updated_at';
--     select uid, updated_at into v_uid, t0
--       from public.transactions where not deleted order by uid limit 1;
--     update public.transactions set notas = notas where uid = v_uid;
--     select updated_at into t1 from public.transactions where uid = v_uid;
--     update public.transactions set notas = coalesce(notas,'') || ' zz' where uid = v_uid;
--     select updated_at into t2 from public.transactions where uid = v_uid;
--     raise exception 'disparadores=% | update vacio no la mueve: % | cambio real si: %',
--       n, (t1 = t0), (t2 > t0);
--   end $$;
--
-- Resultado: `disparadores=23 | update vacio no la mueve: t | cambio real si: t`.
