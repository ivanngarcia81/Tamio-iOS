-- Un apunte del registro se podía reescribir: el rastro que el auditado edita
-- no es un rastro.
--
-- Es el §4 de `docs/PERMISOS-EN-EL-SERVIDOR.md`, pendiente desde el 10-sep.
-- Vuelto a medir contra la base el **19-sep-2026**, y sigue igual punto por
-- punto:
--
--   | hecho | dónde se vio |
--   |---|---|
--   | `registro_update` y `registro_delete` solo filtran `church_id`; ninguna menciona `mi_rol()` | `pg_policies` |
--   | `authenticated` tiene UPDATE sobre las DIEZ columnas, y DELETE de tabla | `column_privileges`, `role_table_grants` |
--   | `registro` tiene UN disparador, `a0_marcar_updated_at`, y no guarda nada | `pg_trigger` |
--
-- Y medido con sesión de tesorero (`set local role authenticated` +
-- `request.jwt.claims`, dentro de una transacción deshecha):
--
--   control: usuario=authenticated, mi_rol=tesorero
--   REESCRIBIR apunte ajeno (quien/tipo/cuerpo/area): SI (1 fila)
--   BORRAR    apunte ajeno:                           SI (1 fila)
--
-- O sea que el tesorero puede abrir el apunte que dice que él borró un
-- movimiento y cambiarle el autor, el tipo o el cuerpo.
--
-- ── Qué cierra esto, y qué NO ──────────────────────────────────────────────
--
-- Cierra la REESCRITURA. El borrado va al final de este archivo, comentado y
-- sin aplicar, porque depende de una decisión del web.
--
-- **Y hay que decirlo entero: mientras el DELETE siga abierto, esto no cierra
-- la falsificación, la encarece.** Quien pueda borrar la fila y volver a
-- insertarla con el mismo `uid` consigue lo mismo en dos pasos —la política de
-- INSERT solo mira la iglesia—. Lo que sí cierra es la reescritura de un
-- apunte VIVO, que es el caso que ocurre sin querer, el que una sincronización
-- puede provocar sola, y el único que no deja ni la huella de haber ocurrido.
--
-- ── Por qué compara VALORES y no columnas ──────────────────────────────────
--
-- Un disparador no puede saber qué columnas nombró el `update`: solo ve OLD y
-- NEW. Y da igual, porque comparar valores es además lo que las dos apps
-- necesitan. Las dos mandan la FILA ENTERA cuando tocan un apunte:
--
--   | quién | qué manda | dónde |
--   |---|---|---|
--   | iOS | `ApunteEscritura` con las nueve columnas, en `update` | `MotorSincronizacion.swift:1049` |
--   | web | `upsert` con `uid, church_id`, las seis de datos, `updated_at` y `deleted` | `sync.ts`, `sincronizarTablaSimple` |
--
-- Si los valores son los mismos —que es lo que pasa en una sincronización
-- normal, porque un apunte no se edita en ninguna de las dos apps— el
-- disparador no ve ningún cambio y deja pasar. Comparar columnas nombradas
-- habría roto las dos.
--
-- ── '' y NULL cuentan como lo mismo ────────────────────────────────────────
--
-- iOS convierte el texto vacío en `null` al subir (`func o(_:)` en
-- `ApunteEscritura`) y el web manda `l[c] ?? null`, que deja pasar el `''`.
-- Así que la misma fila puede viajar con `cuerpo = ''` desde un lado y con
-- `cuerpo = null` desde el otro sin que nadie haya editado nada. `coalesce(x,
-- '')` los iguala. No debilita el guarda: cambiar 'Ivan Garcia' por '' sigue
-- siendo un cambio y se rechaza; lo único que se tolera es la diferencia que
-- no lleva información.
--
-- ── Las dos columnas que SÍ pueden cambiar ─────────────────────────────────
--
-- `deleted` y `updated_at`, **y la lápida solo la pone un administrador**.
--
-- Tiene que poder ponerse: «Borrar los registros» del teléfono encola bajas de
-- `registro` y el motor las manda como UPDATE (`BorradoMasivo.swift:39`,
-- `IPhoneAjustesView.swift:1785`), igual que `borrarDatosIglesia` en el web
-- (`db.ts`), y si se rechazaran, `exigir(...)` lanza y la operación se
-- queda reintentando en la cola para siempre.
--
-- Y tiene que ser del administrador, porque **es lo que las dos apps ya dicen
-- y el servidor no sabía**: la Zona de riesgo está detrás de
-- `veAjuste(.zona) → rol == .administrador` en iOS (`Permisos.swift:129`) y
-- detrás de `esAdmin` en el web (`Configuracion.tsx`). Sin esta línea, el
-- §4 se quedaba a medias: nadie podría falsear un apunte, pero un tesorero
-- podría esconder el rastro entero llamando a la API.
--
-- Se comprobó que no hay ninguna otra vía: `reinicioDeFabrica` es **solo
-- local** —limpia el SQLite, las carpetas y las preferencias, y no encola
-- nada—, y el borrado de cuenta va por la Edge Function `borrar-cuenta`, que
-- corre con `service_role` y está exenta.
--
-- Se deja pasar también `deleted` de vuelta a falso. Es el camino de `.crear`,
-- que es un `upsert`: una fila recreada en local resucita su copia remota. No
-- falsifica nada —el contenido sigue congelado— y cerrarlo rompería ese
-- camino.
--
-- ── El nombre, que importa ─────────────────────────────────────────────────
--
-- Postgres dispara los BEFORE por orden alfabético. `a1_…` ordena después de
-- `a0_marcar_updated_at`, que es lo que hace falta: ese pone `updated_at` y
-- este lo tiene que ver ya puesto, no pisarlo ni juzgarlo. Es el mismo tropiezo
-- del 10-sep con `updated_at` y los guardas de rol (migración `20260910b`).
--
-- ── Quién no pasa por aquí ─────────────────────────────────────────────────
--
-- `postgres` y `service_role`: las Edge Functions, el webhook de pagos y las
-- migraciones tienen que poder corregir una fila. Es la misma exención que
-- `iglesias_congelar_administradas`. Lo que no se copia de aquel es el
-- silencio: este LANZA. Una escritura descartada sin un solo mensaje es el
-- modo de fallo contra el que avisa el propio documento, así que el rechazo
-- sale como `42501`, que es el que se ve desde la app y desde `curl`.

create or replace function public.el_registro_solo_crece()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
  cambio text;
begin
  if current_user in ('postgres', 'service_role') then
    return new;
  end if;

  cambio := case
    when new.uid       is distinct from old.uid       then 'uid'
    when new.church_id is distinct from old.church_id then 'church_id'
    when coalesce(new.tipo, '')      is distinct from coalesce(old.tipo, '')      then 'tipo'
    when coalesce(new.area, '')      is distinct from coalesce(old.area, '')      then 'area'
    when coalesce(new.datos, '')     is distinct from coalesce(old.datos, '')     then 'datos'
    when coalesce(new.cuerpo, '')    is distinct from coalesce(old.cuerpo, '')    then 'cuerpo'
    when coalesce(new.quien, '')     is distinct from coalesce(old.quien, '')     then 'quien'
    when coalesce(new.creado_en, '') is distinct from coalesce(old.creado_en, '') then 'creado_en'
  end;

  if cambio is not null then
    raise exception 'Un apunte del registro no se reescribe (cambiaba «%»)', cambio
      using errcode = '42501',
            hint = 'De un apunte ya escrito solo pueden cambiar deleted y updated_at.';
  end if;

  -- La lápida, que es lo único que puede cambiar, es cosa de administradores.
  if new.deleted is distinct from old.deleted
     and coalesce(public.mi_rol(), '') <> 'administrador' then
    raise exception 'Solo un administrador puede dar de baja un apunte del registro'
      using errcode = '42501',
            hint = 'Es la Zona de riesgo, que las dos apps ya reservan al administrador.';
  end if;

  return new;
end
$fn$;

comment on function public.el_registro_solo_crece() is
  'Guarda del §4 (19-sep-2026): de un apunte ya escrito solo pueden cambiar la lápida y updated_at. El contenido —tipo, area, datos, cuerpo, quien, creado_en— y la identidad —uid, church_id— quedan congelados para todo el que no sea postgres o service_role.';

drop trigger if exists a1_el_registro_solo_crece on public.registro;

create trigger a1_el_registro_solo_crece
  before update on public.registro
  for each row execute function public.el_registro_solo_crece();

-- ── Cómo se comprueba ──────────────────────────────────────────────────────
--
-- Con `supabase/pruebas/registro_solo_crece.sql`, y en este orden: el guion
-- ANTES (control negativo: la fila «reescribir» tiene que salir en SI y por
-- tanto en `### REVISAR`), esta migración, y el guion OTRA VEZ. Corrido como
-- `postgres` el guion no vale y él mismo lo avisa en su primera fila.
--
-- A mano, con sesión de tesorero, las dos caras:
--
--   update registro set quien = 'otro' where uid = '…';   -- 42501
--   update registro set deleted = true  where uid = '…';  -- pasa: es la lápida
--
-- Que la primera devuelva «0 filas» sin error NO sería estar cerrado: sería
-- RLS filtrando por iglesia, que es lo que ya hacía.

-- ── El borrado va en la migración de al lado ──────────────────────────────
--
-- `20260919b_el_registro_no_se_borra.sql`, que se aplica junto con esta. Aquí
-- se congela el CONTENIDO; allí se cierra el DELETE, que es lo que impide
-- borrar la fila y volver a insertarla con el mismo `uid` para conseguir lo
-- mismo en dos pasos. Una sin la otra deja el agujero a medias.
