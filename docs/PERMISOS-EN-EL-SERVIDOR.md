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
- **Hace falta una cuenta de cada rol para probar.** Medido el 10-sep: en
  `perfiles` hay **cuatro administradores repartidos en tres iglesias y dos
  tesoreros**; **de secretaria no hay ninguna**. Así que falta esa, y crearla es
  además la prueba de que las invitaciones funcionan, que nunca se ha
  ejercitado. (Este apartado decía que solo existía la de administrador: ya no
  era verdad.)
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
