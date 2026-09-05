# El padrón, según quien escribió la tabla

`public.members` y las demás tablas de Secretaría las creó el **app web**
(`~/Documents/Tamio-app`, React + Tauri), no esta app. La app de iOS llega
después y se sienta encima. Este documento recoge la semántica que el web da
por sentada y que **no se deduce mirando el esquema**: los nombres de columna no
dicen que tres de ellas se leen juntas, ni que las listas guardan claves y no
etiquetas.

Comprobado el 5 de septiembre de 2026 leyendo `src/db.ts`,
`src/components/fichaMiembro.ts` y `src/components/FichaMiembroModal.tsx` del
repo del web, y contra los datos reales del proyecto de Supabase.

---

## 1. El estado de una persona son TRES columnas, no una

`EstadoMiembro` de iOS —`activo`, `nuevo`, `traslado`, `baja`, `recibido`—
aplana en un solo enum lo que allí son tres campos, y ninguno de esos cinco
valores es el que el web espera leer.

| Columna | Qué es |
|---|---|
| `activo` (int 1/0) | **La bandera de la baja.** 1 = está; 0 = se fue |
| `estado_membresia` (text) | Dónde está dentro del registro, **solo mientras `activo = 1`** |
| `motivo_baja` (text) | Por qué se fue. De él se deriva la etiqueta que se enseña |

`estado_membresia` se elige a mano entre cuatro: **`activo`, `inactivo`,
`visitante`, `enProceso`**. Los otros tres —`trasladado`, `retirado`,
`fallecido`— **no se guardan**: los calcula `estadoDeBaja(motivo_baja)` al
pintar (`traslado → trasladado`, `fallecimiento → fallecido`, `retiro →
retirado`, y cualquier otro motivo → `baja`).

Dar de baja, en el web, es exactamente esto:

```sql
UPDATE members SET activo = 0, fecha_baja = ?, motivo_baja = ? WHERE ...
```

**`estado_membresia` ni se toca**, así que una persona de baja conserva el
estado que tuviera. En la base hay ahora mismo una fila así: `enProceso` con
`activo = 0`. Restaurar es el camino inverso: `activo = 1`, y las dos fechas a
NULL.

`motivo_baja` sale de un catálogo cerrado: **`traslado`, `fallecimiento`,
`retiro`, `disciplina`, `otro`**.

### Lo que esto significa para iOS, y que hoy está mal

`MotorSincronizacion.AportanteEscritura` **no manda `activo`** y escribe en
`estado_membresia` los valores del enum de iOS (`AportanteFila.texto`). O sea:

- Dar de baja a alguien desde el teléfono lo deja **`activo = 1`** en el
  servidor: el web lo sigue contando en el padrón activo.
- Escribe `"baja"`, `"traslado"`, `"nuevo"` y `"recibido"` en una columna cuyo
  vocabulario es otro.

**Todavía no ha pasado**: las ocho filas de la base traen valores del web
(`activo`/1 y `enProceso`/0), así que el daño es latente, no hecho. Pero está en
el código hoy, en Tesorería, y no en la parte de Membresía que falta escribir.

`nuevo` y `recibido` no tienen equivalente en el web y hay que decidir qué son
—probablemente `enProceso` y `activo` con `fecha_ingreso` puesta— antes de
escribir la sincronización del padrón.

---

## 2. Las listas guardan CLAVES, no etiquetas

`ministerios`, `ministerios_interes`, `cargos`, `instrumentos`, `habilidades` y
`etiquetas` son columnas `text` con un **array JSON** dentro (`'[]'` por
defecto). Lo que va dentro son claves de catálogo **sin acentos y en
minúscula**, o texto libre si la persona escribió el suyo — los catálogos son
ABIERTOS a propósito: "ninguna lista de seis casillas cubre lo que una
secretaría se encuentra en la práctica".

| Catálogo | Claves |
|---|---|
| Ministerios | `musica` `ujieres` `ensenanza` `evangelismo` `ninos` `jovenes` `medios` `cocina` `mantenimiento` `intercesion` |
| Cargos | `diacono` `anciano` `maestro` `liderJovenes` `liderDamas` `liderCaballeros` `ujierJefe` `misionero` |
| Instrumentos | `piano` `guitarra` `bajo` `bateria` `percusion` `metales` `voz` |
| Habilidades | `electricidad` `plomeria` `carpinteria` `construccion` `contabilidad` `informatica` `diseno` `fotografia` `conduccion` `cocina` `enfermeria` |
| Estado civil | `soltero` `casado` `unionLibre` `divorciado` `viudo` `separado` |

**`MembresiaView` usa las mismas listas, en el mismo orden, pero con la
etiqueta en español**: `"Música"`, `"Enseñanza"`, `"Niños"`, `"Líder de
jóvenes"`, `"Soltero(a)"`. Si se guardan así, la misma persona sirve en
`Música` para el teléfono y en `musica` para el web: dos ministerios distintos.
Y la app en inglés enseñaría las etiquetas en español, porque dejarían de ser
claves traducibles.

**Hay que guardar la clave y traducir al pintar**, que es lo que hace el web.
Sin valor en `estado_civil` **no es "soltero": es que no se ha preguntado**.

El web parsea con tolerancia (`parseLista`): si el JSON no es un array de
cadenas, devuelve lista vacía en vez de reventar. Conviene copiar ese criterio.

---

## 3. Las dos columnas JSON con forma propia

- **`historial_estados`**: array de `{de, a, fecha}`. Es lo que la ficha de iOS
  pinta hoy como "Movimientos de membresía" inventándoselo en cada guardado. El
  web lo escribe **solo cuando el estado cambia de verdad**, y de paso deja un
  aviso en la bandeja: "los miembros también son los aportantes de Tesorería,
  así que el tesorero se entera de bajas y traslados sin preguntar".
- **`seguimiento_notas`**: array de `{fecha, texto}`, más `seguimiento_revisado_en`.
  La hoja de seguimiento de iOS captura además **tipo** (llamada, visita,
  oración, mensaje, cita pastoral) y **completado**, que ahí no caben. Como es
  JSON en una columna de texto, añadir esas dos claves no rompe al web —las
  ignora— pero hay que decidirlo a propósito y no por accidente.

---

## 4. De dónde sale la asistencia

`servicios` (fecha, tipo, dirige, predica, `asistentes`/`ausentes`/`visitantes`
como arrays JSON, y conteos de `ninos`/`jovenes`/`adultos`) y
`servicio_asistencia` (una fila por persona y culto, con `presente`, `razon`,
`razon_otra`, `seguimiento` y `nombre_snapshot`).

De ahí salen los tres números que hoy son cadenas fijas en `Miembro`:
`rachaSinAsistir`, `ultimaVisita` y `enRoster`, y el `%` de la gráfica. Nada de
eso se guarda: se cuenta.

`nombre_snapshot` es la pista de un criterio que conviene respetar: la lista de
asistencia de un culto de hace dos años debe seguir diciendo el nombre que la
persona tenía entonces.

---

## 5. Dónde está el web

`~/Documents/Tamio-app`, rama con último commit *"Fusión: la puerta del
teléfono, el primer arranque y el mes"*. Los archivos que importan para el
padrón:

- `src/db.ts` — `Member`, `MemberFicha`, `darDeBajaMember`, `restoreMember`,
  `estadoDeBaja`, `registrarCambioEstadoMiembro`.
- `src/components/fichaMiembro.ts` — `ESTADOS_REGISTRO`, `ESTADOS_CIVILES`,
  `parseLista`.
- `src/components/FichaMiembroModal.tsx` — los cuatro catálogos.
- `src/components/BajaMemberModal.tsx` — los motivos de baja.
