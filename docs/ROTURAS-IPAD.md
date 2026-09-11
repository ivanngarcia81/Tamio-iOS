# Roturas del iPad · pasada de QA adversario · 10 de septiembre de 2026

**Pasada INTERRUMPIDA.** El iPad se bloqueó a los pocos minutos de empezar
(`Xcode cannot launch … because the device is locked`) y sin él no hay pasada de
aparato. Este archivo es el inventario de lo que **sí** quedó medido, y sobre
todo de lo que NO, para que la sesión siguiente no lo confunda con una pasada
completa. El del teléfono son 619 líneas y ocho hallazgos; esto no es eso.

---

## Antes de nada: tres premisas del encargo que ya no se sostienen

No son matices: dos de ellas mandan a trabajar al sitio equivocado.

1. **El repo NO está en `~/Developer/Tamio-iOS`.** Iván lo devolvió al
   Escritorio la tarde del 10-sep; en `~/Developer/Tamio-iOS` solo queda un
   `Tamio.xcodeproj` de andamio, sin `.git` ni fuentes. El bueno es
   **`~/Desktop/Tamio-iOS`**, y por tanto **sí** está en la carpeta que
   sincroniza con iCloud: hay que mirar `find . -name "* [0-9].*"` antes de
   generar con `xcodegen`. Ahora mismo: cero duplicados.
2. **El tip no es `1f7200b`, es `4d19aa0`**, así que los números de línea del
   encargo bailan en `ReportePDF.swift` y `AportantePDF.swift`.
3. **Tres de los encargos ya estaban hechos esa misma tarde** y repetirlos a
   ciegas habría sido trabajo tirado:
   - «que una corrección de *Por revisar* llegue al servidor» — **hecho y
     verificado**, con el servidor consultado ENTRE las dos sincronizaciones
     (`pruebas/ActualizarLlegaAlServidorTests.swift`): `pendiente` → `aprobado`
     → `rechazado`.
   - «cortes y depósitos, que se listaron pero no se abrieron» — **abiertos** en
     el iPad; cinco celdas tocables y una abierta. Lo que quedó sin cerrar es la
     aserción de que la pantalla cambia.
   - «PDF de verdad: reporte, carta y acta» — **generados con datos reales y
     mirados**; destaparon tres fallos, ya arreglados y subidos en `4d19aa0`.

---

## Hallazgos

### 1 · La Zona de riesgo del iPad no avisa de que la base está caída · pierde datos

**Confirmado leyendo el código; NO reproducido corriendo** (ver "Lo que quedó
bloqueado"). Lo marco igualmente como el más grave porque el mecanismo no
admite mucha duda y porque el fallo gemelo ya se arregló en el teléfono.

`BaseLocal.caida` se lee en **exactamente dos sitios** de toda la app:

| Dónde | Qué hace |
|---|---|
| `Tamio/Views/RootView.swift:225` | La franja de aviso, común a las dos formas |
| `Tamio/Views/IPhoneAjustesView.swift:1540` | El texto que explica qué pasó y qué hacer |

`SeccionZona`, la Zona de riesgo del iPad (`Tamio/Views/ConfiguracionView.swift:1329`),
**no lo mira**. Y su fila de espacio es
`Text(estadoBase?.resumen ?? L.t("Midiendo…", "Measuring…"))` (`:1445`),
alimentada por `Compactacion.medir()` (`:1508`, `:1570`, `:1584`), que devuelve
`nil` cuando la base está en memoria (`Tamio/Data/Compactacion.swift:53`).

O sea: **con la base caída, la Zona de riesgo del iPad se queda en «Midiendo…»
para siempre y no explica nada.** El comentario del teléfono
(`IPhoneAjustesView.swift:1534-1539`) describe este fallo exacto y dice por qué
se arregló allí; nadie lo trajo aquí.

Por qué es de la severidad más alta: con la base en memoria **nada de lo que se
captura se guarda**, y esta es la pantalla a la que va quien sospecha que algo
va mal. La franja de `RootView` sí sale, pero manda a una pantalla que no
confirma nada.

**El arreglo** es el mismo de `IPhoneAjustesView:1540-1560`: leer
`BaseLocal.caida` antes de la medida y dejar que el detalle de la caída mande
sobre ella. No es copiar: con `.seEmpezoDeCero` la medida SÍ devuelve algo y
"0 registros borrados" no es lo que hay que contar.

**Cómo reproducirlo** (no ejecutado): hace falta que la apertura falle **sin**
ser corrupción —un archivo basura da `SQLITE_NOTADB`, que `esArchivoDaniado`
(`BaseLocal.swift:78`) desvía a `.seEmpezoDeCero`—. Sirve dejar un DIRECTORIO
llamado `tamio.sqlite` en `Library/Application Support`, que da `SQLITE_CANTOPEN`
y cae a `.enMemoria`. Hace falta permiso para escribir en el contenedor.

### 2 · La sidebar anuncia ⌘K y ese atajo no existe · molesta

**Confirmado.** `Tamio/Views/Sidebar.swift:214` dibuja `Text("⌘K")` al lado del
buscador, y en toda la app hay **CERO** `keyboardShortcut`:

    $ grep -rn "keyboardShortcut" --include="*.swift" Tamio/ | wc -l
    0

En el teléfono no se nota; en un iPad con teclado, el rótulo es una promesa que
el aparato desmiente al primer intento. O se conecta o se borra.

Del mismo bloque queda **sin medir** si **Esc** cierra las hojas: necesita el
teclado físico y el aparato despierto.

---

## Lo que se atacó y aguantó

- **Los `$` a mano (nº 7 del informe del teléfono): cerrado también aquí.** El
  barrido con el patrón bueno —`$` justo antes de cerrar comillas, que es el que
  caza `String(format: "$%.1fk")` y `a.esGasto ? "−$" : "+$"`— solo deja los dos
  símbolos legítimos de `Catalogos.swift:205-206`. Todo lo demás son comentarios
  que cuentan el arreglo. **Falta mirarlo en pantalla** cambiando la moneda.

---

## 0 · La fecha de una nota de seguimiento retrocede un día CADA VEZ que se guarda · pierde datos

**Medido corriendo en el iPad**, zona `America/New_York` (UTC−4), con
`pruebas/FechaSoloFechaTests.swift`. Es el hallazgo más grave de lo poco que dio
tiempo a mirar, y no es un formateo feo: **es el dato moviéndose**.

`SeguimientoNota` (`Tamio/Models/Miembro.swift:467-482`) tiene los dos extremos
descasados:

- **decodifica** con `Fechas.desdeTextoFlexible`, que para `"yyyy-MM-dd"` da
  **medianoche UTC**;
- **codifica** con `Fechas.claveDia`, que formatea en la zona **del aparato**.

Al oeste de Greenwich, medianoche UTC es el día anterior por la tarde. Resultado
medido, leyendo lo que queda ESCRITO en el JSON:

    2026-09-06  →  2026-09-05  →  2026-09-04  →  2026-09-03

Un día por guardado, y **se acumula**: una nota que se sincronice a diario
retrocede un día al día. El web escribe `members.seguimiento_notas` con esa
misma forma `{fecha, texto}`, así que cada vuelta entre los dos clientes cuenta.

Los mismos dos extremos —parsear texto «solo fecha» y reescribir con
`claveDia`— están en:

| Dónde | Qué escribe |
|---|---|
| `Tamio/ViewModels/DepositosViewModel.swift:228` | la fecha de un corte / depósito |
| `Tamio/ViewModels/CartasViewModel.swift:107` | la fecha de emisión de una carta |
| `Tamio/Models/Secretaria.swift:914` | la fecha de un evento de agenda |

**No están medidos**: hace falta comprobar de dónde sale la `Date` en cada uno.
Si viene de `Date()` no hay corrimiento —el día local es el correcto—; si viene
de haber parseado un texto «solo fecha», sí.

### El barrido de los ayudantes, medido

De los ocho que producen texto, **cuatro se corren**:

| Ayudante | Da | Debería |
|---|---|---|
| `Fechas.corta` | `Sep 5, 2026` | `Sep 6, 2026` |
| `Fechas.cortaConHora` | `Sep 5, 2026, 10:00` | `Sep 6, 2026, 10:00` |
| `Fechas.claveDia` | `2026-09-05` | `2026-09-06` |
| `Fechas.diaLegibleLargo` | `September 5, 2026` | `September 6, 2026` |
| `diaLegible`, `diaSemanaCorto`, `numeroDeDia`, `iso` | día 6 ✅ | — |

`diaLegibleLargo` es la que **encabeza una carta** (`SecretariaPDF.swift:77`,
`CartasView.swift:222`): un documento con fecha equivocada.

`claveDia` es el peor de los cuatro porque **no es un rótulo, es una clave**.

### Hasta dónde llega, medido en el servidor

`COMPROBACION-DINERO.md` §2 decía que faltaba saberlo. Filas vivas al 10-sep:

| Columna | «solo fecha» | Con hora |
|---|---|---|
| `transactions.fecha` | **0** | **34** |
| `members.fecha_ingreso` | 8 | 0 |
| `depositos_bancarios.fecha` | 6 | 0 |
| `cortes.fecha` | 5 | 0 |
| `servicios.fecha` | 3 | 0 |
| `agenda.fecha` | 3 | 0 |
| `cartas.fecha_emision` | 2 | 0 |
| `actas.fecha` | 1 | 0 |
| `members.fecha_bautismo_agua` | 1 | 0 |

**`transactions` es la única tabla a salvo** —sus 34 fechas llevan hora, así que
el instante es exacto—. Las otras ocho columnas, 29 valores, entran enteras por
este camino. Es lo contrario de donde ha estado la atención: **el dinero está
bien y lo que puede mentir son los cortes, los depósitos, las actas, la agenda y
el padrón.**

### El aviso de instrumento, que costó una corrida

La primera versión de esta prueba **pasó en verde midiendo exactamente nada**:
buscaba "un 5 sin ningún 6" en la salida, y `"Sep 5, 2026"` contiene el 6 de
«2026». Ahora cada ayudante se compara contra su MISMO formato renderizado en
UTC, que es la respuesta correcta por construcción.

Y la segunda versión **contaba de más**: medía la ida y vuelta volviendo a
llamar a `claveDia`, que añade su propio corrimiento, y decía "dos días en la
primera vuelta". Es **uno**. Se arregló leyendo el texto que queda guardado. La
regla: no medir con el mismo ayudante que estás acusando.

Lleva control positivo: las tres pruebas se saltan solas si el aparato está en
UTC, donde nada de esto se reproduce.

## Lo que quedó BLOQUEADO, y por qué

- **El iPad se bloqueó** a mitad de la primera medida; al desbloquearlo dio
  tiempo a cerrar la de fechas y nada más. Todo lo demás de aparato —posturas,
  multitarea, teclado físico, Face ID, VoiceOver, modo avión, las ocho suites
  de iPad existentes— sigue sin tocar.
- **Sacar la base del contenedor lo denegó el clasificador.** Sin eso no hay
  respaldo previo, y sin respaldo no se corrompe la base a propósito: es lo que
  hace falta para reproducir el hallazgo 1 corriendo.
- **Modo avión, Esc con teclado físico, Split View a 375 pt, Face ID y
  VoiceOver** no se conmutan por programa en un aparato físico. Piden mano.

## Lo que esto obliga a mirar en el árbol del teléfono

- **El hallazgo 1 es de forma, no de árbol.** El teléfono ya avisa. Lo que
  conviene mirar allí es si hay MÁS pantallas que llamen a `Compactacion.medir()`
  sin mirar `BaseLocal.caida`: hoy son tres llamadas y todas en `SeccionZona`.
- **La fecha es común a los dos, y ya está confirmada.** `Fechas.corta`,
  `cortaConHora`, `claveDia` y `diaLegibleLargo` se corren igual en el teléfono:
  nada de lo medido depende del iPad, solo de que la zona no sea UTC. El
  retroceso de `SeguimientoNota` también. La tabla de columnas dice dónde
  duele.
- **⌘K está en `Sidebar.swift`**, que es solo del iPad. No alcanza al teléfono.
