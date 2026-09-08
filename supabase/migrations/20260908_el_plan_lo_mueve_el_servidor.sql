-- **El disparador que protege el plan estaba bloqueando también al servidor.**
-- NO APLICADA todavía: la corre Iván.
--
-- `iglesias_congelar_administradas` se añadió el 7 de septiembre junto con la
-- política de UPDATE, y hace bien lo que se le pidió: que nadie se cambie el
-- plan ni su suscripción desde el teléfono. Pero congela esas tres columnas
-- SIN MIRAR QUIÉN escribe:
--
--     new.plan       := old.plan;
--     new.sub_estado := old.sub_estado;
--     new.sub_vence  := old.sub_vence;
--
-- Y eso alcanza al servidor. Dos consecuencias, las dos comprobadas contra la
-- base el 8 de septiembre:
--
-- 1. **El webhook de pagos ya no puede cobrar.** `pago-webhook` termina en un
--    `update` de `iglesias` con la clave de servicio; el disparador lo revierte
--    y el update **no da error**: devuelve éxito y no cambia nada. Es el mismo
--    fallo silencioso que ya costó caro con la política de UPDATE que faltaba,
--    ahora en el camino del dinero. Hoy no ha hecho daño porque la app no está
--    publicada; la habría hecho en la primera venta.
--
-- 2. **Una cortesía no se puede dar ni desde el editor de Supabase.** Se probó
--    un `update` a `sub_estado` sobre una iglesia vacía, dentro de un bloque
--    que se deshace solo: el valor seguía igual después.
--
-- El arreglo es dejar pasar a los roles del SERVIDOR y seguir congelando a los
-- del cliente. `service_role` es con el que entra el webhook por PostgREST;
-- `postgres` es con el que entra el editor de SQL —comprobado con
-- `select current_user` desde los dos—. Cualquier otro rol, incluido
-- `authenticated`, se queda como estaba.
--
-- De paso se le fija el `search_path`, que era el punto 2 de
-- `20260908_endurecer_antes_de_publicar.sql`: es justo la función que no
-- conviene que sea secuestrable.
create or replace function public.iglesias_congelar_administradas()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  new.id := old.id;

  -- El plan y la suscripción los mueve SOLO el servidor: el webhook de pagos
  -- y las cortesías que se dan a mano. Desde el cliente, nunca.
  if current_user not in ('service_role', 'postgres') then
    new.plan       := old.plan;
    new.sub_estado := old.sub_estado;
    new.sub_vence  := old.sub_vence;
  end if;

  -- Los dos permisos siguen igual: solo se mueven por
  -- `fijar_permisos_tesoreria`, que se anuncia con esta marca local.
  if coalesce(current_setting('tamio.permisos_por_rpc', true), '') <> 'on' then
    new.tesorero_ve_padron      := old.tesorero_ve_padron;
    new.tesorero_puede_eliminar := old.tesorero_puede_eliminar;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

-- **Cómo se da una cortesía**, una vez aplicado esto. Desde el editor de SQL:
--
--     update public.iglesias
--        set sub_estado = 'cortesia', sub_vence = null
--      where id = (select church_id from public.perfiles p
--                  join auth.users u on u.id = p.id
--                  where lower(u.email) = 'correo@de.la.persona');
--
-- `cortesia` no es un valor inventado: ya lo usa "Iglesia principal", y
-- `pago-webhook` lo respeta expresamente —un evento de pago nunca degrada una
-- cuenta regalada—.
