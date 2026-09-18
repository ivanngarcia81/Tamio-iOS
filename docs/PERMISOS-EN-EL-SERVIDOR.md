# Los permisos, en el servidor · propuesta

**Escrito el 10 de septiembre de 2026.** La decisión es de Iván, y toca los dos
repos.

> **Revisado el 10-sep por la tarde, contrastándolo con el web.** El §1 está
> **aplicado** (migración `20260910c`). Los §4 y §5 **no se pueden aplicar tal
> como estaban escritos**: partían de una premisa falsa, y abajo va corregida
> con lo que se midió. Este aviso vale por sí solo: lo que sigue se escribió
> mirando únicamente el lado de iOS, que es el error que el propio apartado de
> riesgos avisaba de no cometer.

---

## Lo que hay hoy, medido

**89 políticas de seguridad en `public`. Ninguna mira el rol.** Ochenta y siete
filtran por iglesia, y todas tienen exactamente la misma forma:

```sql
church_id = (select church_id from perfiles where id = auth.uid())
```

O sea que el servidor garantiza **una sola cosa**: que no puedas tocar los datos
de otra congregación. Eso está bien y funciona. Del reparto por rol —el que
`Permisos.swift` razona con tanto cuidado, y que el web repite en `navegacion.ts`
y `plan.ts`— el servidor no sabe nada.

Lo único que sabe de roles son dos disparadores, y cubren un caso muy estrecho:

| | |
|---|---|
| `frenar_borrado_tesorero` | `transactions`, BEFORE **UPDATE** |
| `frenar_baja_tesorero` | `members`, BEFORE **UPDATE** |

Los dos solo se activan en la transición de alta a baja (`deleted` de falso a
verdadero, `activo` de 1 a 0) y solo para el rol `tesorero`.

## Qué deja abierto

Para cualquiera que tenga cuenta en la iglesia y hable con la API sin pasar por
la app —lo que cuesta un `curl` y la clave publicable, que viaja en el binario—:

- Una **secretaria** puede crear, editar y borrar movimientos. La app no le
  enseña Tesorería; la API sí.
- Un **tesorero** puede leer y escribir el padrón entero aunque
  `tesorero_ve_padron` esté apagado.
- Cualquiera puede escribir en **`registro`**, que es el rastro de auditoría, y
  además **borrar sus filas**: `registro_update` y `registro_delete` son tan
  permisivas como las demás. Un rastro que el auditado puede reescribir no es un
  rastro.
- **No hay ningún disparador de `DELETE`.** Los dos guardas miran `UPDATE`, así
  que frenan el borrado lógico y **no el de verdad**: un tesorero sin permiso
  para dar de baja un movimiento puede eliminar la fila entera, que además no
  deja rastro ni se propaga.

**Esto no contradice a `Permisos.swift`**: su propio comentario lo dice —*«esto
no es la barrera; la barrera está en Supabase»*—. El problema es que la barrera
casi no está.

**Y para hoy no cambia nada.** Con una sola iglesia, gente de confianza y datos
de prueba, el reparto por cliente basta. Esto es lo que hay que cerrar **antes de
que entre una iglesia que no es la tuya**, porque ahí «rol» tiene que significar
algo más que qué botones se ven.

---

## El principio

**El servidor repite la regla que los dos clientes ya comparten.** No se inventa
un modelo nuevo: `Permisos.swift` y `navegacion.ts` ya dicen lo mismo, y lo que
falta es que alguien lo haga cumplir. Cuando las tres versiones discrepen, manda
el servidor.

Las reglas, tal como ya están escritas en el cliente:

| Área | Administrador | Tesorero | Secretaria |
|---|---|---|---|
| Tesorería (movimientos, cortes, depósitos, categorías, recurrentes) | escribe | escribe | **nada** |
| Secretaría (actas, agenda, cartas, servicios, traslados, plantillas) | escribe | **nada** | escribe |
| Padrón (`members`, `parentescos`) | escribe | lee si `tesorero_ve_padron`; escribe solo en plan `tesoreria` | escribe |
| Reportes | lee | lee | **lee** |
| Registro (`registro`) | lee las dos áreas | lee la suya | lee la suya |
| Iglesia y permisos | escribe | lee | lee |

---

## Cómo quedaría

### 1. Dos ayudantes, y una sola vez por consulta

```sql
create or replace function public.mi_rol() returns text
language sql stable security definer set search_path = ''
as $$ select p.rol from public.perfiles p where p.id = (select auth.uid()) $$;

revoke all on function public.mi_rol() from public, anon;
grant execute on function public.mi_rol() to authenticated, service_role;
```

**Ojo con el `revoke`.** El borrador decía `revoke all ... from authenticated`, y
eso está mal: una política se evalúa con los permisos de QUIEN CONSULTA, así que
sin `execute` toda política que la use devuelve **cero filas y ningún error** —
el modo de fallo exacto contra el que avisa el apartado de riesgos—. `mi_iglesia()`
lo tiene concedido y por eso funciona. `anon` no lo necesita: sin sesión no hay rol.

**Aplicado y comprobado** (migración `20260910c`, en el servidor como
`20260910224221`), suplantando dentro de una transacción que se deshace:
`tesorero` → `tesorero`, `administrador` → `administrador`, y `anon` recibe
`42501: permission denied for function mi_rol`.

`stable` y **envuelto en `(select ...)` al usarlo**: sin eso la función se evalúa
una vez por fila y, según la propia guía de Supabase, eso cuesta un orden de
magnitud en tablas grandes. `mi_iglesia()` ya existe y hoy no se usa —las
políticas repiten la subconsulta a mano—; conviene unificarlo de paso.

### 2. Una política por tabla y por operación, con el área dentro

Para una tabla de Tesorería, `transactions`:

```sql
alter policy tx_select on public.transactions
  using (
    church_id = (select public.mi_iglesia())
    -- La secretaria SÍ lee: necesita las cifras del mes para las actas y para
    -- la junta. Es lo que ya dice `reportesSoloLectura`.
  );

alter policy tx_insert on public.transactions
  with check (
    church_id = (select public.mi_iglesia())
    and (select public.mi_rol()) in ('administrador', 'tesorero')
  );
-- update y delete, igual que insert.
```

Para una de Secretaría, `actas`, lo mismo cambiando la lista por
`('administrador','secretaria')`.

**Leer y escribir se separan a propósito.** La secretaria lee Tesorería porque la
app se lo ofrece; lo que no puede es tocarla. Cerrar también la lectura rompería
Reportes, que es una función real que hoy usa.

### 3. El padrón, que es el caso con excepciones

```sql
alter policy members_update on public.members
  using (
    church_id = (select public.mi_iglesia())
    and (
      (select public.mi_rol()) <> 'tesorero'
      or (select plan from public.iglesias where id = (select public.mi_iglesia())) = 'tesoreria'
    )
  );
```

Es `administraPadron` de `Permisos.swift` y `puedeCrearMiembros` del web, dicho
en SQL. La excepción del plan `tesoreria` no es un capricho: en ese plan no hay
Secretaría, y sin ella una iglesia no podría dar de alta a nadie.

Y donde ya existe `frenar_baja_tesorero`, **se queda**: cubre el matiz de que un
tesorero pueda editar una ficha pero no darla de baja, que una política de tabla
no distingue.

### 4. El registro, que solo debería crecer

> **CORREGIDO el 10-sep por la tarde. Esto NO se puede aplicar tal cual.**

Lo que decía este apartado —*«lo que la app hace hoy es insertar, así que
quitarlas no le quita nada»*— es **falso en los dos clientes**:

| Quién | Qué hace | Dónde |
|---|---|---|
| iOS | «Borrar todos los datos» encola bajas de `registro`, y el motor las manda como `UPDATE` | `BorradoMasivo.swift:39` y `MotorSincronizacion.swift:1049` |
| Web | `upsert` sobre `registro`, que **en conflicto es un UPDATE** | `sync.ts:1358`, vía `sincronizarTablaSimple` |
| Web | `compactarBase` hace un `DELETE` **de verdad** contra la nube, y su lista de tablas no excluye `registro` | `sync.ts:1822`, vía `tablasConDeleted` |

Y no fallaría en silencio: iOS envuelve cada escritura en `exigir(...)`, que
lanza cuando RLS descarta la fila. O sea que quitar las dos políticas rompe el
borrado masivo del teléfono, la subida del web y la compactación del web —las
tres a la vez y de forma visible.

**Lo que sí se puede hacer, y en este orden:**

1. **Decidir primero en el web** si `registro` deja de purgarse, alineándolo con
   `Compactacion.nuncaSePurga` de iOS, que ya lo protege. Es una decisión de
   producto y del otro repo: un rastro que el auditado puede purgar no es un
   rastro. **Sin esto, nada de lo de abajo se puede aplicar.**
2. Hecho eso, en vez de `drop policy registro_delete`, **quitarla de verdad** ya
   no rompe nada.
3. Para el `UPDATE`, no quitarlo: **acotarlo**. Lo único legítimo que cambia en
   un apunte ya escrito es la lápida. Un `BEFORE UPDATE` que rechace cualquier
   cambio en `tipo`, `area`, `datos`, `cuerpo`, `quien` y `creado_en`, dejando
   pasar `deleted` y `updated_at`, conserva el borrado masivo y cierra el hueco.
   **El nombre importa**: tiene que ordenar DESPUÉS de `a0_marcar_updated_at`,
   porque Postgres dispara los BEFORE por orden alfabético (§0.-8 del contexto).

Sigue siendo el agujero más feo y sigue valiendo la pena, pero cuesta más de lo
que este documento decía.

### 5. El borrado de verdad

Dos caminos, y prefiero el primero:

> **CORREGIDO el 10-sep por la tarde.** *«La app nunca borra de verdad»* es
> cierto **en iOS y falso en el web**. `compactarBase` (`sync.ts:1822`) hace
> `supabase.from(tabla).delete()` sobre toda tabla con `deleted` y `church_id`
> —hoy las 21 que tienen política de `DELETE`—. Quitarlas rompe la
> compactación del web entera.

- **Quitar la política de `DELETE` de las tablas de datos.** Cierra el hueco
  entero y a iOS no le quita nada, porque da de baja con `deleted`. **Pero hay
  que resolver antes qué hace el web con la compactación**: o la purga se mueve
  al servidor (una función `security definer` que compruebe el rol), o el web
  deja de purgar en la nube y lo hace solo en local.
- O añadir disparadores `BEFORE DELETE` que repitan lo de los de `UPDATE`. Más
  código, pero **no rompe al web**, que es la ventaja que antes no se veía.

---

## En qué orden

> **CORREGIDO el 10-sep.** El orden de abajo estaba escrito sobre la idea de
> que el §4 y el §5 «no tocan a la app». Los dos la tocan, y al web más. El
> orden bueno es este:

0. **`mi_rol()`** (§1). **HECHO** — migración `20260910c`.
1. **Una cuenta de secretaria**, que es la que falta y sin la que no se prueba
   nada de lo demás en condiciones.
2. **Escritura por área** (§2), que ahora es lo primero que se puede aplicar sin
   depender del otro repo. Tabla por tabla, empezando por `transactions` y
   `actas`. Cuidado con no cerrar la LECTURA de Tesorería a la secretaria:
   Reportes es una función real que hoy usa.
3. **El padrón** (§3), después, por las excepciones del plan.
4. **El registro y el borrado de verdad** (§4 y §5) **al final**, y solo cuando
   el web haya decidido qué hace con la compactación. Son los que más cierran y
   los únicos que necesitan acuerdo entre los dos repos.

El orden viejo, para que se vea por qué cambió: registro → borrado → escritura
por área → padrón. Se ordenó por «lo que menos rompe», y esa estimación estaba
hecha sin mirar `sync.ts`.

---

## Estado al 15 de septiembre

**Vuelto a medir contra el servidor, y el documento aguantó.** 89 políticas en
`public` sobre 23 tablas, ninguna menciona `mi_rol`; `mi_rol()` y `mi_iglesia()`
existen, las dos `stable security definer` con `execute` para `authenticated`; y
`mi_iglesia()` es **literalmente la misma subconsulta** que las 89 repiten a
mano, así que unificar no cambia semántica. En `perfiles`: 4 administradores en
3 iglesias, 2 tesoreros y 1 secretaria, y hay UNA iglesia que tiene los tres
roles — es la que sirve para comprobar.

Lo único que cambió es el tamaño de los datos: `transactions` pasó de 84 filas
el 12-sep a **114** el 15. Otra vez la misma lección — una medida caduca; la
forma del esquema, no.

**El §2 está APLICADO** (15-sep). Los dos archivos:

| archivo | qué es |
|---|---|
| `supabase/migrations/20260915_la_escritura_repartida_por_area.sql` | las 51 políticas de escritura de 17 tablas, con los nombres reales |
| `supabase/pruebas/permisos_por_area.sql` | la comprobación por rol, que hasta hoy no existía |

### El ensayo, hecho · 15-sep

**Probado a fondo en una transacción que se deshace**, aplicando el §2 a
`transactions` y `actas` y suplantando a un usuario de cada rol. Esto es lo que
hace la migración, medido y no leído:

| | administrador | tesorero | secretaria |
|---|---|---|---|
| leer un movimiento | SÍ | SÍ | **SÍ** ← Reportes se salva |
| crear un movimiento | SÍ | SÍ | **NO · 42501** |
| crear un acta | SÍ | **NO · 42501** | SÍ |
| borrar un acta | SÍ | **NO · 0 filas** | SÍ |

**Mirar la última casilla.** Al tesorero el borrado no le da error: le da **cero
filas**. Un `delete` cuyo `using` lo descarta afecta a cero filas y contesta 204.
Es el mismo modo de fallo que costó semanas con `iglesias` el 7-sep, y es la
razón por la que el guion distingue «NO · 42501» de «NO · 0 filas»: los dos son
un no, pero solo uno avisa.

**Y el ensayo encontró un fallo en el propio guion al primer intento**: sin un
`grant insert on _res to authenticated`, apuntar el resultado falla con
`42501 permission denied for table _res` — que se lee como si fallara la
política que se está probando. Mientras suplanta ya no es `postgres`, así que no
puede escribir ni en su tabla temporal. Corregido.

### APLICADO · 15 de septiembre de 2026

**Lo aplicó Iván desde el editor SQL del panel.** 51 de 51 políticas de
escritura usan ya `mi_rol()`, y **0 políticas de lectura tocadas** — Reportes de
la secretaria sigue entero, que era el riesgo.

Comprobado después con seis casos por rol, los dieciocho en `ok`:

| | administrador | tesorero | secretaria |
|---|---|---|---|
| leer un movimiento | SÍ | SÍ | **SÍ** |
| crear un movimiento | SÍ | SÍ | **NO · 42501** |
| borrar un corte | SÍ | SÍ | **NO · 0 filas** |
| crear evento de agenda | SÍ | **NO · 42501** | SÍ |
| borrar un acta | SÍ | **NO · 0 filas** | SÍ |

**Y el aviso de instrumento que costó tres intentos: el editor SQL del panel de
Supabase NO conserva una tabla temporal entre sentencias.** Va por un pool que
puede cambiar de conexión, así que `create temp table` seguido de un `insert`
falla con `42P01: relation "_quien" does not exist`. El guion de
`supabase/pruebas/permisos_por_area.sql` **no se puede correr ahí**: se corre
por una conexión que mantenga sesión (psql, o las herramientas MCP). Lo que sí
funciona en el panel es la migración, que son `alter policy` sueltos sin estado
compartido.

Se comprobó además que aquel fallo **no dejó nada escrito**: cero filas
`probe-%` en `actas`, `transactions` y `registro`.

**Y el orden al aplicar importa: primero el guion de pruebas, después la
migración, y el guion OTRA VEZ.** La primera pasada es el control negativo —si
ya dice que la secretaria no puede crear un movimiento, algo mide mal—. Corrido
como `postgres` el guion no vale y él mismo lo avisa en su primera fila: el
dueño de las tablas salta RLS.

### El §3, el padrón · APLICADO el 16 de septiembre de 2026

`supabase/migrations/20260916_el_padron_con_sus_excepciones.sql`.

**El §3 tal como estaba escrito arriba habría roto una función que existe.**
Proponía bloquear `members_update` entero al tesorero; pero `MembresiaView:41`
pasa `puedeDarDeBaja: administraPadron` a la hoja de EDICIÓN, o sea que un
tesorero con `tesorero_ve_padron` abre la ficha y la edita — lo que no puede es
dar de alta ni de baja. Y `onAgregarPariente`/`onQuitarPariente` (`:121-125`) no
están detrás de `administraPadron` en absoluto.

El reparto real es a TRES niveles:

| operación | quién |
|---|---|
| `members` INSERT / DELETE | administrador y secretaria; tesorero solo en plan `tesoreria` |
| `members` UPDATE | los anteriores **más** el tesorero si `tesorero_ve_padron` |
| `parentescos` (todo) | igual que `members` UPDATE |
| SELECT de las dos | **sin tocar** — Aportantes necesita los miembros |

**Aplicado y verificado sobre el servidor de verdad**, tres escenarios × tres
roles, **21 comprobaciones en verde**. Y comprobado después que la iglesia quedó
como estaba —`completo`, `vePadron=false`— y que no quedó ni una fila `probe-%`
ni un teléfono pisado: el ensayo mueve `plan` y `tesorero_ve_padron` para poder
medir, y los devuelve.

**Y el aviso que salió de ahí, que vale para cualquier prueba con escenarios:**
el primer ensayo dio **dos falsos rojos**. El escenario «vePadron ON» no era tal:
`iglesias_congelar_administradas` **revierte en silencio** `tesorero_ve_padron` y
`tesorero_puede_eliminar` salvo que la sesión lleve `tamio.permisos_por_rpc =
'on'` —la marca que pone `fijar_permisos_tesoreria`—. El `update` no daba error;
simplemente no ocurría. Desde entonces el ensayo **relee el estado y lo compara
con el que pidió** antes de medir nada. Un escenario que no se comprueba no es
un escenario, es una suposición con nombre.

(El mismo disparador congela `plan`, `sub_estado` y `sub_vence` para todo el que
no sea `service_role` o `postgres`. Por eso el escenario del plan sí funcionó.)

### Lo que se midió del web, que era el riesgo nº 2

`sync.ts` **no filtra por rol al subir**. Pero sube una fila solo si su copia
local es más nueva que la remota (`epoch(l.updated_at) > epoch(r.updated_at)`),
así que quien no toca un área no le escribe nada y el §2 no le rompe nada en
operación normal. Y si lo intentara, el `upsert` devuelve error y el web lo
enseña como fallo de sincronización: **visible, no silencioso**. Queda un caso
sin medir: la PRIMERA subida de un cliente con filas locales sin pareja remota
(la rama `!r`), que sí intentaría subirlas.

### Y una tabla que no es de nadie

**`mensajes` tiene 7 filas, política de las cuatro operaciones, y NINGUNA de las
dos apps la consulta.** No entra en el reparto por área porque meterla sería
inventarle un dueño. Merece una decisión aparte: o tiene uso y hay que
clasificarla, o no lo tiene y sobra.

## 🔴 Cualquier usuario podía hacerse administrador · encontrado el 18-sep

Lo encontró Iván revisando la base y es cierto punto por punto. Comprobado con
consultas, no de memoria:

| hecho | comprobado |
|---|---|
| `perfil_update_propio` deja actualizar la fila propia con `auth.uid() = id`, **sin decir nada de columnas** | `pg_policies` |
| `authenticated` tiene UPDATE sobre las **seis** columnas: `id, nombre, foto, rol, church_id, creado_en` | `information_schema.column_privileges` |
| `perfiles` **no tiene ningún disparador** — el único que la toca, `al_crear_usuario`, está en `auth.users` | `pg_trigger` |
| `mi_iglesia()` y `mi_rol()` leen `church_id` y `rol` **de esta misma tabla** | `pg_get_functiondef` |
| **58 de las 89 políticas** usan `mi_iglesia()`, **57** usan `mi_rol()` | `pg_policies` |

Juntos: un tesorero con sesión llama a la API, pone `rol = 'administrador'` en
su fila, y la política lo acepta porque la fila sigue siendo suya. Y `church_id`
igual: si conoce el UUID de otra iglesia, se muda a ella. **Toda la separación
por iglesia y todo el reparto por rol —lo de arriba entero— se apoyaban en dos
columnas que el propio usuario podía escribir.**

Lo que este documento decía en «Lo que hay hoy, medido» —que 87 políticas
comprueban `church_id` y eso «está bien y funciona»— era cierto y no servía:
comprobaban una columna que no estaba protegida.

**Y lo del `church_id` es anterior al reparto por rol.** El del 10-sep no abrió
el agujero: lo hizo más grave. Antes, con esa misma política, ya se podía saltar
de iglesia.

### El arreglo · `supabase/migrations/20260918_cualquier_usuario_podia_…sql`

Se quita el UPDATE de tabla y se concede solo sobre `nombre` y `foto`:

    revoke update on public.perfiles from anon, authenticated;
    grant  update (nombre, foto) on public.perfiles to authenticated;

No rompe nada legítimo, y está mirado en las dos apps: iOS no escribe nunca en
`perfiles`, el web hace un único `.update({ nombre, foto })` (`auth.ts`), y las
Edge Functions van con `service_role`, que no pasa por estos grants.

**La trampa que evita esa forma:** hacer solo `revoke update (rol, church_id)`
NO cierra nada. En Postgres un REVOKE por columna quita un GRANT por columna, no
recorta el de tabla; con el de tabla en pie las seis columnas siguen
escribibles y la migración parece aplicada. Primero se quita el de tabla, luego
se dan las dos columnas.

**Cómo se sabe que quedó cerrado:** con sesión de tesorero,
`update perfiles set rol = 'administrador' where id = auth.uid()` tiene que
fallar con **`42501: permission denied`**. Que devuelva «0 filas» sin error no
es cerrado: es RLS filtrando, y eso ya lo hacía con las filas ajenas.

**APLICADA y comprobada el 18-sep-2026, 14:47 UTC** (`20260918144751` en
`schema_migrations`). Las tres comprobaciones, contra la base:

- `column_privileges`: `authenticated` tiene UPDATE solo sobre **`foto, nombre`**;
  `anon` no tiene UPDATE.
- Con sesión de tesorero (`set local role authenticated` + `request.jwt.claims`),
  `update perfiles set rol = 'administrador' where id = auth.uid()` →
  **`42501: permission denied for table perfiles`**. Es el cierre bueno.
- Con la misma sesión, `update perfiles set nombre = … where id = auth.uid()` →
  pasa y devuelve la fila con `rol = tesorero`. Lo legítimo sigue funcionando.
  (Dentro de una transacción deshecha; la fila real no cambió, comprobado.)

## El barrido del 18-sep · ¿el mismo agujero en otra tabla?

Después de cerrar `perfiles` se buscó el mismo patrón en el resto del esquema
—columnas de las que dependen las políticas y que `authenticated` puede
escribir—, más lo que suele fallar alrededor. Todo contra la base, y lo que
pudo probarse con sesión se probó con sesión.

| qué se miró | resultado |
|---|---|
| RLS en las 24 tablas de `public` | **activo en todas** |
| Políticas por tabla | 22 con las cuatro operaciones; `perfiles` e `iglesias` sin INSERT/DELETE **a propósito** (las crea el disparador de alta y las borra la Edge Function); `folios_contador` con **cero**, ver abajo |
| UPDATE cuyo WITH CHECK no ate la iglesia | **solo `perfil_update_propio`**, ya cerrada |
| `iglesias`: grants de `authenticated` | UPDATE sobre las **32** columnas, `plan`, `sub_estado`, `sub_vence`, `tesorero_ve_padron` y `tesorero_puede_eliminar` incluidas… |
| …pero `iglesias` tiene disparador | **`iglesias_congelar_administradas`** (BEFORE UPDATE): revierte `id`, `plan`, `sub_estado` y `sub_vence` salvo para `service_role`/`postgres`, y los dos permisos del tesorero salvo con la marca `tamio.permisos_por_rpc` que pone `fijar_permisos_tesoreria` |
| Ese disparador, **probado** con sesión de tesorero | `update iglesias set plan='HACKEADO', sub_estado='activa', sub_vence='2099-12-31', tesorero_ve_padron=true, nombre='x'` → **devuelve la fila con `plan=completo`, `sub_estado=cortesia`, `sub_vence=null`, `ve_padron=false` y `nombre='x'`**. Congela lo administrado y deja pasar lo editable. Deshecho después. |
| Funciones `security definer` al alcance de `authenticated` (9) | `mi_iglesia`, `mi_rol`, `mi_plan`, `mi_tesorero_ve_padron`: solo leen. `siguiente_folio`, `folio_previsto` y sus `_anual`: comprueban pertenencia a `p_church_id` y lanzan `Sin acceso a esta iglesia`. `fijar_permisos_tesoreria`: exige `rol = 'administrador'` y lanza si no. **Ninguna abierta.** |
| `folios_contador` sin políticas | Intencional: solo la tocan los RPC de folio, y **ninguna de las dos apps la consulta directamente** (grep en iOS y en `Tamio-app/src`: cero). RLS sin políticas deniega todo a `authenticated`, que es lo que se quiere. |
| Avisos de Supabase (`get_advisors`, security) | 1 INFO (`folios_contador`, lo de arriba); 9 WARN por las funciones `security definer` (revisadas una a una, arriba); 1 WARN por contraseñas filtradas (**pide plan Pro**, §E del contexto, ya sabido) |

**Conclusión:** el de `perfiles` era el único. `iglesias` tenía los grants
igual de abiertos pero **estaba protegida por otra capa**, y esa capa funciona.

### Lo que el barrido deja, y no es un agujero

**La protección de `iglesias` es silenciosa.** Un tesorero que escriba
`plan = 'completo'` recibe *«1 fila actualizada»* y nada cambia. No es un
fallo de seguridad —el valor no se mueve— pero es exactamente el patrón que
«Los riesgos» de abajo advierte: la escritura descartada sin un solo mensaje.
Un `revoke update` sobre esas cinco columnas convertiría el silencio en un
`42501`, y **sería seguro**: iOS (`IglesiaUpdate`) no las sube, el web
(`COLUMNAS_IGLESIA` en `sync.ts`) tampoco, y el webhook de pagos va con
`service_role`. Es defensa en profundidad, no urgencia; se hace cuando se
quiera y con la misma forma que la de `perfiles` (fuera el grant de tabla,
dentro las columnas editables).

### Lo que un QA de verdad tiene que añadir a esto

Este barrido mira la ESTRUCTURA: qué columnas se pueden escribir y qué políticas
las leen. Lo que **no** mira es si cada política deja hacer exactamente lo que
la tabla de «Cómo se comprueba» dice que debe dejar. Esa tabla —rol × tabla ×
operación— **sigue sin rellenarse**, y es el QA que falta. Se puede escribir
como un guion: `set local role authenticated` + `request.jwt.claims` de un
usuario de cada rol, una operación por celda, dentro de una transacción que se
deshace, y que **falle** cuando una celda dé lo contrario de lo esperado. Sin
eso, lo de hoy demuestra que no hay puertas abiertas; no demuestra que cada
puerta esté donde el diseño dice.

**Y las tres cuentas para probarla ya existen.** Este párrafo decía el 18-sep
que faltaba la de secretaria «medido el 10-sep y sigue igual», y era falso:
**`Ivang`, rol `secretaria`, existe desde el 11-sep** —lo dijo Iván, y estaba en
la propia consulta de `perfiles` de ese día—. Repetir una medida vieja como si
fuera de hoy es justo lo que este documento le reprocha a otros. Hoy hay
administradores, tesoreros y una secretaria, y la de secretaria está en la
misma iglesia que los otros dos roles, así que la tabla entera es probable.

## Los riesgos, que son reales

- **Una política mal escrita no da error: devuelve cero filas o descarta la
  escritura en silencio.** Es exactamente lo que ya pasó con `iglesias` el 7 de
  septiembre —RLS activo, sin política de UPDATE, y todo lo que se escribía en
  Ajustes · Iglesia se perdía sin un solo mensaje—. Cada tabla que se toque hay
  que probarla con una sesión de cada rol, no leyendo el SQL.
- **El web usa la misma base.** Si escribe en algo que su rol no debería, dejará
  de funcionar el día que esto se aplique. Hay que mirar `sync.ts` y `export.ts`
  antes, no después.
- **Las Edge Functions y los RPC no pasan por RLS** si son `security definer`.
  `invitar-usuario`, `siguiente_folio` y `fijar_permisos_tesoreria` hay que
  revisarlos aparte: ahí la comprobación va dentro de la función.
- **Hace falta una cuenta de cada rol para probar, y ya están las tres.**
  Medido el 10-sep había cuatro administradores en tres iglesias y dos
  tesoreros, y de secretaria ninguna. **Desde el 11-sep hay una** (`Ivang`,
  creada por invitación, así que la invitación quedó ejercitada de paso). Este
  punto se leyó el 18-sep como si siguiera vigente y se escribió más abajo que
  faltaba; corregido el mismo día. Una medida lleva fecha por esto.
- **Y no hace falta una cuenta para todo.** Con `set local role authenticated` y
  `request.jwt.claims` dentro de una transacción que se deshace se prueban las
  tres vistas del mundo desde el servidor. Está ejercitado y funciona: es como
  se comprobó `mi_rol()`.

## Cómo se comprueba

Con `set local role authenticated` y `request.jwt.claims` fijados a un usuario de
cada rol, dentro de una transacción que se deshace. Eso permite probar las tres
vistas del mundo sin tres teléfonos, y es lo que convierte esto de "escribí unas
políticas" en "comprobé qué deja hacer cada rol".

La tabla que hay que rellenar, y que hoy no existe:

| | administrador | tesorero | secretaria |
|---|---|---|---|
| leer un movimiento | ✅ | ✅ | ✅ |
| crear un movimiento | ✅ | ✅ | ❌ |
| borrar un acta | ✅ | ❌ | ✅ |
| editar el padrón | ✅ | según plan | ✅ |
| escribir en el registro | ❌ | ❌ | ❌ |
