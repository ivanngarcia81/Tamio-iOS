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
