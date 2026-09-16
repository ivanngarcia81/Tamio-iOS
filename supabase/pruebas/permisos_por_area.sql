-- Qué deja hacer cada rol, medido. No leído.
--
-- Rellena la tabla del §"Cómo se comprueba" de
-- `docs/PERMISOS-EN-EL-SERVIDOR.md`, que hasta hoy no existía. Se corre ENTERO
-- y de una vez: acaba en `rollback`, así que no deja nada escrito ni siquiera
-- si algo falla a mitad.
--
-- **Por qué esto y no tres teléfonos.** `set local role authenticated` más
-- `request.jwt.claims` dan las tres vistas del mundo desde el servidor. Es como
-- se comprobó `mi_rol()` el 10-sep.
--
-- **Por qué hay que correrlo, y no vale con leer el SQL de las políticas.** Una
-- política mal escrita NO da error: devuelve cero filas o descarta la escritura
-- en silencio. Es lo que pasó con `iglesias` el 7 de septiembre —RLS activo y
-- sin política de UPDATE— y nadie se enteró hasta que se miró una columna que
-- llevaba semanas congelada.
--
-- ATENCIÓN AL CONTROL NEGATIVO: si sale que todo el mundo puede todo, lo más
-- probable NO es que las políticas estén mal, sino que se está corriendo como
-- `postgres`, que las SALTA por ser el dueño de las tablas. La primera fila del
-- resultado lo dice.

-- LO QUE DIO EL ENSAYO DEL 15-sep, antes de aplicar nada (transacción deshecha):
--
--   |                    | admin | tesorero      | secretaria |
--   |--------------------|-------|---------------|------------|
--   | leer un movimiento | SI    | SI            | SI         |
--   | crear un movimiento| SI    | SI            | NO (42501) |
--   | crear un acta      | SI    | NO (42501)    | SI         |
--   | borrar un acta     | SI    | NO (0 filas)  | SI         |
--
-- **El último caso es el que hay que mirar con cuidado.** Al tesorero el
-- borrado no le da error: le da CERO FILAS. Un `delete` cuyo `using` lo
-- descarta afecta a cero filas y PostgREST contesta 204. Es el mismo modo de
-- fallo que costó semanas con `iglesias`, y por eso aquí se distingue
-- «NO (42501)» de «NO (0 filas)»: los dos son un no, pero solo uno avisa.

-- **NO se puede correr en el editor SQL del panel de Supabase.** Ese editor va
-- por un pool que puede cambiar de conexión entre sentencias, así que la tabla
-- temporal se pierde y sale `42P01: relation "_quien" does not exist`. Hace
-- falta una conexión que mantenga sesión: `psql`, o las herramientas MCP.
-- Costó tres intentos el 15-sep. La MIGRACIÓN sí va en el panel, porque son
-- `alter policy` sueltos y no comparten estado.

begin;

-- **Los usuarios se BUSCAN, no se escriben aquí.** Dos razones, y la primera
-- pesa más: son cuentas reales de la congregación y este archivo va a un repo.
-- La segunda es que escritos a mano caducan —basta que alguien cambie de rol— y
-- el guion se pondría a medir a quien no es sin decir nada.
--
-- Se coge la iglesia que tenga los TRES roles; si no hay ninguna, el guion se
-- planta en vez de medir a medias.
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
    raise exception 'No hay ninguna iglesia con los tres roles: el guion no puede medir. Faltan cuentas.';
  end if;
end $$;

create temp table _res(rol text, caso text, resultado text, esperado text) on commit drop;

-- **Sin este `grant` el guion no corre**, y el error engaña: dice
-- `42501: permission denied for table _res`, que se lee como si fallara la
-- POLÍTICA que se está probando cuando lo que falla es apuntar el resultado.
-- Mientras suplanta a `authenticated` ya no es `postgres`, así que tampoco
-- puede escribir en su propia tabla temporal. Lo encontró el ensayo del
-- 15-sep al primer intento.
grant insert, select on _res to authenticated;

-- **Un acta de prueba POR ROL, sembrada antes de empezar.** Sin esto la prueba
-- de borrado depende del ORDEN: el administrador corre primero, borra todas las
-- actas dentro de esta transacción, y los dos roles siguientes reciben «0 filas»
-- —que se lee como «no tiene permiso» y es mentira—. Lo dio el ensayo del
-- 15-sep: la secretaria salía sin poder borrar actas cuando sí puede.
--
-- Se siembran como `postgres`, que salta RLS a propósito: lo que se mide es el
-- BORRADO, no la siembra. Y son filas propias, así que la prueba no toca
-- ninguna acta de verdad aunque alguien quite el `rollback` del final.
insert into public.actas (uid, church_id)
select 'probe-acta-'||q.rol, p.church_id
from _quien q
join public.perfiles p on p.id = q.uid;

do $$
declare
  u record;
  ch uuid := (select p.church_id from public.perfiles p join _quien q on q.uid = p.id limit 1);
  n int;
begin
  for u in select * from _quien loop
    perform set_config('request.jwt.claims',
                       json_build_object('sub', u.uid, 'role','authenticated')::text, true);
    set local role authenticated;

    -- **El control, y va DENTRO a propósito.** Medido fuera del bloque que
    -- suplanta siempre diría `postgres` —porque `reset role` ya corrió— y
    -- avisaría en falso en cada corrida. Lo que hay que comprobar es con qué
    -- usuario se midieron las filas de abajo, no con cuál se lanzó el guion.
    insert into _res values (u.rol,'0 control · usuario',
      current_user, 'authenticated');

    -- LEER un movimiento. La secretaria SÍ: Reportes es una función que usa.
    begin
      select count(*) into n from public.transactions where church_id = ch;
      insert into _res values (u.rol,'leer un movimiento',
        case when n > 0 then 'SI' else 'NO ve ninguno' end, 'SI');
    exception when others then
      insert into _res values (u.rol,'leer un movimiento','ERROR '||SQLSTATE,'SI'); end;

    -- CREAR un movimiento. Solo administrador y tesorero.
    begin
      insert into public.transactions (uid, church_id)
        values ('probe-tx-'||u.rol||'-'||clock_timestamp()::text, ch);
      insert into _res values (u.rol,'crear un movimiento','SI',
        case when u.rol = 'secretaria' then 'NO' else 'SI' end);
    exception when others then
      insert into _res values (u.rol,'crear un movimiento','NO ('||SQLSTATE||')',
        case when u.rol = 'secretaria' then 'NO' else 'SI' end); end;

    -- BORRAR un acta. Solo administrador y secretaria.
    begin
      delete from public.actas where church_id = ch and uid = 'probe-acta-'||u.rol;
      get diagnostics n = row_count;
      insert into _res values (u.rol,'borrar un acta',
        case when n > 0 then 'SI' else 'NO (0 filas)' end,
        case when u.rol = 'tesorero' then 'NO' else 'SI' end);
    exception when others then
      insert into _res values (u.rol,'borrar un acta','NO ('||SQLSTATE||')',
        case when u.rol = 'tesorero' then 'NO' else 'SI' end); end;

    -- EDITAR el padrón. Hoy PASA para los tres: el §3 no está aplicado.
    begin
      update public.members set updated_at = now() where church_id = ch;
      get diagnostics n = row_count;
      insert into _res values (u.rol,'editar el padron',
        case when n > 0 then 'SI' else 'NO (0 filas)' end, 'segun plan (§3)');
    exception when others then
      insert into _res values (u.rol,'editar el padron','NO ('||SQLSTATE||')','segun plan (§3)'); end;

    -- ESCRIBIR en el registro. Hoy PASA para los tres: el §4 no está aplicado.
    begin
      insert into public.registro (uid, church_id)
        values ('probe-reg-'||u.rol||'-'||clock_timestamp()::text, ch);
      insert into _res values (u.rol,'escribir en el registro','SI','NO (pendiente §4)');
    exception when others then
      insert into _res values (u.rol,'escribir en el registro','NO ('||SQLSTATE||')',
                               'NO (pendiente §4)'); end;

    reset role;
    perform set_config('request.jwt.claims', NULL, true);
  end loop;
end $$;

-- Si alguna fila «0 control · usuario» dice `postgres`, la suplantación no
-- ocurrió: `postgres` es el dueño de las tablas y SALTA RLS, así que todo
-- saldría permitido y el resultado no valdría nada.

select rol, caso, resultado, esperado,
       case when resultado like esperado||'%' then 'ok' else '### REVISAR' end as veredicto
from _res
order by case rol when 'administrador' then 1 when 'tesorero' then 2 else 3 end, caso;

rollback;
