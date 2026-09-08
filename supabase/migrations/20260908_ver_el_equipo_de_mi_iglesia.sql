-- **El administrador no podía ver quién está en su iglesia.** NO APLICADA: la
-- corre Iván.
--
-- **Ensayada entera contra la base el 8-sep-2026**, dentro de un bloque que
-- termina en `raise` y no deja nada puesto. Haciéndose pasar por el
-- administrador de la iglesia real:
--
--   * antes veía **1** perfil (el suyo);
--   * después ve **4**, que es su equipo entero;
--   * y de otra iglesia sigue viendo **0**.
--
-- Comprobado después que ni la política ni la función quedaron creadas. La
-- recursión que se temía no aparece: la función `security definer` la corta.
--
-- `perfiles` tenía UNA sola política de lectura, `leer_propio_perfil`, con
-- `auth.uid() = id`. O sea: cada quien ve su fila y nada más. Un administrador
-- puede invitar, pero no puede comprobar a quién invitó, ni si sigue dentro, ni
-- con qué rol. Para una app que se vende con tres roles, eso se nota.
--
-- **No es un hueco de iOS: es de las dos apps.** La pantalla de usuarios del
-- app web tampoco lee la nube —su lista sale de la base LOCAL—, así que las
-- dos enseñan lo mismo: a ti.
--
-- **El escollo, y por qué hace falta la función.** Lo natural sería:
--
--     using (church_id = (select church_id from perfiles where id = auth.uid()))
--
-- y eso revienta: una política sobre `perfiles` que consulta `perfiles` entra
-- en recursión y PostgreSQL corta con "infinite recursion detected in policy".
-- Las demás políticas del proyecto usan esa forma sin problema porque están en
-- OTRAS tablas. Aquí hace falta una función `security definer`, que lee
-- saltándose RLS y rompe el ciclo.
create or replace function public.mi_iglesia()
returns uuid
language sql
stable
security definer
set search_path to 'public'
as $$
  select church_id from public.perfiles where id = auth.uid()
$$;

-- Se puede llamar estando dentro; no la necesita `anon`.
revoke execute on function public.mi_iglesia() from anon;

-- **Quién ve a quién: cualquier miembro ve a los de SU iglesia.**
--
-- Se consideró dejarlo solo al administrador y se descartó: saber quién más
-- puede ver la contabilidad de la congregación no es un privilegio de mando,
-- y un tesorero que no puede comprobarlo está peor informado que el resto.
--
-- Lo que se expone es poco y ya se conoce dentro de una iglesia: `perfiles`
-- solo guarda nombre, rol, foto y fecha de alta. **El correo NO está aquí**
-- —vive en `auth.users`, que el cliente no toca—, así que esta política no lo
-- descubre.
--
-- Cambiar a alguien de rol sigue siendo cosa del administrador: eso pasa por
-- la Edge Function `invitar-usuario`, que lo comprueba. Esto es solo LEER.
create policy leer_perfiles_de_mi_iglesia on public.perfiles
  for select
  using (church_id = public.mi_iglesia());

-- La de siempre se queda: sin ella, alguien cuyo perfil aún no tiene iglesia
-- —el hueco entre registrarse y ser invitado— no podría leerse ni a sí mismo.
