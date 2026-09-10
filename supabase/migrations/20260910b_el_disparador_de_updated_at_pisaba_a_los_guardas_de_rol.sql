-- Aplicada el 2026-09-10, unas horas después de
-- `20260910_updated_at_no_se_movia...`. **Es una regresión de esa misma
-- migración**, encontrada al auditar los permisos el mismo día.
--
-- `frenar_borrado_tesorero` y `frenar_baja_tesorero` no solo revierten lo que un
-- tesorero sin permiso intentó: además **empujan `updated_at` a propósito**
-- —`greatest(now(), new.updated_at + 1s)`— para que la fila revertida vuelva a
-- bajar al aparato que lo intentó. Sin eso, ese aparato se queda creyendo que
-- borró algo que el servidor conserva, que es exactamente la divergencia que el
-- guarda existe para evitar.
--
-- Postgres dispara los BEFORE por orden **alfabético del nombre**, así que
-- `frenar_...` corría antes que `marcar_updated_at` y el mío deshacía el
-- empujón: ponía `new.updated_at := old.updated_at`, y como el guarda ya había
-- revertido el contenido, `new is distinct from old` daba falso y la marca se
-- quedaba igual.
--
-- Medido con una maqueta de dos disparadores, antes de tocar nada:
--
--     revertido=t | la marca avanzo=f
--
-- Dos cambios, y el primero es el que importa:
--
-- 1. **El prefijo `a0_` es funcional, no decorativo.** Hace que este dispare
--    ANTES que cualquier guarda, de modo que la política tenga siempre la última
--    palabra sobre la marca. Renombrarlo lo vuelve a romper, y en silencio.
--
-- 2. **La marca nunca retrocede.** El guarda empuja un segundo al futuro; un
--    cambio legítimo dentro de ese segundo recibía `clock_timestamp()`, que es
--    ANTERIOR, y la fila iba hacia atrás — invisible para cualquier aparato cuyo
--    cursor ya hubiera pasado ese punto. `greatest(clock_timestamp(),
--    old.updated_at + 1us)` la hace monótona, que es lo que un cursor necesita.
create or replace function public.marcar_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := old.updated_at;
  if new is distinct from old then
    new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  end if;
  return new;
end;
$$;

revoke all on function public.marcar_updated_at() from public, anon, authenticated;

do $$
declare t text;
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
    execute format('drop trigger if exists marcar_updated_at on public.%I', t);
    execute format('drop trigger if exists a0_marcar_updated_at on public.%I', t);
    execute format(
      'create trigger a0_marcar_updated_at before update on public.%I
         for each row execute function public.marcar_updated_at()', t);
  end loop;
end
$$;

-- **Comprobado el 2026-09-10**, primero en una maqueta con los dos disparadores
-- (para no tocar las tablas de la app) y luego sobre `transactions`:
--
--     revertido=t | guarda empuja=t | cambio real avanza=t
--     update vacio no mueve=t | nunca retrocede=t
--
--     a0=23 viejos=0 | orden=a0_marcar_updated_at -> frenar_borrado_tesorero
--
-- El orden es la mitad del arreglo: si algún día ese `->` sale al revés, el
-- empujón de los guardas ha vuelto a perderse.
