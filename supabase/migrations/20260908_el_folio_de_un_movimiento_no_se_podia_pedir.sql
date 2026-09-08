-- **Desde el 7 de septiembre a las 15:21 UTC, ningún ingreso ni gasto podía
-- subir desde el teléfono.** APLICADA el 8 de septiembre de 2026, y verificada
-- ANTES de que ningún aparato la usara, con el bloque que se deshace solo del
-- final de este archivo: el contador de `gasto` estaba en 2, `siguiente_folio`
-- devolvió **3**, y el `raise` lo dejó otra vez en 2 con su marca de tiempo
-- intacta. Antes de esto, esa misma llamada levantaba 42P10.
--
-- Lo destapó Iván el 8 de septiembre: capturó dos gastos de prueba, la
-- definición del recurrente subió y el movimiento no. Ajustes decía
-- "Sin subir: 2 cambios", pulsó "Sincronizar ahora", el estado volvió a poner
-- la fecha —o sea, éxito— y seguía diciendo 2. El fallo no se veía por ningún
-- lado.
--
-- En los logs de PostgREST está clarísimo:
--
--     POST /rest/v1/rpc/siguiente_folio  →  400
--
-- decenas de veces, dos por cada sincronización, sin una sola línea en los
-- logs de Postgres. Que no llegue a Postgres es la pista: el error lo da el
-- planificador antes de ejecutar nada.
--
-- **La causa.** `20260907_folios_por_serie_y_anio.sql` añadió la columna `anio`
-- a `folios_contador` y rehízo la clave primaria como
-- `(church_id, serie, anio)`. Escribió `siguiente_folio_anual` con su
-- `on conflict (church_id, serie, anio)`, correcto. Pero **dejó intacta la
-- `siguiente_folio` de antes**, que sigue diciendo:
--
--     on conflict (church_id, serie)
--
-- Dos columnas contra una clave de tres. Ya no hay índice único que case, así
-- que Postgres levanta `42P10: there is no unique or exclusion constraint
-- matching the ON CONFLICT specification` y PostgREST lo devuelve como 400.
--
-- Y esa es justo la que usan los movimientos: cartas y actas van por la anual
-- —sus contadores tienen `anio = 2026`—, mientras ingresos y gastos siguen en
-- una serie continua con `anio = 0`, que es lo correcto y no se cambia aquí.
-- Un folio de gasto no se reinicia en enero.
--
-- **La fecha cuadra sola.** El último folio de gasto que se entregó bien es el
-- 2, del 7 de septiembre a las 14:29:30. Los contadores de carta y acta llevan
-- la marca de las 15:21:20 de ese mismo día, que es cuando se aplicó la
-- migración anual. Todo lo de antes funcionó; nada de lo de después.
--
-- **Lo que esto significa, y por qué no es solo una prueba.** Cualquier ingreso
-- o gasto capturado en el teléfono desde ayer a las 15:21 está en la cola de
-- salida sin subir, y la app asegura que todo está sincronizado. No se ha
-- perdido nada —la cola no tira lo que no sale, reintenta— pero la contabilidad
-- del servidor lleva un día sin recibir movimientos y nadie tenía forma de
-- saberlo. Es exactamente el fallo silencioso que los seis arreglos de esta
-- misma tarde persiguen, ocurriendo de verdad mientras se arreglaba.
--
-- **La app no cambia.** iOS llama a la función correcta con los parámetros
-- correctos; la que está mal es ella. Actualizar el teléfono no arregla esto:
-- con la compilación nueva el fallo se VE —el estado pasa a "2 cambios no
-- pudieron subir: …"— pero el 400 sigue llegando igual.
--
-- El arreglo es alinear el `on conflict` con la clave que hay, y de paso poner
-- el `anio` explícito en el `insert` en vez de fiarlo al valor por omisión de
-- la columna: que la fila nazca con `anio = 0` es parte de lo que esta función
-- decide, no un detalle de la tabla.

create or replace function public.siguiente_folio(p_church_id uuid, p_serie text)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
    v_nuevo integer;
begin
    if p_serie not in ('ingreso', 'gasto') then
        raise exception 'Serie de folio no válida: %', p_serie;
    end if;

    -- SECURITY DEFINER salta RLS, así que la pertenencia se comprueba a mano.
    if not exists (
        select 1 from public.perfiles
        where id = auth.uid() and church_id = p_church_id
    ) then
        raise exception 'Sin acceso a esta iglesia';
    end if;

    -- **`anio = 0` explícito, y en el `on conflict` las TRES columnas de la
    -- clave.** Las series de movimiento no se reinician por año: el folio de un
    -- gasto es continuo desde que existe la iglesia. El cero es la marca de
    -- "esta serie no lleva año", no un año de verdad.
    insert into public.folios_contador as fc (church_id, serie, anio, ultimo)
    values (p_church_id, p_serie, 0, 1)
    on conflict (church_id, serie, anio)
    do update set ultimo = fc.ultimo + 1, updated_at = now()
    returning fc.ultimo into v_nuevo;

    return v_nuevo;
end;
$function$;

-- **Cómo comprobarlo sin gastar un folio de la iglesia**, que es lo que no
-- conviene hacer a ciegas sobre datos reales. Dentro de un bloque que se
-- deshace solo, como se hizo con `frenar_baja_tesorero` y con el disparador del
-- plan:
--
--     begin;
--       select public.siguiente_folio(
--                (select church_id from public.perfiles where id = auth.uid()),
--                'gasto');
--     rollback;
--
-- Antes de esta migración eso levanta `42P10`. Después devuelve el número
-- siguiente y el `rollback` lo deja como estaba. **Así se comprobó**, con un
-- `do $$ ... $$` que se hace pasar por un miembro —`set_config` de
-- `request.jwt.claims` con el uid de un perfil de la iglesia, que desde el
-- editor no hay `auth.uid()`— y termina en un `raise` que deshace el bloque
-- entero. El `raise` es la forma de que la prueba te CUENTE el número y no lo
-- gaste.
--
-- Desde el editor de SQL no hay `auth.uid()`, así que ahí la comprobación de
-- pertenencia rebota antes de llegar al `insert`. Para probarlo de verdad se
-- hace desde la app, o haciéndose pasar por un miembro con
-- `set local request.jwt.claims`.
--
-- **Y lo que hay que mirar después, que es la prueba de verdad:** que el
-- contador de la serie `gasto` avance de 2 en adelante, y que el "Sin subir"
-- del teléfono baje a 0 solo.

-- **Queda una cosa anotada y NO arreglada aquí**, porque no está rota hoy y
-- tocarla sin necesidad es peor: `folio_previsto` lee sin filtrar por `anio`
--
--     select ultimo into v_ultimo
--       from public.folios_contador
--      where church_id = p_church_id and serie = p_serie;
--
-- Hoy da igual —una serie de movimiento solo tiene la fila del año 0—, pero es
-- un `select into` que se traería una fila cualquiera si alguna vez hubiera
-- dos. Si alguien añade años a las series de movimiento, esto es lo primero
-- que hay que revisar.
