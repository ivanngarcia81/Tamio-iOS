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

## La fecha: hasta dónde llega, ya medido

`docs/COMPROBACION-DINERO.md` §2 dice que el corrimiento de un día está medido
en el importador y que **falta saber hasta dónde llega**. Eso sí quedó
contestado, midiendo en el servidor en vez de suponiendo.

`Fechas.desdeTexto("2026-09-06")` devuelve **medianoche UTC**
(`Fechas.swift:96-97`, la rama `.withFullDate`). Un formateador que no fije zona
lo lee con la del aparato y, al oeste de Greenwich, enseña el día anterior.
`L.formateador` (`Localization.swift:83`) **no fija zona**, y `Fechas.corta` va
por ahí.

**Qué forma tienen las fechas vivas** (medido el 10-sep en `public`, filas no
borradas):

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

O sea: **`transactions` es la única tabla a salvo** —todas sus fechas llevan
hora, así que el instante es exacto— y **las otras ocho columnas, 29 valores,
entran enteras por el camino del corrimiento**. Es lo contrario de donde ha
estado la atención: el dinero está bien y lo que puede mentir son los cortes,
los depósitos, las actas, la agenda y el padrón.

**Y no todo está roto**, que es la otra mitad de la respuesta: hay ocho
formateadores que SÍ fijan UTC a propósito —cinco en `Fechas.swift` (entre
ellos `diaLegible`, `diaSemanaCorto` y `numeroDeDia`), dos en
`Models/Secretaria.swift` y uno en `Models/MovimientoRecurrente.swift`— y sus
comentarios explican que se arreglaron justo por esto. Lo que falta es saber
**qué pantalla usa cuál**, y eso solo lo dice corriendo.

La prueba que lo mide está escrita —`pruebas/FechaSoloFechaTests.swift`—, pasa
una fecha conocida por los ocho ayudantes con la zona real del aparato y falla
nombrando a los que se corren. **No llegó a ejecutarse**: el iPad se bloqueó. Va
con control positivo (se salta sola si el aparato está en UTC, donde el fallo no
se puede reproducir).

---

## Lo que quedó BLOQUEADO, y por qué

- **El iPad se bloqueó** a mitad de la primera medida. Todo lo de aparato
  —posturas, multitarea, teclado físico, Face ID, VoiceOver, modo avión, las
  ocho suites de iPad existentes— sigue sin tocar.
- **Sacar la base del contenedor lo denegó el clasificador.** Sin eso no hay
  respaldo previo, y sin respaldo no se corrompe la base a propósito: es lo que
  hace falta para reproducir el hallazgo 1 corriendo.
- **Modo avión, Esc con teclado físico, Split View a 375 pt, Face ID y
  VoiceOver** no se conmutan por programa en un aparato físico. Piden mano.

## Lo que esto obliga a mirar en el árbol del teléfono

- **El hallazgo 1 es de forma, no de árbol.** El teléfono ya avisa. Lo que
  conviene mirar allí es si hay MÁS pantallas que llamen a `Compactacion.medir()`
  sin mirar `BaseLocal.caida`: hoy son tres llamadas y todas en `SeccionZona`.
- **La fecha es común a los dos.** Si el barrido confirma que `Fechas.corta`
  miente con una fecha «solo fecha», miente igual en el teléfono, y la tabla de
  arriba dice exactamente en qué ocho columnas.
- **⌘K está en `Sidebar.swift`**, que es solo del iPad. No alcanza al teléfono.
