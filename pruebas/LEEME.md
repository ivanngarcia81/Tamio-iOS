# Pruebas que no viajan en el proyecto

**Estos archivos NO están en ningún target.** El `.pbxproj` de este repo está
editado a mano y `xcodegen` no se puede correr aquí (§2.1 de
`docs/CONTEXTO.md`), así que un target de pruebas obligaría a tocarlo a mano.
Vivían en un directorio temporal y se perdían al acabar la sesión; están aquí
para que la siguiente no las vuelva a escribir.

**Cómo correrlas** — la receta entera está en `docs/CONTEXTO.md` §3, en corto:

1. `rsync -a --exclude .git --exclude Tamio.xcodeproj . /ruta/copia/`
2. En la COPIA, añadir al `project.yml` los paquetes (GRDB, Supabase), un
   target `bundle.unit-test` con `TEST_HOST` y `BUNDLE_LOADER` apuntando a
   `Tamio.app/Tamio`, y un `schemes:` con el target de test.
3. Copiar estos archivos a `TamioTests/` de la copia, `xcodegen generate` allí
   y `xcodebuild ... test` contra un simulador por UDID.

**Con el modo revisión apagado, no correrlas contra un contenedor con sesión.**
Ya subieron filas a la base de la iglesia sin querer. Sin sesión no sube nada:
las operaciones se quedan en la cola de salida y el motor no se llama.

## Las de la pasada de interfaz del 8 de septiembre

- **`RecorridoInterfazUITests.swift`** — el recorrido de captura: navega, hace
  un volcado de cada pantalla y se para en cada `MARCA:` para que el shell
  dispare `simctl io screenshot`. Se repite en oscuro y en AX1 sin tocar el
  código (`xcrun simctl ui <udid> appearance dark` y `content_size
  accessibility-medium`). Lleva en su cabecera las tres cosas que cuestan una
  vuelta: las filas de `List` no son botones, la primera celda es la cabecera, y
  las filas del hub bajo el pliegue no están en el árbol.
- **`PlantillasDeCartaUITests.swift`** — la prueba del fallo intermitente de
  Cartas. Abre la pantalla veinte veces y cuenta las que se quedan sin
  plantillas. Sirve de control para cualquier cambio en `CartasViewModel`.
- **`contraste.py`** — mide el contraste de un rectángulo de una captura, sin
  dependencias. `python3 pruebas/contraste.py captura.png rect X0 Y0 X1 Y1`.

## Las de la pasada del iPad · 9 de septiembre

Se corren igual (§3), pero con `XCUIDevice.shared.orientation` en el `setUp` y
—las de columna estrecha— **en el iPad mini**, que es donde la columna del
detalle baja de 640 pt con la sidebar fijada.

- **`EstrechoIPadUITests.swift`** — iPad mini vertical: que tocar una fila abra
  la ficha, que cambiar de sección la deje en la raíz y que el reporte abra con
  sus controles una sola vez.
- **`ReportesEstrechoUITests.swift`** — que ninguna cabecera de la tabla se
  salga del ancho de la ventana y que ninguna etiqueta de botón mida más de un
  renglón. Cuatro posturas.
- **`InicioEstrechoUITests.swift`**, **`SecretariaEstrechoUITests.swift`** — lo
  mismo para los indicadores de Inicio, los informes del padrón y el panel de
  Asistencia.
- **`FirmaUITests.swift`** — que un trazo encienda "Guardar", en iPad y en
  teléfono. `PKCanvasView` no es observable: es la prueba de que el cuerpo lee
  el contador.
- **`FichaAportanteUITests.swift`**, **`FilaTrasladoUITests.swift`**,
  **`TextoGrandeUITests.swift`** — que las cifras y las pastillas se dibujen
  todas al mismo tamaño, con el tamaño de letra de fábrica y en AX1.
- **`AjustesAccesoUITests.swift`** — la parada para medir el contraste de los
  dos botones apagados de Acceso y áreas, y que vuelvan a ser botón al escribir
  un correo.
- **`SeleccionAnunciadaUITests.swift`** — que la sección y la fila abiertas
  digan `isSelected`.
- **`TelefonoParadasUITests.swift`**, **`MembresiaTelefonoUITests.swift`** — las
  paradas del teléfono para el diff de píxeles cuando se toca una vista
  compartida.
- **`pixdiff.py`** — el diff de píxeles, sin dependencias. Salta la franja
  superior (reloj y aviso del modo revisión) y da el porcentaje distinto:
  `python3 pruebas/pixdiff.py antes.png despues.png`. **Solo vale con corrida
  de control**: dos corridas del mismo código dan 0.000 %.

## Las de la segunda vuelta del iPad · 9 de septiembre

Las 45 hojas, los detalles que no se habían abierto, y las dos pantallas que el
modo revisión salta.

- **`HojasIPadUITests.swift`** — abre las hojas una a una y, en cada parada,
  fotografía, vuelca los rótulos con su marco y **avisa de lo que se sale por el
  borde**. Trae los ayudantes que costaron una vuelta: `toca` baja a buscar el
  botón si está bajo el pliegue (en la columna de detalle del iPad los del corte
  quedan fuera de pantalla), y `revisarSuave` es para las hojas del SISTEMA —la
  de compartir—, que se reordenan mientras se leen y dejan a XCUITest sin el
  elemento a media lista.
- **`DetallesIPadUITests.swift`** — la carta, el culto y el día de la agenda.
  El desplazamiento va por el LADO DERECHO: en el centro cae la lista.
- **`AccesoIPadUITests.swift`** — la puerta, en las dos orientaciones. Se corre
  con el modo revisión **APAGADO** y en un simulador recién creado
  (`xcrun simctl create`), porque el llavero del simulador es común a todas las
  apps (§3).
- **`CandadoIPadUITests.swift`** — la pantalla de bloqueo. Se corre con el modo
  revisión encendido —el candado se enciende en Ajustes · Cuenta— y **se queda
  encendido entre corridas**, así que la prueba sirve para las dos entradas. El
  diálogo del sistema tapa la pantalla y se cancela desde SpringBoard;
  `sb.buttons["Cancel"]` hay más de uno, así que **`.firstMatch`**.
- **`ConstanciaUITests.swift`** — la frase de la constancia, entera, en iPad y
  en teléfono. El alto que se compara depende de la escala de la hoja: 38 pt en
  iPad, 20 en el teléfono.

- **`ImportarIPadUITests.swift`** y **`ImportarTelefonoUITests.swift`** — los
  dos importadores de CSV, de punta a punta: menú → selector → archivo → mapeo
  → previa. Tres cosas que costaron una tarde y no se deducen del código:
  1. **El selector de archivos corre en OTRO proceso.** `DocumentsApp.state` y
     el conteo de botones de la app **no lo ven**; con ese detector se da por
     roto lo que ya funciona. Lo delatan sus propios textos ("Recents", "On My
     iPad") o, si no, la captura.
  2. **Hace falta un CSV puesto de antemano**, porque la app no puede guardarlo
     en Archivos sin manos. Se escribe en el contenedor del simulador:
     `.../data/Containers/Shared/AppGroup/<el de group.com.apple.FileProvider.LocalStorage>/File Provider Storage/`.
     El del iPad se abre por nombre; en la rejilla el toque va **en el icono**,
     no en la etiqueta (`dy: -1.8` desde el texto).
  3. **En el iPhone sus elementos ni se dejan consultar** —la instantánea de
     accesibilidad caduca a media lectura— y **recuerda entre corridas dónde
     estaba**, así que navegar por coordenadas fijas no vale: lo único estable
     es el buscador de arriba, se escribe el nombre y se toca el resultado.
  Y `revisar()` no se puede usar mientras el selector está arriba, por lo
  mismo: se toma la captura a secas.

**Y un aviso sobre lo que estas pruebas NO pueden medir:** XCUITest lista los
elementos aunque lleven `accessibilityHidden(true)` —comprobado poniéndoselo al
aviso del modo revisión, que siguió apareciendo en el volcado—. Así que con el
árbol de XCUITest no se puede saber qué lee VoiceOver: eso pide VoiceOver de
verdad.

## Las de la SEGUNDA pasada de interfaz del iPad · 11 de septiembre

El recorrido de las quince secciones en siete posturas. Los hallazgos están en
`docs/ROTURAS-IPAD.md` y las lecciones en `docs/CONTEXTO.md` §0.-10.

- **`RecorridoIPadUITests.swift`** — visita las quince secciones de la sidebar,
  vuelca los marcos y **avisa de los tocables por debajo de 44×44** y de lo que
  se sale. La postura, la orientación y el idioma llegan por entorno
  (`TEST_RUNNER_POSTURA`, `_ORIENT`, `_IDIOMA`), así que una sola prueba sirve
  para las siete.
- **`postura.sh` y `capturar.sh`** — el guion de una postura y el disparador de
  capturas. `capturar.sh` mira el log esperando cada `MARCA:` y dispara
  `simctl io screenshot` (más `sips -r -90` en apaisado, que el adjunto de
  XCUITest sale rotado y recortado). Uso:
  `postura.sh <udid> <nombre> <apaisado|vertical> <es|en> <light|dark> <large|accessibility-medium>`
- **`AjustesIPadUITests.swift`** — recorre las ocho secciones de Ajustes, y
  afirma que la cabecera de la iglesia es un botón que lleva a Configuración.
- **`EstrechoVentanaIPadUITests.swift`** — estrecha la ventana a 375 pt,
  comprueba **quién dibuja entonces** (pestañas y no sidebar, o sea
  `IPhoneRootView`) y **restaura la ventana al terminar**.
- **`TextosCorregidosUITests.swift`**, **`UltimosDosUITests`** — van a BUSCAR en
  pantalla los textos corregidos, porque un diff a 0.000 % en una pantalla donde
  sí se cambió texto no prueba que el arreglo falle: prueba que el texto no se
  ve ahí (un marcador con el campo lleno, un `Picker` bajo el pliegue).
- **`TelefonoParadasInterfazUITests.swift`** — las siete paradas del iPhone 17e
  para el diff de píxeles al tocar una vista compartida.

**Cuatro avisos de instrumento que costaron una corrida cada uno:**

1. **Comparar contra el ancho de la VENTANA no ve lo que se trunca dentro de una
   COLUMNA.** En el mini la ventana son 744 pt y el detalle 467: «0 desbordes»
   quiere decir "nada fuera de la ventana", no "todo cabe".
2. **Los marcos de XCUITest van en coordenadas de PANTALLA y `app.frame` las da
   locales.** Con la ventana estrechada y centrada salieron **60 desbordes
   falsos**. La captura los desmontó.
3. **El tamaño de ventana sobrevive a la corrida siguiente.** Se restaura con
   `Window Controls → Zoom` de SpringBoard: el asa estrecha pero no ensancha.
4. **El menú de la barra tiene un suelo de ruido de 0.896 %** entre dos corridas
   del mismo código. Sin corrida de control se lee como regresión.

Y uno de barrido, no de prueba: **el texto se busca por el TÉRMINO y sobre
`Tamio/` completo**. `L.t("Concepto", "Concept")` no encuentra
`L.t("Concepto · opcional", "Concept · optional")`, y hay texto visible en
`Tamio/Data/`.

## Las de la pasada de QA adversario del iPhone · 9 de septiembre

Los hallazgos y cómo se reprodujeron están en `docs/ROTURAS-IPHONE.md`. **Las
que cazan un fallo están HOY en rojo a propósito**: se ponen verdes el día que
se arregle lo que cazan, y hasta entonces son la medida.

Unitarias (target `bundle.unit-test`, receta del §3):

- **`ImporteDelAltaTests.swift`** — los dos parseadores de dinero enfrentados.
  Compara `NuevoMovimientoView.centavos` (el del alta manual) contra
  `Money.desdeTexto` (el del importador) con el mismo texto. **Estaba en rojo y
  ahora pasa**: si vuelve a fallar, es que el alta se volvió a escribir su propio
  parseador. Es la prueba del hallazgo nº 1 y del nº 3.
- **`BandejaConIdRealTests.swift`** — aprobar, devolver y editar un asunto de
  «Por revisar» **con un id como los de verdad**, que es un UUID con guiones. El
  id del asunto se partía por el primer guion y las cinco acciones de la bandeja
  no hacían nada; con los ids de la maqueta —"1", "207"— eso no se ve, y por eso
  esta prueba se pasa el id hecho a mano. Modo revisión APAGADO.
- **`BaseMudaTests.swift`** — la base local cuando el archivo no abre, y **cuál
  de las dos salidas toca**: apartar y empezar de cero (archivo dañado) o quedarse
  en memoria sin tocar nada (todo lo demás). Se corre en DOS pasadas sobre el
  mismo contenedor, con el shell estropeando el archivo entre una y otra; la
  cabecera lleva los comandos. **Las dos pasadas SALTAN** si el contenedor no está
  como cada una espera, en vez de fallar: una suite que siempre tiene un rojo es
  una suite que se deja de mirar. La tercera prueba es la que más falta hacía —que
  una migración rota NO caiga en la rama de apartar—, y esa corre siempre.
- **`CSVQueMienteTests.swift`** — BOM, filas vacías, comas dentro del nombre,
  columnas duplicadas, encabezados en el otro idioma, 5.000 filas, los dos
  formatos de importe y los importes con letras dentro. **Cada regla que se
  aprieta lleva su control al lado**: junto a "1e9 se rechaza" está "$1,960.00 y
  1.960,00 MXN siguen pasando", y junto a "el separador no mira dentro de las
  comillas" está "un archivo de comas con un punto y coma dentro sigue siendo de
  comas". Sin ese par, apretar una regla que existía por una razón rompe la
  razón.
- **`FechasImposiblesTests.swift`** — 31 de febrero, año 1900, año 2999 y la
  ambigüedad día/mes. Pasan todas: están para que no se rompa lo que hoy va bien.

De interfaz (con el modo revisión **ENCENDIDO** en la copia):

- **`ImporteEnPantallaUITests.swift`** — el teclado que sale en región española
  (`-AppleLocale es_ES`) y el camino entero de un importe con coma hasta la fila
  del libro. **La medida que lo destapó todo es el volcado de teclas**: con esa
  región el `.decimalPad` no tiene tecla de punto.
- **`RevisarRedibujoUITests.swift`** — corregir el importe de un asunto y verlo
  corregido. **Mide el importe en TRES momentos a propósito** —al guardar, en la
  lista, y al salir y volver a entrar—, porque hicieron falta tres arreglos en
  capas distintas y cada uno tapaba al siguiente: que se escriba, que la ficha
  empujada se entere, y que la lista se entere. El momento en el que falle dice
  cuál se rompió.
- **`FichaAlDiaUITests.swift`** — que la ficha abierta enseñe el dato de ahora y
  no el de cuando se abrió. **Lleva su control dentro de la cabecera**: sin él la
  prueba no demostraría nada, porque también pasaría si la lista se redibujara
  por su cuenta. Para comprobar que muerde, se devuelve el `==` por id a
  `Movimiento` y se deshace el `vigente` de `MovimientosView`.
- **`BaseCaidaUITests.swift`** — lo que ve la tesorera, que son **dos avisos
  distintos**: rojo "no se guarda nada" y naranja "estaba dañada, se empezó de
  cero". Tres pasadas, y la primera es el control positivo: con la base sana no
  puede salir ninguno. Para provocar el rojo **no vale corromper el archivo**
  —eso ahora se recupera—: hay que sustituirlo por un DIRECTORIO, que da
  `CANTOPEN` en vez de `NOTADB`.
- **`MonedaYCeroUITests.swift`** — cambiar la moneda de la iglesia a euros y
  recorrer Tesorería buscando dólares; y guardar un movimiento de $0.00.
- **`CapsulasDeBarraUITests.swift`** — cuenta las cápsulas de las cuatro
  pantallas de lista. **Se corre dos veces sin tocar el código**, con
  `content_size large` y `accessibility-medium`, y se comparan los dos volcados.
  Hoy pasa: no se descarta ninguna.
- **`PresentacionesUITests.swift`**, **`TecladoYHojasUITests.swift`**,
  **`DobleToqueUITests.swift`** — las tres son **controles negativos**: las hojas
  apiladas sí salen, el teclado no tapa el importe y el doble toque no duplica.
  Valen para no volver a sospechar de lo mismo, y para enterarse el día que
  cambie.
- **`RespaldoUITests.swift`** — el botón "Respaldar ahora" mirado despacio, con
  paradas para fotografiar. Es la otra mitad de `BaseMudaTests`: lo que la
  tesorera ve cuando la base ya está caída.
- **`TextoBrutoUITests.swift`** — **NO sirve todavía.** Su cabecera dice qué dos
  cosas hay que arreglarle antes de creerse nada de lo que imprima.

**Dos cosas de esta pasada que cuestan una vuelta si no se saben:**

1. **Al añadir un archivo de prueba hay que volver a correr `xcodegen` en la
   copia Y comprobar que entró** (`grep -c NombreDeLaClase Tamio.xcodeproj/project.pbxproj`).
   Si no, `xcodebuild` contesta `Executed 0 tests` y **da TEST SUCCEEDED**, que
   se lee como que todo va bien.
2. **Sin red no se puede compilar la copia** tal cual: la resolución de paquetes
   sale a GitHub. Se arregla copiando el `Package.resolved` del repo y un
   `SourcePackages` ya resuelto, y añadiendo
   `-clonedSourcePackagesDirPath <dir> -disableAutomaticPackageResolution
   -onlyUsePackageVersionsFromResolvedFile`.

## Las de APARATO · 10 de septiembre

Estas cuatro corren **en el iPhone y el iPad de Iván**, no en el simulador, y
por eso su receta es distinta de la de arriba:

- **El bundle id de la copia tiene que ser el REAL** (`church.tamio.native`).
  En un aparato físico el llavero NO se comparte entre apps —al revés que en el
  simulador, que es de lo que avisa el §3 del traspaso—, así que una copia con
  id propio arranca **sin sesión y sin datos**, en la pantalla de acceso.
- El target unitario va con `TEST_HOST`/`BUNDLE_LOADER` a `Tamio.app/Tamio`:
  así la prueba tiene la sesión de verdad y puede consultar Supabase ella misma.
- `xcodebuild ... -destination 'id=<UDID del aparato>' -allowProvisioningUpdates`.

- **`CorreccionLlegaAlServidorTests`** — siembra un gasto pendiente con id de
  verdad, sincroniza, lo aprueba desde la bandeja y vuelve a sincronizar.
- **`ActualizarLlegaAlServidorTests`** — la misma historia pero **preguntándole
  al servidor entre las dos sincronizaciones**. Es la que de verdad prueba el
  `UPDATE`: sin esa consulta intermedia, una fila que sube ya aprobada da el
  mismo resultado final que una que sube pendiente y se actualiza después.
- **`PDFDeVerdadTests`** — genera reporte, acta y carta con los datos del
  aparato y los deja en `Documents/` para poder SACARLOS y mirarlos:
  `xcrun devicectl device copy from --device <UDID> --domain-type
  appDataContainer --domain-identifier church.tamio.native --source
  Documents/qa-reporte.pdf --destination .`
- **`CortesYDepositosUITests`** — abre Depósitos y su primer corte. Distingue
  teléfono de iPad: el primero navega por `tabBars` y hub, el segundo por la
  sidebar. Sin esa distinción falla con "No matches found for Descendants
  matching type TabBar", que parece un fallo del producto y no lo es.

### La tanda unitaria del iPad · 11 de septiembre · 51 en verde

Corrida **desde el iPad de Iván contra el servidor**, con el modo revisión
APAGADO y sobre sus datos (que son de prueba: ver el traspaso). Receta: target
`bundle.unit-test` con `TEST_HOST`/`BUNDLE_LOADER` a `Tamio.app/Tamio`, id de
la copia el REAL (`church.tamio.native`), `-destination 'id=<UDID hardware>'` y
`-allowProvisioningUpdates`. **El `project.yml` generado necesita
`DEVELOPMENT_TEAM`**, que el `.pbxproj` de verdad sí lleva y `xcodegen` no
inventa.

Lo que quedó probado y nunca lo había estado desde un aparato:

- **`ActualizarLlegaAlServidorTests` pasa** (4.6 s) — la que pregunta al
  servidor ENTRE las dos sincronizaciones, o sea la única que prueba el
  `UPDATE` de verdad. Y **`CorreccionLlegaAlServidorTests`** (2.9 s).
- **`FechaSoloFechaTests` 5/5**, con su control de que la zona del aparato no
  es UTC: la regresión de la fecha que retrocedía aguanta.
- **Los tres PDF generados con los datos del aparato** y mirados: acta
  `ACTA-2026-001` (23 KB), reporte `2026-09` (42 KB) y carta (20 KB).

- **`QueHayEnElAparatoTests.swift`** — inventario de la base local: si está
  caída, el estado del motor antes y después de sincronizar, y el conteo de
  cada tabla. **Los nombres de las tablas se leen de `sqlite_master`, no se
  adivinan**: la primera versión los puso a mano, las nueve consultas fallaron
  y el centinela (-2) se leía como "vacío".
- **`ActasTrasSincronizarTests.swift`** — la prueba que desmontó un hallazgo en
  tres vueltas. Ver abajo.
- **`InterfazAparatoUITests.swift`** — el repintado de los controles empujados,
  el barrido visual en iOS 27 y el texto que faltaba por ver. **Escrita y
  compilada, sin correr**: el iPad devuelve *"Timed out while enabling
  automation mode"*. No es conexión ni firma —instalar funciona a la primera—,
  es el permiso de automatización del aparato: `Ajustes → Desarrollador →
  Habilitar automatización de interfaz`, o reiniciar el iPad.

**Y el aviso que más vale de esta tanda: sincronizar ANTES de mirar.**
`PDFDeVerdadTests` falló con «no hay ningún acta» y «no hay ningún periodo
contable» sobre un aparato con 7 actas y 40 movimientos en su base. La
sincronización es asíncrona y arranca con la app: la prueba medía una base que
todavía no había bajado nada. Ahora lleva un `setUp` que sincroniza.

Perseguirlo hasta el final costó tres vueltas, y cada una podía haber quedado
escrita como hallazgo falso:

1. «El repositorio devuelve 0 actas y la tabla tiene 7» → parecía el caso del
   folio B7 (§0.0), un filtro que tira el dato al leer.
2. Tras sincronizar: tabla 7, repositorio **1**. Seguía oliendo mal.
3. `lista()` filtra `borrado == false`, y **6 de las 7 están borradas**. El
   repositorio acierta. **No hay hallazgo.**

**Tres avisos que costaron una vuelta cada uno:**

- **NO pasar `xcodebuild` por un `grep`**: el código de salida pasa a ser el del
  grep. Una compilación fallida dio "exit 0" y las pruebas corrieron con el
  paquete VIEJO. Redirigir a un archivo y confirmar `** TEST BUILD SUCCEEDED **`.
- **`Not authorized for performing UI testing actions` a mitad = el aparato se
  bloqueó o se lo llevaron.** No es del producto.
- **Un volcado que recorre todos los elementos es inviable en el iPad**:
  `allElementsBoundByIndex` + `isHittable` es un viaje por elemento y pasa de
  veinte minutos. Volcar solo lo que se va a mirar.

**Y limpiar lo que siembran.** Marcan `registrado_por = "prueba-aparato"`
justamente para poder darlas de baja después; los folios que consumen no se
recuperan.

---

## El instrumental DE APARATO, sustituido · 12 de septiembre

Hasta hoy esta receta estaba en prosa en el traspaso y la copia que la
hospedaba vivía en el `TMPDIR`, así que se fue con él y hubo que volver a
deducirla. Ahora es **`pruebas/aparato.sh`** y **`pruebas/aparato_yaml.py`**:

    pruebas/aparato.sh [--limpio] <UDID-hardware> [-only-testing:Target/Clase]

Monta la copia, le compone el `project.yml` con los dos paquetes y los dos
targets de prueba, la genera con `xcodegen` —**en la copia, nunca en el repo**—
y lanza `xcodebuild test` contra el aparato. Sin `--limpio` reutiliza la copia:
rehacerla de cero cuesta unos 8 minutos por vuelta y no hace falta cuando lo
único que cambió es una prueba.

### Lo que en el simulador se hacía de otra forma

| En el simulador | En el aparato |
|---|---|
| `simctl io screenshot` (`capturar.sh`) | `XCUIScreen.main.screenshot()` escrita a `Documents/` desde la prueba y sacada con `devicectl device copy from`. **Del contenedor del RUNNER**, no del de la app: `--domain-identifier church.tamio.native.PruebasUIAparato.xctrunner`. En el teléfono salen **derechas**, no rotadas como en el iPad apaisado. |
| `xcresulttool` para sacar adjuntos | En **Xcode 26.6** el subcomando es `xcresulttool export attachments` (y `get attachments`); el `export object` de antes está deprecado. Confirmado, pero escribir a `Documents/` sigue siendo más barato. |
| `simctl ui content_size accessibility-medium` | A mano: Ajustes · Accesibilidad · Pantalla y tamaño de texto. **El tamaño de fábrica del aparato es `large`**, no el `medium` del simulador. |
| `simctl ui appearance dark` | No sirve: la app fija `preferredColorScheme` desde `prefs.tema`. Va por argumento de lanzamiento, `-prefs.tema oscuro`. |
| `-prefs.idioma espanol` | Igual que en el simulador: los argumentos de lanzamiento llegan también al aparato. |
| `simctl spawn log stream` | `log stream` desde el Mac contra el aparato, o Console.app. Control positivo obligatorio antes de creerse un silencio. |
| `simctl uninstall` | `xcrun devicectl device uninstall app --device <id> church.tamio.native` — se lleva la base local. |
| Face ID con `notifyutil` | Face ID de verdad. |
| Girar el simulador | **No aplica en el teléfono: es solo vertical a propósito** (`project.yml:69`). Medido: `XCUIDevice.shared.orientation = .landscapeLeft` en el iPhone **no rota nada y no falla**, así que una prueba escrita para el iPad se cree que mide otra postura. |
| — | **Modo avión, la zona horaria y el reloj**: los tres solo existen aquí. |

`pruebas/contraste.py` sigue valiendo, **comprobando la escala**: en el
iPhone 17 Pro Max la ventana son 440×956 pt y la captura 1320×2868 px, o sea
**×3**. Se divide, no se da por hecho.

### Los dos identificadores del mismo teléfono

`devicectl list devices --json-output` los da los dos y no son intercambiables:

- `identifier` → el `--device` de `devicectl`: `D66FF4DA-EC57-55D8-B4D4-8EF1B74DADE7`
- `udid` → el `-destination 'id=…'` de `xcodebuild`: `00008150-0005793E3EC0401C`

**Y hay un SIMULADOR llamado igual que el teléfono** (`iPhone 17 Pro Max`), así
que por nombre se coge el que no es. Por eso el script pide el UDID.

### Cuatro cosas que costaron una vuelta cada una

- **El `DEVELOPMENT_TEAM` va en `settings.base`**, no solo en los targets de
  prueba: sin él falla la firma del target de la **APP**, que es donde nadie lo
  busca. El `.pbxproj` de verdad lo lleva y `xcodegen` no lo inventa.
- **Los targets de prueba tienen que entrar DENTRO del `targets:` que ya
  existe.** Apendar `packages:` primero y los targets después los mete como
  hijos del paquete, y `xcodegen` contesta `Unknown package requirement` sin
  decir dónde.
- **Hay DOS `DerivedData/Tamio-*`.** El glob `Tamio-*/Build/Products/…` de la
  receta escrita se expande a dos rutas y puede instalar el `.app` de anteayer.
  Se mira la fecha y se pasa la ruta entera.
- **Ni el script ni `xcodebuild` se pasan por un `tail` o un `grep`**, y esta
  vez lo pagué yo: el código de salida pasa a ser el del último comando de la
  tubería, y `xcodegen` fallando me dio **exit 0**. Es el mismo aviso que ya
  estaba escrito para `grep`, y aplica igual a `tail`.

### Y el silencio que más caro sale

**`-only-testing` con el nombre del ARCHIVO no selecciona nada y no avisa.**
`pruebas/TextoBrutoUITests.swift` declara la clase **`TextoBruto`**, así que
`-only-testing:PruebasUIAparato/TextoBrutoUITests` se salta en silencio. Hay
que contar las pruebas ejecutadas, siempre.
