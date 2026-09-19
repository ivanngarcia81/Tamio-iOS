-- Qué deja hacer cada rol con el RASTRO DE AUDITORÍA, medido. No leído.
--
-- Acompaña a `supabase/migrations/20260919_el_registro_solo_crece.sql` (§4 de
-- `docs/PERMISOS-EN-EL-SERVIDOR.md`). Se corre ENTERO y de una vez: acaba en
-- `rollback`, así que no deja nada escrito ni aunque algo falle a mitad.
--
-- **El orden importa: este guion ANTES, la migración, y este guion OTRA VEZ.**
-- La primera pasada es el control negativo. Antes de aplicar, la fila
-- «2 reescribir un apunte ajeno» tiene que salir en `SI` y por tanto en
-- `### REVISAR` para los tres roles; si ya sale en `ok` antes de aplicar
-- nada, el guion está midiendo mal.
--
-- **NO se puede correr en el editor SQL del panel de Supabase.** Ese editor va
-- por un pool que puede cambiar de conexión entre sentencias y pierde las
-- tablas temporales (`42P01`). Hace falta `psql` o las herramientas MCP. La
-- MIGRACIÓN sí va en el panel: son sentencias sueltas sin estado compartido.
--
-- ATENCIÓN AL CONTROL: si sale que todo el mundo puede todo, lo más probable
-- NO es que el guarda esté mal, sino que se está corriendo como `postgres`,
-- que salta RLS por ser el dueño y además está exento del disparador a
-- propósito. La primera fila de cada rol lo dice.
--
-- LO QUE TIENE QUE DAR, para los TRES roles:
--
--   | caso                                   | antes      | después     |
--   |----------------------------------------|------------|-------------|
--   | 1 escribir un apunte nuevo             | SI         | SI          |
--   | 2 reescribir un apunte ajeno           | SI  ← hoy  | NO (42501)  |
--   | 3 mudar el apunte a otra iglesia       | NO (42501) | NO (42501)  |
--   | 4 poner la lápida (deleted)            | SI         | SI          |
--   | 5 el upsert idéntico del web           | SI         | SI          |
--   | 6 '' donde había null                  | SI         | SI          |
--   | 7 borrar un apunte                     | SI         | SI ← §4 no lo cierra |
--
-- Las filas 1, 4 y 5 son las que hay que mirar con MÁS cuidado que la 2: son
-- las que dicen que no se rompió nada. La 1 porque la bitácora la escriben las
-- dos áreas desde la app (`anotarSuceso` lo llaman `OfflineDepositosRepository`
-- y `ActasRepository`, entre otros: si el tesorero no pudiera insertar, los
-- apuntes de tesorería dejarían de existir). La 4 porque es «Borrar todos los
-- datos» del teléfono. La 5 porque es lo que el web manda en cada
-- sincronización.
--
-- La 3 ya dice que no HOY, pero lo dice RLS (el WITH CHECK de la política) y
-- después lo dirá el disparador: mirar la columna `detalle` para ver cuál de
-- los dos contestó.
--
-- La 7 es honesta a propósito: el §4 no cierra el borrado. Sigue siendo `SI`
-- después de aplicar, y así tiene que salir hasta que el web decida qué hace
-- con la compactación.

begin;

-- Los usuarios se BUSCAN, no se escriben aquí: son cuentas reales y este
-- archivo va a un repo. Se coge la iglesia que tenga los TRES roles; si no hay
-- ninguna, el guion se planta en vez de medir a medias.
create temp table _quien(rol text, uid uuid) on commit drop;

insert into _quien
select p.rol, min(p.id::text)::uuid
from public.perfiles p
where p.church_id = (
  select church_id from public.perfiles
  group by church_id
  having count(distinct rol) = 3
  limit 1)
group by p.rol;

do $$
begin
  if (select count(*) from _quien) <> 3 then
    raise exception 'No hay ninguna iglesia con los tres roles: el guion no puede medir.';
  end if;
end $$;

create temp table _res(rol text, caso text, resultado text, esperado text, detalle text)
  on commit drop;

-- Sin este `grant` el guion falla con `42501 permission denied for table _res`,
-- que se lee como si fallara el guarda que se está probando. Mientras suplanta
-- ya no es `postgres`, así que tampoco puede escribir en su tabla temporal.
grant insert, select on _res to authenticated;

-- La otra iglesia, para el caso de la mudanza. Tiene que ser una de VERDAD: un
-- uuid inventado daría `23503` por la clave foránea, que se leería como un «no
-- puede» y sería mentira.
create temp table _otra(id uuid) on commit drop;
insert into _otra
select i.id from public.iglesias i
where i.id <> (select p.church_id from public.perfiles p join _quien q on q.uid = p.id limit 1)
limit 1;

-- **Un apunte de prueba por rol y POR CASO.** Sin esto la prueba depende del
-- orden —el primer rol borra o marca la fila y los siguientes reciben «0
-- filas», que se lee como «no tiene permiso» y es mentira—. Lo costó el ensayo
-- del 15-sep con las actas.
--
-- Se siembran como `postgres`, que salta RLS a propósito: lo que se mide es lo
-- que se hace DESPUÉS con ellas, no la siembra. Y son filas propias, así que
-- esto no toca ningún apunte de verdad aunque alguien quite el `rollback`.
insert into public.registro (uid, church_id, tipo, area, datos, cuerpo, quien, creado_en, deleted)
select 'probe-reg-'||q.rol||'-'||c.caso, p.church_id,
       'movEliminado', 'tesoreria', '{"folio":"T-0001"}',
       case when c.caso = 'vacio' then null else 'cuerpo original' end,
       'Otra persona', '2026-01-01T00:00:00Z', false
from _quien q
join public.perfiles p on p.id = q.uid
cross join (values ('reescribir'),('mudar'),('lapida'),('upsert'),('vacio'),('borrar')) as c(caso);

do $$
declare
  u record;
  ch uuid := (select p.church_id from public.perfiles p join _quien q on q.uid = p.id limit 1);
  otra uuid := (select id from _otra);
  n int;
begin
  for u in select * from _quien loop
    perform set_config('request.jwt.claims',
                       json_build_object('sub', u.uid, 'role','authenticated')::text, true);
    set local role authenticated;

    -- El control va DENTRO del bloque que suplanta: medido fuera diría siempre
    -- `postgres` —porque `reset role` ya corrió— y avisaría en falso.
    insert into _res values (u.rol, '0 control · usuario', current_user, 'authenticated',
                             'y mi_rol dice: '||coalesce(public.mi_rol(),'?'));

    -- 1. ESCRIBIR un apunte nuevo. Sigue abierto A PROPÓSITO: la bitácora la
    --    escribe la app, desde las dos áreas. Cerrarlo la vaciaría.
    begin
      insert into public.registro (uid, church_id, tipo, area, datos, quien, creado_en)
        values ('probe-reg-nuevo-'||u.rol, ch, 'notaLibre', 'general', '{}',
                'prueba', '2026-09-19T00:00:00Z');
      insert into _res values (u.rol, '1 escribir un apunte nuevo', 'SI', 'SI',
                               'la app anota desde tesoreria y secretaria');
    exception when others then
      insert into _res values (u.rol, '1 escribir un apunte nuevo', 'NO ('||SQLSTATE||')', 'SI',
                               left(SQLERRM, 70)); end;

    -- 2. REESCRIBIR un apunte ajeno. ESTE es el §4.
    begin
      update public.registro set quien = 'REESCRITO', tipo = 'movCreado', cuerpo = 'esto nunca paso'
        where uid = 'probe-reg-'||u.rol||'-reescribir' and church_id = ch;
      get diagnostics n = row_count;
      insert into _res values (u.rol, '2 reescribir un apunte ajeno',
        case when n > 0 then 'SI' else 'NO (0 filas)' end, 'NO (42501)', null);
    exception when others then
      insert into _res values (u.rol, '2 reescribir un apunte ajeno', 'NO ('||SQLSTATE||')',
        'NO (42501)', left(SQLERRM, 70)); end;

    -- 3. MUDAR el apunte a otra iglesia.
    if otra is null then
      insert into _res values (u.rol, '3 mudar el apunte a otra iglesia', 'sin medir',
        'sin medir', 'no hay una segunda iglesia en la base');
    else
      begin
        update public.registro set church_id = otra
          where uid = 'probe-reg-'||u.rol||'-mudar' and church_id = ch;
        get diagnostics n = row_count;
        insert into _res values (u.rol, '3 mudar el apunte a otra iglesia',
          case when n > 0 then 'SI' else 'NO (0 filas)' end, 'NO (42501)', null);
      exception when others then
        insert into _res values (u.rol, '3 mudar el apunte a otra iglesia', 'NO ('||SQLSTATE||')',
          'NO (42501)', left(SQLERRM, 70)); end;
    end if;

    -- 4. PONER LA LÁPIDA. Tiene que seguir pasando: es «Borrar todos los
    --    datos» del teléfono, y si se rechazara, `exigir(...)` lanza y la
    --    operación se queda reintentando en la cola para siempre.
    begin
      update public.registro set deleted = true
        where uid = 'probe-reg-'||u.rol||'-lapida' and church_id = ch;
      get diagnostics n = row_count;
      insert into _res values (u.rol, '4 poner la lapida (deleted)',
        case when n > 0 then 'SI' else 'NO (0 filas)' end, 'SI',
        'lo hace Borrar todos los datos'); 
    exception when others then
      insert into _res values (u.rol, '4 poner la lapida (deleted)', 'NO ('||SQLSTATE||')', 'SI',
        left(SQLERRM, 70)); end;

    -- 5. EL UPSERT IDÉNTICO DEL WEB. `set x = x` toma el valor VIEJO de la
    --    fila, que es justo lo que manda `sync.ts:1359` cuando sube un apunte
    --    que nadie editó. Si esto fallara, la sincronización del web se
    --    rompería en cada pasada.
    begin
      update public.registro
         set tipo = tipo, area = area, datos = datos, cuerpo = cuerpo,
             quien = quien, creado_en = creado_en, deleted = deleted
        where uid = 'probe-reg-'||u.rol||'-upsert' and church_id = ch;
      get diagnostics n = row_count;
      insert into _res values (u.rol, '5 el upsert identico del web',
        case when n > 0 then 'SI' else 'NO (0 filas)' end, 'SI',
        'sync.ts:1359 manda la fila entera'); 
    exception when others then
      insert into _res values (u.rol, '5 el upsert identico del web', 'NO ('||SQLSTATE||')', 'SI',
        left(SQLERRM, 70)); end;

    -- 6. '' DONDE HABÍA NULL. iOS sube el texto vacío como `null` y el web lo
    --    sube como ''. La misma fila viaja de las dos formas sin que nadie la
    --    haya editado, así que el guarda tiene que tolerarlo.
    begin
      update public.registro set cuerpo = ''
        where uid = 'probe-reg-'||u.rol||'-vacio' and church_id = ch;
      get diagnostics n = row_count;
      insert into _res values (u.rol, '6 poner '''' donde habia null',
        case when n > 0 then 'SI' else 'NO (0 filas)' end, 'SI',
        'iOS sube "" como null; el web lo deja en ""');
    exception when others then
      insert into _res values (u.rol, '6 poner '''' donde habia null', 'NO ('||SQLSTATE||')', 'SI',
        left(SQLERRM, 70)); end;

    -- 7. BORRAR un apunte. El §4 NO lo cierra: sigue en SI después de aplicar.
    begin
      delete from public.registro
        where uid = 'probe-reg-'||u.rol||'-borrar' and church_id = ch;
      get diagnostics n = row_count;
      insert into _res values (u.rol, '7 borrar un apunte',
        case when n > 0 then 'SI' else 'NO (0 filas)' end, 'SI',
        'pendiente: depende de la compactacion del web');
    exception when others then
      insert into _res values (u.rol, '7 borrar un apunte', 'NO ('||SQLSTATE||')', 'SI',
        left(SQLERRM, 70)); end;

    reset role;
    perform set_config('request.jwt.claims', NULL, true);
  end loop;
end $$;

select rol, caso, resultado, esperado,
       case when resultado like esperado||'%' then 'ok' else '### REVISAR' end as veredicto,
       detalle
from _res
order by case rol when 'administrador' then 1 when 'tesorero' then 2 else 3 end, caso;

rollback;
