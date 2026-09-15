-- La escritura, repartida por área. El servidor no sabía de qué área es cada tabla.
--
-- Es el §2 de `docs/PERMISOS-EN-EL-SERVIDOR.md`, y el primero que se puede
-- aplicar sin depender del otro repo. Antes de esto, las 89 políticas de
-- `public` garantizaban UNA sola cosa —que no toques los datos de otra
-- congregación— y del reparto por rol no sabían nada: una secretaria que
-- hablara con la API sin pasar por la app podía crear, editar y borrar
-- movimientos, y un tesorero escribir el padrón entero.
--
-- **Lo que NO se toca, y es deliberado: la LECTURA.** Ninguna política de
-- SELECT cambia aquí. La secretaria tiene que seguir leyendo Tesorería porque
-- Reportes es una función real que hoy usa —necesita las cifras del mes para
-- las actas y para la junta—, y es lo que ya dicen `reportesSoloLectura` de
-- `Permisos.swift` y el orden de `navegacion.ts`. Cerrar la lectura "de paso"
-- rompería una pantalla que funciona.
--
-- **Qué se midió antes de escribir esto** (15-sep-2026, contra el proyecto
-- `hkpbkpojeierxqtbmagh`):
--
--   * 89 políticas en `public` sobre 23 tablas; NINGUNA menciona `mi_rol`.
--     El documento seguía siendo exacto cinco días después.
--   * `mi_rol()` y `mi_iglesia()` existen, las dos `stable security definer`
--     y con `execute` concedido a `authenticated` — que es lo que hace falta
--     para que una política que las use no devuelva cero filas en silencio.
--   * `mi_iglesia()` es LITERALMENTE la misma subconsulta que las 89 políticas
--     repiten a mano, así que sustituirla no cambia semántica y de paso deja
--     de evaluarse una vez por fila (envuelta en `(select ...)`).
--   * En `perfiles`: 4 administradores en 3 iglesias, 2 tesoreros y 1
--     secretaria. La iglesia `84c92ad0…` tiene los tres roles, que es la que
--     sirve para comprobar.
--
-- **Por qué esto no rompe al app web**, que bebe de la misma base y NO filtra
-- por rol al subir (`sync.ts`, `sincronizarTablaSimple`): sube una fila solo
-- si su copia local es más nueva que la remota
-- (`epoch(l.updated_at) > epoch(r.updated_at)`), así que quien no toca un área
-- no le escribe nada. Y si algún día lo intenta, `upsert` devuelve error y el
-- web lo enseña como fallo de sincronización — visible, no silencioso. El
-- riesgo que queda es la PRIMERA subida de un cliente con filas locales sin
-- pareja remota (`!r`), que sí intentaría subirlas.
--
-- **Lo que este archivo NO cubre**, a propósito:
--   * `members` y `parentescos` (§3): tienen la excepción del plan `tesoreria`
--     y van en su propia migración.
--   * `registro` (§4) y el borrado de verdad (§5): necesitan que el web decida
--     antes qué hace con `compactarBase`.
--   * `mensajes`: tiene 7 filas y política de las cuatro operaciones, pero
--     NINGUNA de las dos apps la consulta. Es una tabla huérfana y meterla en
--     un reparto por área sería inventarle un dueño.
--   * `iglesias` y `perfiles`, que no son de un área.
--
-- **Los dos disparadores que ya existen se quedan.** `frenar_borrado_tesorero`
-- y `frenar_baja_tesorero` cubren un matiz que una política de tabla no
-- distingue: que un tesorero pueda editar y no dar de baja.
--
-- ============================================================================
-- CÓMO SE COMPRUEBA. No leyendo este archivo: corriendo
-- `supabase/pruebas/permisos_por_area.sql`, que suplanta a un usuario de cada
-- rol dentro de una transacción que se deshace y rellena la tabla del §"Cómo
-- se comprueba" del documento. Una política mal escrita NO da error: devuelve
-- cero filas o descarta la escritura en silencio, que es exactamente lo que
-- pasó con `iglesias` el 7 de septiembre y costó semanas de datos perdidos.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- TESORERÍA · escriben administrador y tesorero; la secretaria lee y no toca.
-- ---------------------------------------------------------------------------
alter policy tx_insert on public.transactions
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy tx_update on public.transactions
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy tx_delete on public.transactions
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));

alter policy cortes_insert on public.cortes
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy cortes_update on public.cortes
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy cortes_delete on public.cortes
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));

alter policy corte_movs_insert on public.corte_movimientos
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy corte_movs_update on public.corte_movimientos
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy corte_movs_delete on public.corte_movimientos
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));

alter policy dep_insert on public.depositos_bancarios
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy dep_update on public.depositos_bancarios
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy dep_delete on public.depositos_bancarios
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));

alter policy categorias_custom_insert on public.categorias_custom
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy categorias_custom_update on public.categorias_custom
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy categorias_custom_delete on public.categorias_custom
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));

alter policy movimientos_recurrentes_insert on public.movimientos_recurrentes
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy movimientos_recurrentes_update on public.movimientos_recurrentes
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));
alter policy movimientos_recurrentes_delete on public.movimientos_recurrentes
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','tesorero'));

-- ---------------------------------------------------------------------------
-- SECRETARÍA · escriben administrador y secretaria; el tesorero no entra.
-- `plantillas` y `solicitudes` van aquí porque son de Cartas.
-- ---------------------------------------------------------------------------
alter policy actas_insert on public.actas
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy actas_update on public.actas
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy actas_delete on public.actas
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));

alter policy agenda_insert on public.agenda
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy agenda_update on public.agenda
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy agenda_delete on public.agenda
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));

alter policy cartas_insert on public.cartas
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy cartas_update on public.cartas
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy cartas_delete on public.cartas
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));

alter policy servicios_insert on public.servicios
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy servicios_update on public.servicios
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy servicios_delete on public.servicios
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));

alter policy roster_insert on public.servicio_asistencia
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy roster_update on public.servicio_asistencia
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy roster_delete on public.servicio_asistencia
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));

alter policy sv_orden_insert on public.servicio_orden
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy sv_orden_update on public.servicio_orden
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy sv_orden_delete on public.servicio_orden
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));

alter policy sv_puestos_insert on public.servicio_puestos
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy sv_puestos_update on public.servicio_puestos
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy sv_puestos_delete on public.servicio_puestos
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));

alter policy te_insert on public.traslados_entrada
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy te_update on public.traslados_entrada
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy te_delete on public.traslados_entrada
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));

alter policy ts_insert on public.traslados_salida
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy ts_update on public.traslados_salida
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy ts_delete on public.traslados_salida
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));

alter policy plantillas_insert on public.plantillas
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy plantillas_update on public.plantillas
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy plantillas_delete on public.plantillas
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));

alter policy solicitudes_insert on public.solicitudes
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy solicitudes_update on public.solicitudes
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'))
  with check (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
alter policy solicitudes_delete on public.solicitudes
  using (church_id = (select public.mi_iglesia())
         and (select public.mi_rol()) in ('administrador','secretaria'));
