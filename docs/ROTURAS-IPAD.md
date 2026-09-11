# Roturas del iPad · pasada de QA adversario · 10 de septiembre de 2026

**Pasada PARCIAL.** Empezó con el iPad bloqueado, siguió con él desbloqueado, y
aun así cubre una fracción de lo que cubrió la del teléfono: tres hallazgos, no
ocho. Este archivo dice **qué quedó medido y qué no**, para que la sesión
siguiente no lo confunda con una pasada completa.

Lo que sí está aquí está **reproducido corriendo en el aparato y con control
positivo**, no deducido leyendo.

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

### 1 · Con la base caída, el iPad queda ATRAPADO en la configuración inicial · pierde datos

**Reproducido corriendo en el iPad, con control positivo.** Empecé buscando lo
que el encargo señalaba —que la Zona de riesgo no avisa— y resultó ser peor:
**a esa pantalla no se puede llegar.**

Cómo se puso la base en ese estado: no vale un archivo basura, que da
`SQLITE_NOTADB` y `esArchivoDaniado` (`BaseLocal.swift:78`) lo desvía a
`seEmpezoDeCero`. Se dejó un **DIRECTORIO** llamado `tamio.sqlite` en
`Library/Application Support`, que da `SQLITE_CANTOPEN` y cae a `.enMemoria`:

    xcrun devicectl device copy to --device <UDID> \
      --domain-type appDataContainer --domain-identifier church.tamio.native \
      --source <carpeta local llamada tamio.sqlite> \
      --destination "Library/Application Support/tamio.sqlite"

Medido con el mismo volcado en los dos estados, mirando `isHittable`, que es lo
único que distingue lo que se ve de lo que solo está en el árbol:

| | Base CAÍDA | Base sana (control) |
|---|---|---|
| Franja de `RootView:225` | `NOTHING IS BEING SAVED ON THIS DEVICE · close the app and reopen it` | ausente |
| Hoja encima | **«Welcome to Tamio — Set up your church in a minute»**, con Church, City, Currency y «Get started» | ausente |
| `Show Sidebar` | **`·NOHIT`** | tocable |

**Las tres cosas a la vez son el problema:**

1. La franja dice, con razón, que **nada se está guardando**.
2. La app abre encima el formulario de alta de iglesia —porque la base vacía
   hace que el nombre sea el de fábrica (§0.-3)— e **invita a configurarla**.
   Lo que se teclee ahí no se guarda: lo dice la franja de arriba, en la misma
   pantalla. Dos elementos que se contradicen.
3. Y esa hoja **bloquea la navegación**: con `Show Sidebar` sin tocar, no hay
   forma de llegar a Ajustes. O sea que **la Zona de riesgo del iPad no es que
   no avise: es inalcanzable** justo cuando haría falta.

El arreglo del teléfono —explicar la caída en Ajustes— no sirve aquí mientras
no se pueda llegar a Ajustes. Lo que hay que decidir es qué hace la app con la
base en memoria: o no ofrecer el alta, o dejar salir de ella.

**Y el detalle que lo vuelve más traicionero:** detrás de la hoja el panel
seguía enseñando cifras —`$500.00`, `$4,714.50`, `7 records`—, porque la
sincronización llena la base EN MEMORIA. La app parece entera y con datos; solo
la franja dice que al cerrarla no quedará nada.

Lo de origen sigue siendo cierto y queda como causa: `BaseLocal.caida` se lee
en **exactamente dos sitios** —`RootView.swift:225` y
`IPhoneAjustesView.swift:1540`, que es la de TELÉFONO—. `SeccionZona`
(`ConfiguracionView.swift:1329`), la del iPad, no lo mira, y su fila es
`estadoBase?.resumen ?? "Midiendo…"` (`:1445`) alimentada por
`Compactacion.medir()`, que devuelve `nil` con la base en memoria
(`Compactacion.swift:53`).

**La prueba** está en `pruebas/ZonaDeRiesgoIPadUITests.swift`. Hoy su control
falla —no se llega a la Zona de riesgo—, y **ese fallo del control ES el
hallazgo**: sin él habría leído «no avisa» donde lo que pasa es «no se llega».
`pruebas/VolcadoRapidoUITests.swift` es el volcado con el que se midió.

La base del aparato se respaldó antes y se devolvió después; el control de
arriba es esa restauración, con sus datos intactos.

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

## Las ocho suites de iPad, corridas en el aparato: la tanda NO es admisible

Se copiaron las ocho a un target de interfaz y se corrieron contra el iPad.
**16 pruebas, 9 fallos — y ninguno cuenta como hallazgo**, porque la corrida
está contaminada y eso se comprobó, no se supuso:

`CandadoIPad` **enciende el candado y lo deja encendido** (lo dice su propio
comentario), así que las siguientes corrieron contra la pantalla de bloqueo.
Rastreado en el registro:

    BLOQUEADA durante → CandadoIPad.testElCandadoEnLasDosOrientaciones
    BLOQUEADA durante → DetallesIPad.testDetalleDeCarta
    BLOQUEADA durante → RecorridoIPad.testApaisado
    BLOQUEADA durante → RecorridoIPad.testInventario
    BLOQUEADA durante → RecorridoIPad.testVertical

Más una mano humana desbloqueando con Face ID a mitad. Y los fallos que sí se
explican, se explican **sin culpar al producto**:

| Fallo | Qué era de verdad |
|---|---|
| `EstrechoIPad` | `1192.0 no es < 1024.0`: la suite exige **iPad mini**; este es el 12.9". |
| `ImportarIPad` ×3 | «no hay menú Archivo»: sin proveedor de Archivos ni CSV en el aparato. |
| `MultitareaIPad` ×3 | El redimensionado de Split View no se automatiza. |
| `CandadoIPad` | El diálogo de Face ID **sí** salió (lo vio Iván). Instrumento. |
| `RecorridoIPad.testApaisado` | Corrió con la app bloqueada. |

**La conclusión va contra lo que el encargo daba por hecho.** «Lo que falle aquí
y pasara en el simulador es hallazgo por sí solo» **no se sostiene**: estas
suites, corridas tal cual en el aparato, producen ruido. Para que valgan hay que
(a) dejar `CandadoIPad` la ÚLTIMA o apagar el candado entre suites, (b) correr
`EstrechoIPad` en el mini, y (c) aceptar que Multitarea e Importar piden mano.

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
