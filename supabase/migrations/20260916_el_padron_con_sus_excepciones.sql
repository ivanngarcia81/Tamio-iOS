-- El padrón, que es el caso con excepciones. §3 de docs/PERMISOS-EN-EL-SERVIDOR.md.
--
-- **El §3 del documento proponía bloquear `members_update` entero al tesorero,
-- y eso habría roto una función que existe.** `MembresiaView:41` pasa
-- `puedeDarDeBaja: administraPadron` a la hoja de EDICIÓN: o sea que un tesorero
-- con `tesorero_ve_padron` encendido abre la ficha y la edita; lo que no puede es
-- dar de alta ni de baja. Y `onAgregarPariente`/`onQuitarPariente` (`:121-125`)
-- no están detrás de `administraPadron` en absoluto — añadir un pariente es
-- editar la ficha, no darla de alta.
--
-- Así que el reparto es a TRES niveles, no a dos:
--
--   | operación                    | quién |
--   |------------------------------|-------|
--   | `members` INSERT / DELETE    | administrador y secretaria; el tesorero SOLO en plan `tesoreria` |
--   | `members` UPDATE             | los anteriores, MÁS el tesorero si `tesorero_ve_padron` |
--   | `parentescos` todo           | igual que `members` UPDATE: escribir ahí es editar |
--   | SELECT de las dos            | **sin tocar** |
--
-- **La lectura no se toca, y no es descuido.** `Permisos.swift` lo dice: «los
-- miembros se sincronizan igual a todos los aparatos, porque Aportantes los
-- necesita». `vePadron` abre una PANTALLA, no filtra la bajada. Cerrar el SELECT
-- dejaría a Tesorería sin poder resolver a quién pertenece un diezmo.
--
-- **`frenar_baja_tesorero` se queda**, y ahora se entiende por qué es
-- imprescindible: una política de tabla no distingue una edición de una baja.
-- El disparador sí — vigila la transición `activo 1→0` y `deleted false→true` y
-- la revierte para el tesorero en los planes `completo` y `secretaria`. Es
-- exactamente el hueco que deja el UPDATE abierto de arriba.
--
-- **Dos ayudantes nuevos, y `security definer` a propósito.** Leer `iglesias`
-- DENTRO de una política la somete a RLS: si la política de `iglesias` no casa,
-- la subconsulta devuelve `NULL`, el `OR` se vuelve `NULL` y la escritura se
-- descarta **sin un solo error**. Es el modo de fallo que costó semanas con
-- `iglesias` el 7-sep. Con `security definer` la lectura no pasa por RLS.
-- `btrim` en el plan porque `Permisos.swift` compara con
-- `trimmingCharacters(in: .whitespaces)` y los dos lados tienen que decir lo mismo.
--
-- ============================================================================
-- ENSAYADO el 16-sep en una transacción deshecha, tres escenarios × tres roles,
-- las 21 comprobaciones en verde, con un control que relee el estado real antes
-- de medir. Ese control hacía falta: el primer ensayo dio dos falsos rojos
-- porque `iglesias_congelar_administradas` REVIERTE EN SILENCIO
-- `tesorero_ve_padron` salvo que la sesión lleve `tamio.permisos_por_rpc = 'on'`
-- —la marca que pone `fijar_permisos_tesoreria`—. Un escenario que no se
-- comprueba no es un escenario.
-- ============================================================================

create or replace function public.mi_plan() returns text
language sql stable security definer set search_path = public
as $$ select btrim(i.plan) from public.iglesias i where i.id = (select public.mi_iglesia()) $$;
revoke all on function public.mi_plan() from public, anon;
grant execute on function public.mi_plan() to authenticated, service_role;

create or replace function public.mi_tesorero_ve_padron() returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(i.tesorero_ve_padron,false) from public.iglesias i where i.id = (select public.mi_iglesia()) $$;
revoke all on function public.mi_tesorero_ve_padron() from public, anon;
grant execute on function public.mi_tesorero_ve_padron() to authenticated, service_role;

-- ALTA y BAJA del padrón: trabajo de Secretaría.
alter policy members_insert on public.members
  with check (church_id = (select public.mi_iglesia())
              and ((select public.mi_rol()) <> 'tesorero' or (select public.mi_plan()) = 'tesoreria'));
alter policy members_delete on public.members
  using (church_id = (select public.mi_iglesia())
         and ((select public.mi_rol()) <> 'tesorero' or (select public.mi_plan()) = 'tesoreria'));

-- EDITAR una ficha: también el tesorero, si la iglesia le abrió el padrón.
alter policy members_update on public.members
  using (church_id = (select public.mi_iglesia())
         and ((select public.mi_rol()) <> 'tesorero' or (select public.mi_plan()) = 'tesoreria'
              or (select public.mi_tesorero_ve_padron())))
  with check (church_id = (select public.mi_iglesia())
              and ((select public.mi_rol()) <> 'tesorero' or (select public.mi_plan()) = 'tesoreria'
                   or (select public.mi_tesorero_ve_padron())));

-- PARENTESCOS: añadir o quitar un pariente ES editar la ficha.
alter policy parentescos_insert on public.parentescos
  with check (church_id = (select public.mi_iglesia())
              and ((select public.mi_rol()) <> 'tesorero' or (select public.mi_plan()) = 'tesoreria'
                   or (select public.mi_tesorero_ve_padron())));
alter policy parentescos_update on public.parentescos
  using (church_id = (select public.mi_iglesia())
         and ((select public.mi_rol()) <> 'tesorero' or (select public.mi_plan()) = 'tesoreria'
              or (select public.mi_tesorero_ve_padron())))
  with check (church_id = (select public.mi_iglesia())
              and ((select public.mi_rol()) <> 'tesorero' or (select public.mi_plan()) = 'tesoreria'
                   or (select public.mi_tesorero_ve_padron())));
alter policy parentescos_delete on public.parentescos
  using (church_id = (select public.mi_iglesia())
         and ((select public.mi_rol()) <> 'tesorero' or (select public.mi_plan()) = 'tesoreria'
              or (select public.mi_tesorero_ve_padron())));
