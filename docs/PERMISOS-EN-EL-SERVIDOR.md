# Los permisos, en el servidor · propuesta

**Escrito el 10 de septiembre de 2026.** No está aplicado: es lo que habría que
hacer y con qué orden. La decisión es de Iván, y toca los dos repos.

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

revoke all on function public.mi_rol() from public, anon, authenticated;
```

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

```sql
drop policy registro_update on public.registro;
drop policy registro_delete on public.registro;
```

Sin sustituirlas por nada. Un apunte de auditoría se escribe una vez y no se
toca; lo que la app hace hoy es insertar, así que quitarlas no le quita nada. Y
la lectura se acota al área del rol, igual que ya hace `areasDelRegistro`.

Esto por sí solo ya vale la pena aunque no se haga nada más.

### 5. El borrado de verdad

Dos caminos, y prefiero el primero:

- **Quitar la política de `DELETE` de las tablas de datos.** La app nunca borra
  de verdad —da de baja con `deleted`, que es lo que permite propagar la baja—,
  así que no pierde nada y se cierra el hueco entero.
- O añadir disparadores `BEFORE DELETE` que repitan lo de los de `UPDATE`. Más
  código para el mismo fin.

---

## En qué orden

Por relación entre lo que cierra y lo que puede romper:

1. **El registro** (§4). No toca a la app y cierra el agujero más feo.
2. **El borrado de verdad** (§5). Mismo argumento: la app no lo usa.
3. **Escritura por área** (§2). Es el grueso. Se puede ir tabla por tabla
   empezando por `transactions` y `actas`, que son las dos más claras.
4. **El padrón** (§3). El último porque es el que tiene excepciones y el que más
   fácil se equivoca.

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
- **Hace falta una cuenta de cada rol para probar.** Hoy solo existe la de
  administrador, así que el primer paso real es crear una de tesorero y una de
  secretaria — que además es la prueba de que las invitaciones funcionan, que
  tampoco se ha ejercitado nunca.

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
