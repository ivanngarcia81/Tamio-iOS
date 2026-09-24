# Lo que el handoff no trae y la app necesita · 21 de septiembre de 2026

Lista levantada contra `handoff5`, leyendo su HTML y comparándolo con las tablas
de la base y con lo que ya hace el iPhone. **Todo lo de aquí está verificado**:
o se buscó en el handoff y no está, o se leyó la columna en `tamio.sqlite`.

No es una queja al diseño: es el inventario de lo que hay que decidir por
nuestra cuenta, para que no se decida por olvido.

---

## 1. Pantallas que no dibuja

| Pantalla | Estado |
|---|---|
| **Cartas y traslados** | Confirmado por Iván: es la que falta. La tabla `carta` tiene 21 columnas —folio, destinatario, asunto, saludo, cuerpo, despedida, firmas, entrega— y ninguna está dibujada. |
| **Registro (Log)** | No aparece en el `navDef` del handoff, que lista trece filas y no la incluye. La app la tiene en el pie, junto a Configuración. |
| **Acceso** | El handoff **no dibuja la pantalla de entrar**: no hay "Sign in", ni correo, ni contraseña. La app tiene `AccesoMac`, y es lo primero que ve quien abre. |

## 2. Hojas y acciones que no dibuja

El handoff trae seis hojas —miembro, pariente, culto, asistencia, acta y
actividad—. Faltan, y todas existen en el iPhone:

- **Editar una ficha.** Solo dibuja "New member". La edición de alguien que ya
  está —y de un acta, y de un culto— no aparece en ninguna parte.
- **Firmar un acta.** La lista de actas enseña quién firmó y a quién le falta
  (`signers`), pero **no hay hoja para firmar**. En Configuración sí hay firmas
  guardadas del tesorero y del pastor, que es otra cosa.
- **Ver y exportar el PDF de un acta.**
- **Registrar una acción de seguimiento.** La pestaña "Follow-up" existe y
  lista a quién hay que buscar; no hay forma de apuntar que se le buscó.
- **Exportar el CSV** de informes de membresía.
- **Nueva carta y su vista previa**, que caen con la pantalla de Cartas.
- **Elegir idioma.** Configuración tiene la fila "Language · English" con su
  chevron, pero la pantalla de detrás no está dibujada. La app es bilingüe y
  el handoff está solo en inglés.

## 3. Campos que la tabla guarda y el handoff no pide

Verificado columna por columna contra `tamio.sqlite`.

**`acta` — la hoja "New minutes entry" no pregunta por siete cosas que la
tabla tiene:** `titulo`, `lugar`, `preside`, `secretario`, `testigo`, y
`presentes` / `ausentes` / `invitados` —en su lugar pide un **número** de
asistentes, que no es ninguna columna—. También tiene `fechaAprobacion` y
`folioProvisional`, que el handoff no contempla.

**`aportante` — la hoja "New member" no pregunta por:** la **baja**
(`fechaBaja`, `motivoBaja`), el `idFiscal`, las fechas de los dos bautismos, y
cuatro de las cinco listas de servicio: pide un selector único de ministerio
donde la tabla guarda `ministerios`, `cargos`, `instrumentos`, `habilidades` y
`ministeriosInteres`.

**`agenda` — la hoja "New event" no pregunta por:** `tipoPersonalizado`,
`invitado`, `contacto` y `recordatorios`.

**`servicio` — la hoja "New service" no pregunta por:** `eventos`. Las
`participaciones` sí están, pero en la otra hoja, la de asistencia.

## 4. Reglas que el handoff no modela

Esto no son campos: son cosas que la app hace y el diseño no puede saber.

- **Los permisos por rol.** `administraPadron`, `puedeEliminarMovimientos` y el
  reparto de áreas por rol no existen en el handoff: sus pantallas las ve todo
  el mundo. En la app esconden botones enteros —el alta y la baja del padrón,
  `Eliminar…` en Movimientos—.
- **El folio provisional.** El handoff numera las actas con una serie que no
  salta (`nextActaFolio`); la app manda un `P-` y **el folio bueno lo asigna
  Supabase**, que es por lo que no se imprime hasta que vuelve.
- **La cola de salida y el estado de la sincronización.** Nada del `outbox`, de
  los intentos, ni del fallo por paso ("Actas no se pudo sincronizar: …").
- **Que un dato pueda no saberse.** El handoff usa `<input type=date>` vacío; un
  `DatePicker` siempre tiene valor, así que cada fecha opcional necesita su
  interruptor o guardaría la de hoy como si fuera cierta.
- **Los dos vacíos distintos** de §0.-19 —"no ha bajado todavía" contra "esta
  iglesia no tiene"—, que la app distingue y el handoff enseña siempre con
  datos.

## 5. Y al revés: lo que el handoff pide y no tiene dónde guardarse

- **"Budget or speaker"** de una actividad. `EventoAgenda.presupuesto` existe en
  el modelo, **no hay columna en `agenda`** y el repositorio no lo escribe: hoy
  se perdería al guardar. Es el mismo caso que `Movimiento.auditoria`.
- **El número de asistentes** de un acta, que el handoff pide como cifra y la
  tabla guarda como tres listas de nombres. Se puede derivar contándolas.
- **Los tipos y estados acortados.** El handoff ofrece cuatro tipos de reunión y
  tres estados de acta; `TipoActa` tiene once y `EstadoActa` siete, que son los
  del web. Seguir el handoff a ciegas dejaría fuera siete tipos que el web sí
  usa y escribiría estados que allá no significan nada —el mismo fallo que ya
  se arregló el 21-sep con el `estado` traducido de la agenda—.

## 6. Media pantalla: dos pantallas que no caben en 900 pt · 23 de septiembre

> **Resuelto con el handoff 8 (24-sep).** Reportes pliega su lista de tipos por debajo de 809 pt de
> pantalla y la abre flotando desde un botón de su barra; Configuración cambia su barra por un riel
> de iconos de 60 pt por debajo de 741. El diseño dibuja solo los dos estados; el corte es donde
> deja de caber. La hoja del PDF no se achica al 88 % del diseño: en el Mac mide 612 (carta) y cabe.

Media pantalla de una MacBook Pro de 14" son **900 pt**. El resto de la app
cabe con el inspector cerrado (§0.-23 de `CONTEXTO.md`), pero estas dos no, y
hacerlas caber es rediseño. **Iván decidió el 23-sep pedírselo al diseñador** en
vez de inventarlo:

- **Reportes pide unos 1060 pt** desde `5f2b070`, que lo ensanchó para que
  dejara de romperse. Lo que no cabe es la lista de tipos de reporte al lado
  del documento. Una salida sería plegar esa lista por debajo de cierto ancho,
  como hace Mail con sus buzones. Pero eso cambia cómo se navega, y hay que
  dibujarlo.
- **Configuración pide 961 pt**: barra de la app (220) + barra de secciones
  (320) + panel. La barra de secciones no puede bajar de 320: con 240 y con 300
  se recortaba («tings» por «Settings»), y caber rompiendo es peor que no
  caber. Faltan **61 pt**. Hace falta una barra de secciones más estrecha o una
  que se pliegue.

Lo que se le pide al diseño: **cómo se ven Reportes y Configuración a 900 pt de
ancho**, con la barra lateral de la app abierta y el inspector cerrado.

**Inicio no entra en la petición.** Con el inspector abierto pide unos 1275 pt.
Iván decidió el 23-sep que a media pantalla se use con el inspector cerrado (⌘I),
que así cabe, y **no** poner las cuatro tarjetas en 2×2.

## 7. La pantalla de acceso del Mac: dos piezas que no entran · 24 de septiembre

> **Resuelto en el handoff 8 (24-sep):** el diseño quitó las dos piezas y el separador «or».

El handoff 7 dibuja en el bloque `locked` dos cosas que la app no puede cumplir. **Iván decidió el
24-sep dejarlas fuera**, y conviene que el diseño las quite:

- **«Keep me signed in on this Mac».** Cerrar la sesión en Tamio borra la base del aparato
  (`SesionSupabase.cerrarSesion` → `BaseLocal.limpiar`), para que los datos de una iglesia no se
  queden para el siguiente que entre. Con la casilla desmarcada, cerrar la app se llevaría lo que
  aún no hubiera subido.
- **«Unlock with Touch ID» y su nota.** A esa pantalla se llega sin sesión, y Touch ID no puede
  iniciarla sin guardar la contraseña. El Touch ID de verdad es el candado (`CandadoMac`), que
  tapa una sesión ya abierta, y ese sí está dibujado aparte.

El resto del bloque está construido tal cual: el panel verde de 380, «Show/Hide», el aviso de campos
vacíos con el borde rojo y «Forgot your password?».
