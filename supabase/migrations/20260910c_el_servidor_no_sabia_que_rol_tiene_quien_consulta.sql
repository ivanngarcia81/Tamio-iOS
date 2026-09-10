-- El servidor no sabía qué rol tiene quien consulta.
--
-- `mi_iglesia()` ya existía y responde a la única pregunta que hoy sabe hacer
-- la base: de qué congregación eres. Del reparto por rol —el que
-- `Permisos.swift` y `navegacion.ts` razonan con tanto cuidado— aquí no había
-- nada. Esta función es el §1 de docs/PERMISOS-EN-EL-SERVIDOR.md; sola no
-- cambia ningún permiso, solo permite escribirlos después.
--
-- `stable` y con `search_path` fijado, igual que `mi_iglesia()`. Al usarla en
-- una política hay que envolverla en `(select public.mi_rol())`: sin eso
-- Postgres la evalúa una vez POR FILA.
create or replace function public.mi_rol() returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.rol from public.perfiles p where p.id = (select auth.uid())
$$;

-- El permiso va como el de `mi_iglesia()`: `authenticated` SÍ la ejecuta.
--
-- La propuesta decía `revoke all ... from authenticated`, y eso está mal: una
-- política se evalúa con los permisos de quien consulta, así que revocárselo
-- haría fallar TODA política que la use —y en silencio, devolviendo cero
-- filas, que es justo el modo de fallo contra el que avisa el propio
-- documento—. `anon` no la necesita: sin sesión no hay rol.
revoke all on function public.mi_rol() from public, anon;
grant execute on function public.mi_rol() to authenticated, service_role;
