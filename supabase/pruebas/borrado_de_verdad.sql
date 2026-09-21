-- Qué puede BORRAR DE VERDAD cada rol, medido. No leído.
--
-- Acompaña a `20260919c_el_borrado_de_verdad_solo_alcanza_a_las_lapidas.sql`
-- (§5 de `docs/PERMISOS-EN-EL-SERVIDOR.md`). Se corre entero y acaba en
-- `rollback`: no deja nada escrito ni aunque falle a mitad.
--
-- **El orden: este guion ANTES, la migración, y este guion OTRA VEZ.** Antes
-- de aplicar, las dos filas «una fila VIVA» tienen que salir en `SI` para
-- quien escribe en esa área —ese es el agujero— y por tanto en
-- `### REVISAR`.
--
-- **No se puede correr en el editor SQL del panel**: pierde las tablas
-- temporales entre sentencias. `psql` o MCP.
--
-- ATENCIÓN AL CONTROL: corrido como `postgres` todo saldría permitido, porque
-- es el dueño de las tablas y además está exento del disparador. La primera
-- fila de cada rol dice con quién se midió.
--
-- LO QUE TIENE QUE DAR:
--
--   | caso                               | admin | tesorero | secretaria |
--   |------------------------------------|-------|----------|------------|
--   | 1 borrar un movimiento VIVO        | NO    | NO       | NO         |
--   | 2 borrar un movimiento CON LÁPIDA  | SI    | SI       | NO         |
--   | 3 borrar un acta VIVA              | NO    | NO       | NO         |
--   | 4 borrar un acta CON LÁPIDA        | SI    | NO       | SI         |
--
-- Los «NO» de las filas 1 y 3 no son todos iguales, y la columna `detalle` lo
-- enseña: a quien escribe en esa área se lo dice el DISPARADOR (`42501`), y a
-- quien no, la política, que descarta la fila y contesta **cero filas sin
-- error**. Los dos son un no; solo uno avisa. Por eso el guarda es un
-- disparador y no un `and deleted` en la política.
--
-- Y las dos últimas filas son de COBERTURA, que es lo que caza la tabla nueva
-- que nadie acordó proteger.

begin;

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

-- Sin esto el guion falla con `42501 permission denied for table _res`, que se
-- lee como si fallara el guarda que se está probando.
grant insert, select on _res to authenticated;

-- **Cuatro filas de prueba POR ROL**, sembradas como `postgres` —que salta RLS
-- a propósito: lo que se mide es el borrado, no la siembra—. Una viva y una
-- con lápida de cada área, para que ningún rol reciba «cero filas» solo
-- porque el anterior ya se llevó la fila por delante.
insert into public.transactions (uid, church_id, deleted)
select 'probe-tx-'||v.estado||'-'||q.rol, p.church_id, v.estado = 'lapida'
from _quien q join public.perfiles p on p.id = q.uid
cross join (values ('vivo'),('lapida')) as v(estado);

insert into public.actas (uid, church_id, deleted)
select 'probe-acta-'||v.estado||'-'||q.rol, p.church_id, v.estado = 'lapida'
from _quien q join public.perfiles p on p.id = q.uid
cross join (values ('vivo'),('lapida')) as v(estado);

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

    insert into _res values (u.rol, '0 control · usuario', current_user, 'authenticated',
                             'y mi_rol dice: '||coalesce(public.mi_rol(),'?'));

    -- 1. UN MOVIMIENTO VIVO. Nadie, y al de Tesorería se lo dice el disparador.
    begin
      delete from public.transactions where uid = 'probe-tx-vivo-'||u.rol and church_id = ch;
      get diagnostics n = row_count;
      insert into _res values (u.rol, '1 borrar un movimiento VIVO',
        case when n > 0 then 'SI' else 'NO (0 filas)' end, 'NO',
        case when n > 0 then 'lo borro entero, sin lapida y sin rastro' else 'la politica lo descarta: callado' end);
    exception when others then
      insert into _res values (u.rol, '1 borrar un movimiento VIVO', 'NO ('||SQLSTATE||')', 'NO',
        left(SQLERRM, 70)); end;

    -- 2. UN MOVIMIENTO CON LÁPIDA. Es la compactación del web.
    begin
      delete from public.transactions where uid = 'probe-tx-lapida-'||u.rol and church_id = ch;
      get diagnostics n = row_count;
      insert into _res values (u.rol, '2 borrar un movimiento CON LAPIDA',
        case when n > 0 then 'SI' else 'NO (0 filas)' end,
        case when u.rol = 'secretaria' then 'NO' else 'SI' end,
        'es lo que purga compactarBase');
    exception when others then
      insert into _res values (u.rol, '2 borrar un movimiento CON LAPIDA', 'NO ('||SQLSTATE||')',
        case when u.rol = 'secretaria' then 'NO' else 'SI' end, left(SQLERRM, 70)); end;

    -- 3. UN ACTA VIVA.
    begin
      delete from public.actas where uid = 'probe-acta-vivo-'||u.rol and church_id = ch;
      get diagnostics n = row_count;
      insert into _res values (u.rol, '3 borrar un acta VIVA',
        case when n > 0 then 'SI' else 'NO (0 filas)' end, 'NO',
        case when n > 0 then 'la borro entera, sin lapida y sin rastro' else 'la politica lo descarta: callado' end);
    exception when others then
      insert into _res values (u.rol, '3 borrar un acta VIVA', 'NO ('||SQLSTATE||')', 'NO',
        left(SQLERRM, 70)); end;

    -- 4. UN ACTA CON LÁPIDA.
    begin
      delete from public.actas where uid = 'probe-acta-lapida-'||u.rol and church_id = ch;
      get diagnostics n = row_count;
      insert into _res values (u.rol, '4 borrar un acta CON LAPIDA',
        case when n > 0 then 'SI' else 'NO (0 filas)' end,
        case when u.rol = 'tesorero' then 'NO' else 'SI' end,
        'es lo que purga compactarBase');
    exception when others then
      insert into _res values (u.rol, '4 borrar un acta CON LAPIDA', 'NO ('||SQLSTATE||')',
        case when u.rol = 'tesorero' then 'NO' else 'SI' end, left(SQLERRM, 70)); end;

    reset role;
    perform set_config('request.jwt.claims', NULL, true);
  end loop;
end $$;

-- COBERTURA. No depende del rol, así que va una vez y fuera del bucle.
insert into _res
select '—', '5 tablas con lapida SIN guarda',
       coalesce(string_agg(c.relname, ', ' order by c.relname), '0'), '0',
       'toda tabla con deleted tiene que llevar a1_solo_se_borra_lo_enterrado'
from pg_class c
join pg_namespace ns on ns.oid = c.relnamespace
where ns.nspname = 'public' and c.relkind = 'r'
  and c.relname <> 'registro'
  and exists (select 1 from information_schema.columns k
              where k.table_schema='public' and k.table_name=c.relname and k.column_name='deleted')
  and not exists (select 1 from pg_trigger t
                  where t.tgrelid = c.oid and t.tgname = 'a1_solo_se_borra_lo_enterrado');

insert into _res
select '—', '6 el registro sigue sin permiso de DELETE',
       case when count(*) = 0 then '0' else 'LO TIENE' end, '0',
       'su cierre es mas duro: ni las lapidas'
from information_schema.role_table_grants
where table_schema='public' and table_name='registro'
  and grantee in ('anon','authenticated') and privilege_type='DELETE';

select rol, caso, resultado, esperado,
       case when resultado like esperado||'%' then 'ok' else '### REVISAR' end as veredicto,
       detalle
from _res
order by case rol when 'administrador' then 1 when 'tesorero' then 2
                  when 'secretaria' then 3 else 4 end, caso;

rollback;
