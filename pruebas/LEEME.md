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

**Y un aviso sobre lo que estas pruebas NO pueden medir:** XCUITest lista los
elementos aunque lleven `accessibilityHidden(true)` —comprobado poniéndoselo al
aviso del modo revisión, que siguió apareciendo en el volcado—. Así que con el
árbol de XCUITest no se puede saber qué lee VoiceOver: eso pide VoiceOver de
verdad.
