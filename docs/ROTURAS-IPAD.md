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

## Las suites de iPad, corridas en el aparato: dos tandas y una lección

### Primera tanda: CONTAMINADA, no admisible

16 pruebas, 9 fallos, **ninguno cuenta**. `CandadoIPad` **enciende el candado y
lo deja encendido** (lo dice su propio comentario), así que las siguientes
corrieron contra la pantalla de bloqueo. Rastreado en el registro, no supuesto:

    BLOQUEADA durante → CandadoIPad.testElCandadoEnLasDosOrientaciones
    BLOQUEADA durante → DetallesIPad.testDetalleDeCarta
    BLOQUEADA durante → RecorridoIPad.testApaisado / testInventario / testVertical

Más una mano humana desbloqueando con Face ID a mitad.

### Segunda tanda: LIMPIA, y aquí está la lección

Sin `CandadoIPad` —que contamina— y sin `EstrechoIPad` —que exige un iPad mini y
aquí solo mide el modelo equivocado: `1192.0 no es < 1024.0`—. **Cero bloqueos.**

| | Primera (sucia) | Segunda (limpia) |
|---|---|---|
| `RecorridoIPad.testApaisado` | **falló** | **pasa** (301 s) |
| `RecorridoIPad.testVertical` | no llegó | **pasa** (301 s) |
| `DetallesIPad.testDetalleDeDia` | **falló** | **pasa** (84 s) |
| `DetallesIPad` · carta y culto | pasaban | pasan |
| `AccesoIPad` ×2 | pasaban | pasan |
| `ImportarIPad` | 1 de 4 | 1 de 4 |
| `MultitareaIPad` | 0 de 3 | 0 de 3 |

**Tres pruebas que "fallaban" en el aparato pasan en cuanto se quita el
candado.** Y los 6 fallos que quedan son de entorno, con el motivo escrito:

| Fallo | Lo que dijo |
|---|---|
| `ImportarIPad` ×3 | «el CSV no aparece en el selector» — no hay fichero en el aparato |
| `MultitareaIPad` ×3 | `1590.0 no es < 500.0` — **la ventana no se estrechó**: Split View no se automatiza |

**Conclusión, y va contra lo que el encargo daba por hecho.** «Lo que falle aquí
y pasara en el simulador es hallazgo por sí solo» **no se sostiene**: de 9
fallos, 3 eran un candado contagiado, 3 un fichero que no está y 3 un gesto que
no existe sin dedos. **Cero hallazgos de producto en las suites.** Lo que hay que
hacer para que valgan: `CandadoIPad` la ÚLTIMA o el candado apagado entre
suites, `EstrechoIPad` en el mini, y aceptar que Multitarea e Importar piden
mano.

### Tercera tanda: las `Hojas*`, en verde

Al descubrir lo de la clase base se corrieron aparte `HojasTesoreria`,
`HojasSecretaria` y `HojasAjustes`. **Diecisiete pruebas, diecisiete en verde**,
cero fallos y cero bloqueos. Son las más lentas de todas —entre 85 y 317
segundos cada una, más de 40 minutos la tanda— y son también las que más
superficie tocan:

- `HojasAjustes testZonaDeRiesgo` — **el control con la base SANA del hallazgo
  1**: esa pantalla funciona; lo que no funciona es llegar a ella con la base
  caída.
- `HojasTesoreria testCorteAgregarRegistrarYFirma` — el corte, el depósito y la
  firma, que es la zona que el encargo daba por nunca abierta. Aguanta.
- `HojasTesoreria testReportesPDF` — los PDF, ya con los tres arreglos de
  `4d19aa0` dentro.
- `HojasSecretaria` — actas, cartas, agenda, informes, servicios y la ficha de
  miembro con su seguimiento.

Que `testMembresiaNuevoEditarYSeguimiento` pase **no contradice el hallazgo 0**:
esa prueba recorre la interfaz, y el retroceso de la fecha está en el
`Codable` de `SeguimientoNota`, que solo se ve midiendo la ida y vuelta del
JSON. Es un recordatorio de para qué NO sirve una prueba de interfaz.

### Un aviso de instrumento que se tragó una suite entera

`-only-testing:PruebasAparato/HojasIPad` **no seleccionó nada y no dijo nada**:
`HojasIPad` es la clase BASE, no una prueba. Las de verdad son
`HojasTesoreria`, `HojasSecretaria` y `HojasAjustes` —y `DetallesIPad` e
`ImportarIPad` también heredan de ella—. Un `-only-testing` que no casa con
ninguna clase se salta en silencio: hay que contar las pruebas ejecutadas, no
fiarse del "passed".

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

## ARREGLADOS · 11 de septiembre, y verificados corriendo en el iPad

**Hallazgo 0 · la fecha que retrocedía.** `Fechas.diaDeCalendario` lee un
`"yyyy-MM-dd"` como la medianoche LOCAL de ese día, y `SeguimientoNota` la usa
al decodificar. Medido en el aparato:

| | Antes | Ahora |
|---|---|---|
| Tres guardados seguidos | `06 → 05 → 04` | **`06 → 06 → 06`** |
| Nota creada a las 23:50 | — | se guarda con el día local ✅ |

**La alternativa obvia no servía, y por eso está escrita en el código:** pasar
la ESCRITURA a UTC arregla la ida y vuelta y rompe la nota nueva, que nace con
`Date()` —la hora actual, no medianoche (`MembresiaView:1564`)—; una nota hecha
a las 23:50 en Nueva York se habría guardado con la fecha de mañana. Hay una
prueba dedicada a esa mitad.

**Hallazgo 1 · el iPad atrapado.** `ConfiguracionInicialView.haceFalta` recibe
ahora `baseCaida` y devuelve `false` cuando la base está en memoria: con nada
guardándose, no se pide configurar nada. Y `SeccionZona` lee `BaseLocal.caida`
y explica la avería con el MISMO texto que la de teléfono. Medido con la base
tumbada otra vez:

| | Antes | Ahora |
|---|---|---|
| Franja de aviso | presente | presente ✅ |
| Hoja «Welcome to Tamio» | presente | **ausente** ✅ |
| `Show Sidebar` | `·NOHIT` | **tocable** ✅ |
| Llegar a la Zona de riesgo | imposible | **se llega** ✅ |
| La fila de espacio | «Midiendo…» para siempre | explica la caída ✅ |

**Hallazgo 2 · ⌘K.** Quitado el rótulo. No se conectó porque no hay nada a lo
que conectarlo: el buscador de la sidebar es un `HStack`, **no un `Button`**, y
no abre nada. **Queda abierto y es decisión de Iván**: una barra de búsqueda
que no busca sigue siendo una promesa; o se le pone una búsqueda detrás —y
entonces el atajo vuelve, ya con algo que hacer— o se quita la barra.

### Y una acusación mía que estaba mal planteada

El informe daba por rotos cuatro ayudantes —`corta`, `cortaConHora`, `claveDia`
y `diaLegibleLargo`— porque con una fecha «solo fecha» enseñan el día anterior.
**No están rotos**: formatean un INSTANTE en la hora del aparato, que es lo
correcto para `transactions`, cuyas 34 fechas vivas llevan hora. El fallo nunca
fue del ayudante: era alimentarlo con un día de calendario leído como
medianoche UTC. La prueba se reescribió para fijar el reparto —instantes en
local, días de calendario en UTC— en vez de acusar al inocente.

## Pasada de INTERFAZ · 11 de septiembre · lo que se cerró y lo que queda

Segunda pasada, solo visual, las quince secciones en siete posturas (Air 13"
apaisado en ES/EN, claro/oscuro, fábrica/AX1; Air vertical; **mini vertical con
la sidebar fijada**, columna de detalle ~467 pt; y estrechada a 375 pt). 106
capturas. Detalle y lecciones en `docs/CONTEXTO.md` §0.-10.

**Todo lo de esta pasada se midió en SIMULADOR.** En el iPad físico solo se
instaló y se lanzó la app, mirando y sin sembrar. La distinción va escrita
porque un "bien" de simulador no vale lo que un "bien" de aparato.

### ARREGLADOS y vistos en pantalla (16 commits)

| Qué | Dónde |
|---|---|
| Dos radios de tarjeta para el mismo rol | `ConfiguracionView` · `Esp.radioTarjeta` |
| Filas idénticas a 50 y 52 pt | `ConfiguracionView` · `Esp.altoFila` |
| Cuatro acciones repartidas 52/54 | `ConfiguracionView` · `Esp.altoBoton` |
| Fila de persona 10 pt más baja | `ConfiguracionView` · `Esp.altoFilaDoble` |
| Tarjeta de sincronización a un tercio de ancho | `ConfiguracionView` · faltaba el `Spacer` |
| Radio de fila copiado a mano | `Sidebar` · `Esp.radioFila` |
| La cabecera de la iglesia no llevaba a ninguna parte | `Sidebar` |
| Trece filas de navegación a 36 pt (mínimo 44) | `Sidebar` |
| «Vista previa del PDF» prometía y no abría | `ConfiguracionView` |
| «Aportante» era "Contributor" y "Giver" a la vez | 9 sitios, 4 archivos |
| El lado ESPAÑOL decía «ROSTER» | `ServiciosView` ×2 |
| La misma sección, "MESSAGE" al leer y "PASSAGE" al escribir | `ServiciosView` |
| "Concept", falso amigo de «concepto» | 3 + 3 sitios |
| «Cargo» traducido como "Role", que es el otro concepto | `InformesMembresiaView` |
| «Importe» y «Monto» para el mismo dato | 6 sitios, dos de ellos PDF |
| Ocho sitios de vocabulario fuera de `Views/` | `Data/`, `AportanteDetalle` |

**Verificado con diff de píxeles del teléfono, con corrida de control:** seis de
siete paradas a **0.000 %** entre dos corridas del mismo código; tras los
cambios, solo se movieron las dos que debían (0.091 % y 2.593 % sobre un suelo
de ruido de 0.896 % en el menú del sistema). **El teléfono no se movió donde no
debía.**

**Y uno que solo compila, dicho como toca:** el «Cargo» → "Title" de
`InformesMembresiaView:342` está aplicado y compila, pero **no se ha visto en
pantalla** — el filtro del padrón no se abrió en dos intentos de navegación.

### ABIERTO · inventariado, no aplicado

| Sev | Dónde | Qué |
|---|---|---|
| media | `MiembroDetalle:29` (320) vs `CorteDetalle:52` (300) | Misma columna derecha, 20 pt de salto entre pantallas |
| media | `DashboardView` · Inicio | Dos columnas con alturas dispares: la dona deja un hueco grande a su derecha |
| media | `DashboardView:681` | Etiqueta de eje de **9 pt de texto**: 2 por debajo de `.caption2`, y nunca crece |
| baja | `DeltaBadge:17` | Glifo de **8 pt**. Es símbolo, no letra: otro criterio |
| baja | `ConfiguracionView` ×8 | `maxWidth: 640` a mano; mismo número que el breakpoint pero **otro rol** |
| baja | `Esp` | El espaciado VERTICAL sin tokenizar: `padding(.vertical, 6…20)` sueltos |
| baja | `ServiciosView:668-676` | «Fecha» es `DatePicker` y «Hora» un `TextField` libre de 70 pt, en el mismo formulario |
| baja | `ConfiguracionView.listaCompacta` | Código muerto (verificado): ocho filas con galón y sin `Button` |
| — | los 15 `.system(size:)` de texto | Propuesta de `relativeTo` por rol lista; sin aplicar |

### Los TRES roles, recorridos · sin hallazgos

| Rol | Ve (9-15) | No ve |
|---|---|---|
| **Administrador** | las quince | — |
| **Secretaria** | reportes, membresía, actas, servicios, cartas, informes, agenda, registro, config | inicio, ingresos, gastos, aportantes, depósitos, por revisar |
| **Tesorero** | inicio, ingresos, gastos, aportantes, reportes, depósitos, por revisar, registro, config | membresía, actas, servicios, cartas, informes, agenda |

**Cuadra exactamente con `Permisos.ve(_:)`**: a la secretaria le queda de
Tesorería solo Reportes y no tiene Inicio —que no es una pantalla neutra, enseña
el saldo—; al tesorero se le cierra Secretaría entera, y Membresía no aparece
porque `tesoreroVePadron` está apagado. **Cero desbordes en los dos.**
Verificado además en la captura: el pie de la sidebar dice el rol.

**Y el aviso que casi me cuesta dos hallazgos falsos:** forzar el rol
sustituyendo los catorce `?? .administrador` de las vistas **no hace nada**. En
modo revisión hay una sesión INYECTADA (`SesionSupabase.swift:97`, `rol:
.administrador`), así que `sesion` no es `nil` y ese `??` no se evalúa nunca. La
primera pasada dio «la secretaria ve las quince» —que parecía un agujero de
permisos— y «el tesorero se comporta bien» —que parecía la confirmación—, y las
dos eran administrador disfrazado; lo del tesorero, además, porque en el mini
APAISADO (744 pt de alto) las seis secciones de Secretaría quedan bajo el
pliegue y el recorrido no desplaza. **El rol se fuerza en la inyección, no en
los `??`, y el recorrido por rol se hace con altura de sobra.**

### RETIRADO · un hallazgo mío que no se sostiene

**«Tocables por debajo de 44×44» medido con el volcado NO es una medida del área
tocable.** El marco que devuelve XCUITest es el de accesibilidad y, para un
`Button` cuya etiqueta lleva relleno transparente, es el del contenido
DIBUJADO, no el de la zona que responde.

Se cazó con las celdas de día de Agenda: el volcado daba **27 tocables de
16×18 pt**, y el código las declara con `.frame(height: 54)` y **sin
`contentShape`**, que es justo el patrón que encoge el área tocable. Parecía un
hallazgo redondo. **No lo es**: `pruebas/DiaTocableUITests.swift` toca el hueco
de la celda, fuera de los dígitos, y **abre igual**. Con control positivo
—tocar el número también abre—.

Por eso se retira «Cambiar periodo, 98×14 pt» de la lista de abiertos, y por eso
los 28-30 pt de los botones de tarjeta de «Por revisar» quedan **sin medir**, no
confirmados.

**Lo que SÍ se sostiene es el de la sidebar**, y la diferencia es concreta:
`SidebarRow` lleva `.contentShape(Rectangle())`, así que su marco de 36 pt era
el área tocable de verdad. Medir un tocable pide mirar si hay `contentShape`, y
si no lo hay, tocarlo en el hueco.

### DECISIÓN DE IVÁN

- **El buscador de la sidebar** sigue siendo un `HStack` que no busca. O se le
  pone búsqueda detrás —y el ⌘K vuelve, ya con algo que hacer— o se quita la
  barra. Sigue abierto desde el 10-sep.
- **`AmountText` sabe encoger y no sabe crecer.** Si crece: donde la cifra
  comparte renglón con un rótulo, el `minimumScaleFactor(0.5)` la devolverá a
  un tamaño parecido —beneficio pequeño—; donde hay sitio crecerá de verdad y
  puede reabrir el caso del `Divider` de §0.-7. Por ahí pasa el dinero de toda
  la app y toca las dos plataformas.
- **«Configuración» (iPad) contra «Ajustes» (iPhone)**, los dos en `RootView`.
- **La tarjeta «Vista previa del PDF»**, ya sin galón, sigue siendo redundante
  con la previa en vivo de la misma pantalla: ¿se queda o se va entera?
- **Cinco términos más con dos traducciones**, fuera de la lista aprobada:
  «EL CORTE»→"THE CUT", «Movimientos»→"Entries"/"Transactions", «Sin nombre»
  con tres ingleses, «Banorte · …» con dos, «Congrega desde»/«Se congrega
  desde».

### NO MEDIDO, y qué haría falta

| Pendiente | Qué hace falta |
|---|---|
| Todo lo de aparato | El iPad en la mano y desbloqueado |
| Cinco secciones en AX1 | El recorrido no hace scroll en la sidebar: quedaron bajo el pliegue. **No se demostró que sean inalcanzables** |
| El conteo de controles empujados de la hoja de miembro | §4 dice diez y su propia lista suma trece; sigue sin contarse |
| Truncados dentro de la columna estrecha | El volcado mide contra la ventana, no contra la columna |

## Lo que queda por arreglar

## Lo que NO se pudo medir, y qué haría falta

| Pendiente | Qué hace falta |
|---|---|
| Modo avión, cola de salida, reintento | Una mano: no se conmuta por programa |
| **Esc** con teclado físico | Un teclado puesto |
| Split View a 375 pt | Un dedo: el gesto no se automatiza (lo dijeron los 3 fallos de Multitarea) |
| VoiceOver con el candado (§7) | VoiceOver de verdad. **XCUITest no sirve**: lista lo de debajo aunque esté oculto |
| Si `Sign out` responde con la app bloqueada | `pruebas/CandadoTapaLoDeDebajoUITests.swift`, ya escrita, con el candado encendido |
| Roles contra RLS, token expirado, borrar cuenta | Una cuenta de secretaria, que sigue sin existir |
| `EstrechoIPad` | Un iPad mini |
| El importador | El CSV de prueba en el aparato |

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
