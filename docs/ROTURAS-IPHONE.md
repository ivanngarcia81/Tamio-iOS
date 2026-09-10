# Roturas del iPhone · pasada de QA adversario · 9 de septiembre de 2026

**Solo iPhone.** El árbol compacto (`IPhoneRootView`, `RootView:322`), en
iPhone 17e (`535B863C-BCD2-4D92-AB5D-6FE9ED41FF02`), en los dos idiomas, con el
tamaño de letra de fábrica (`large`) y con AX1. El iPad va en otra sesión: aquí
solo se anota, al final, lo que sus gemelas comparten.

**Cada hallazgo se reprodujo dos veces y se midió en la app corriendo o con una
prueba que hoy falla.** Las pruebas están en `pruebas/`, con la cabecera que
dice qué cazan y cómo se corren. Ninguna afirmación de este documento sale de
leer el código a secas: lo que solo se dedujo leyendo está marcado como tal.

**Lo que esta pasada NO pudo tocar, y por qué:** el entorno de esta sesión no
tiene red, así que no hay forma de entrar con una cuenta. Sin sesión la app se
queda en la puerta (`TamioApp.contenido`, caso `.sinSesion`), de modo que **la
cola de salida, la sincronización, los folios del servidor, los roles contra
RLS, borrar cuenta y el candado biométrico no se ejercitaron.** Todo lo de
abajo se midió con el modo revisión encendido en la copia, salvo lo de la base
local, que corre contra la base de archivo de verdad.

---

## Los hallazgos, por severidad

### 1 · Con la región en español, cada importe con decimales se guarda multiplicado por cien

**Severidad: cifra falsa, y en la puerta por la que entra todo el dinero.**

El `.decimalPad` de un iPhone con región española ofrece **solo la coma**. No es
que la coma sea una opción: **no hay tecla de punto**. Volcado del teclado con
la app corriendo (`pruebas/ImporteEnPantallaUITests.swift`,
`testQueTeclaOfreceElTecladoEnEspanol`):

```
TECLAS: 1|2|3|4|5|6|7|8|9|,|0|Delete
```

Y `NuevoMovimientoView.aCentavos` (`NuevoMovimientoView.swift:550`) borra las
comas y hace `Double(...) ?? 0`:

```swift
let limpio = s.replacingOccurrences(of: ",", with: "")
return Int(((Double(limpio) ?? 0) * 100).rounded())
```

**Reproducción**, dos veces, `testDoceCincuentaLlegaAlLibroComoMilDoscientos`:

1. Región del aparato `es_ES`, app en español.
2. Tesorería → Movimientos → Nuevo.
3. Teclear `12,50` — el campo muestra `12,50`, Guardar se enciende.
4. Guardar.

**Lo que pasa:** la fila del libro dice `+$1250,00`.
**Lo que se esperaba:** `+$12,50`.

No es un caso raro: es **todo importe con céntimos tecleado en una región de
coma decimal**. Los números medidos, del mismo caso en unitaria
(`pruebas/ImporteDelAltaTests.swift`), comparando contra `Money.desdeTexto`, que
es el parseador bueno y el que usa el importador de aportes:

| Tecleado     | `Money.desdeTexto` | lo que guarda el alta | error   |
|--------------|--------------------|-----------------------|---------|
| `12,50`      | $12.50             | **$1,250.00**         | ×100    |
| `1,5`        | $1.50              | **$15.00**            | ×10     |
| `1.960,00`   | $1,960.00          | **$1.96**             | ÷1000   |
| `$ 1 960,00` | $1,960.00          | **$0.00**             | todo    |

**Hay dos parseadores de dinero en la app y el alta manual usa el malo.**
`Money.desdeTexto` (`Money.swift:114`) aguanta los dos mundos y lo explica en su
propio comentario —"manda el último separador que aparezca"—; lo usan el
importador de aportes, los recurrentes y la segunda firma. El alta, no.

**Prueba:** `pruebas/ImporteDelAltaTests.swift` (8 casos, 11 asertos en rojo hoy)
y `pruebas/ImporteEnPantallaUITests.swift`.

**Y una segunda mitad, para quien lo arregle:** `aTexto` escribe con
`String(format: "%.2f")`, o sea siempre con punto. Al **editar** un movimiento
en región española el campo se abre con `1960.00` y el teclado no tiene con qué
escribir ese punto. Vuelve a entrar redondo (`aCentavos("1960.00")` = 196000),
pero si la tesorera corrige un dígito y reescribe la parte decimal con la única
tecla que tiene, sale `1960,00` → **$196,000.00**.

---

### 2 · La base cae a memoria sin decirlo, se pierde el día entero, y encima no se puede respaldar

**Severidad: pierde datos. Es lo más grave que puede tener la app.**

`BaseLocal.init` (`BaseLocal.swift:21`) abre `tamio.sqlite`; si el archivo no
abre **o si `migrate` lanza**, se cae a una base en memoria y sigue como si
nada. `enMemoria` existe, pero un `grep` sobre todo `Tamio/` da **siete
apariciones y ninguna en una vista**: solo lo miran `Respaldo` (dos veces),
`Compactacion` (dos) y `BorradoMasivo` (una), y todas para lanzar `sinBase`.

**Reproducción**, dos pasadas sobre el mismo contenedor
(`pruebas/BaseMudaTests.swift`):

1. Pasada 1 (`test1_sembrarYDecirDonde`): con la base sana, escribir un
   movimiento y comprobar `enMemoria == false`. Imprime la ruta del archivo.
2. Desde el shell, estropear ese archivo — se simuló un respaldo restaurado a
   medias poniendo a cero los primeros 4 KB y dejando el tamaño intacto:
   `sqlite3` contesta `file is not a database (26)`.
3. Pasada 2 (`test2_seguirAhi`): lo que la tesorera da por hecho.

**Lo que pasa:**

```
EN-MEMORIA:true FILAS:0
RESPALDO-FALLA:sinBase
```

Y esto es lo que ve ella, medido en pantalla
(`pruebas/RespaldoUITests.swift`, captura adjunta a esta sesión):

- La app arranca **como recién instalada**. Nada dice que pasa algo.
- Se puede trabajar toda la tarde: los ingresos se guardan, los cortes se
  cierran. Al cerrar la app **no queda nada**, y la cola de salida se va con
  ellos, así que tampoco subió nada.
- El único rastro en toda la app aparece en Ajustes · Zona de riesgo, y **solo
  si pulsa "Respaldar ahora"**: una línea roja que dice *"This device's database
  isn't available."* — que es justo el momento en que ya no puede salvar nada.
- En esa misma pantalla, "Storage on this device" se queda en **"Measuring…"
  para siempre**: `Compactacion.medir()` devuelve `nil` con la base en memoria
  (`Compactacion.swift:53`) y la vista no distingue "midiendo" de "no hay base".

**Control positivo, para que la medida valga:** con la base sana y el mismo
recorrido, "Respaldar ahora" sí presenta la hoja de compartir con
`tamio-2026-09-09.zip · 7 KB`. O sea que el botón funciona; lo que falla es
todo lo que hay detrás, en silencio.

**Y es permanente:** el archivo estropeado se queda estropeado, así que cada
arranque siguiente vuelve a caer en memoria. No hay recuperación ni aviso.

**El camino que ya está documentado y que lleva aquí solo:** §3 del traspaso
avisa de que "si `migrate` lanza, `BaseLocal` se cae a una base EN MEMORIA sin
avisar". Esto lo confirma y añade lo que faltaba: no es solo que el fallo se
note tarde, es que **la salida de emergencia está cerrada con llave desde
dentro**.

---

### 3 · El alta guarda movimientos de $0.00, negativos y de mil millones

**Severidad: cifra falsa.**

Guardar se enciende con `!importe.isEmpty` (`NuevoMovimientoView.swift:147`) y
`aCentavos` devuelve `0` ante cualquier cosa que no entienda.

**Reproducción** (`pruebas/MonedaYCeroUITests.swift`,
`testGuardarUnMovimientoDeCero`):

1. Tesorería → Movimientos → Nuevo.
2. En el importe teclear `..` — dos puntos, que el `.decimalPad` deja escribir.
3. Guardar se enciende. Pulsarlo.

**Lo que pasa:** entra en Ingresos una fila `Tithe · Folio 1045 · Cash ·
+$0.00 · Not deposited`. Con folio gastado, contando para el corte y para la
constancia anual del aportante.

Y de la unitaria, sobre el mismo `aCentavos`:

- `-50` → **−$50.00 como ingreso**. La dirección del dinero ya la lleva el tipo
  (ingreso/gasto), así que un importe negativo la invierte dos veces.
- `1e9` → **$1,000,000,000.00**. `Double` acepta la notación científica.
- `mil`, `..`, `—`, `$ 1 960,00` → **$0.00**, todos.

**Lo que hace más raro que esté así:** la app **ya sabe hacerlo bien en otra
pantalla**. `EditarRecurrenteView:92` apaga su botón con
`.disabled((Money.desdeTexto(importe) ?? 0) <= 0)` y vuelve a comprobarlo antes
de guardar (`:112`). Es exactamente la validación que le falta al alta.

**Prueba:** `pruebas/ImporteDelAltaTests.swift`
(`testLoQueNoSeEntiendeNoDebeValerCero`, `testNoSeCuelaUnImporteNegativo`,
`testNotacionCientifica`) y `pruebas/MonedaYCeroUITests.swift`.

---

### 4 · Corregir un asunto en «Por revisar» no guarda nada de lo que se corrige

**Severidad: cifra falsa que la tesorera cree haber arreglado.**

La bandeja existe para arreglar lo que está mal. Su hoja de edición
(`EditarAsuntoView`) ofrece seis campos: concepto, importe, categoría, método,
aportante y fecha. **Ninguno se queda.**

**Reproducción**, dos veces (`pruebas/RevisarEdicionUITests.swift`):

1. Por revisar → abrir *"Missions · La Esperanza Mission Church"* (−$600.00).
2. Editar → cambiar el importe de `600.00` a `1.00`.
3. "Save changes".

**Lo que pasa:** el detalle sigue diciendo `Amount −$600.00`, y la descripción
sigue diciendo *"for $600.00"*.
**Lo que se esperaba:** −$1.00.

**El control que hace precisa la queja** (`testLaCategoriaSiSeQueda`): se repitió
cambiando **la categoría** de Missions a Cleaning, que es el único campo que el
repositorio dice escribir. Tampoco se queda: el detalle sigue en `Missions`.

La causa está a la vista en `RevisarRepository.swift:85`:

```swift
func actualizar(_ r: Revision) async {
    guard var m = await movimiento(de: r.id) else { return }
    if let cat = r.editCategoria, !cat.isEmpty { m.categoria = cat }
    try? await movimientos.actualizar(m)
}
```

Cinco de los seis campos **no se escriben en ninguna parte**. El sexto sí se
escribe y aun así no se ve, y ahí hay dos candidatos que quien lo arregle tendrá
que separar: o el `try?` se está tragando el fallo, o la pantalla lee
`categoriaCompleta` mientras la escritura toca `categoria`
(`CalculadoraRevisiones.swift:213` compone la `Revision` con `m.categoria`, pero
la fila "Category" del detalle sale de `campos(m)`). **No lo he determinado**:
lo que está medido es que al usuario no le llega ninguno de los seis.

El cableado está comprobado y no es el problema: `RevisarView:52` llama a
`vm.editar`, y `RevisarViewModel.editar:109` construye la `Revision` con los seis
valores nuevos antes de pasársela al repositorio. Es el repositorio el que los
tira.

---

### 5 · El importador de aportes lee como dinero cosas que no lo son

**Severidad: cifra falsa, y en bloque — un CSV mete muchas filas de una vez.**

`Money.desdeTexto` empieza borrando **todo lo que no sea dígito, punto, coma o
menos**. Es lo que le permite aguantar `$1,960.00 USD`, y está bien; el problema
es que no hay ningún límite después, así que un texto que no es un importe sale
convertido en uno **plausible**:

| En la celda    | Lo que entra en el libro |
|----------------|--------------------------|
| `1e9`          | **$19.00**               |
| `12 pesos 34`  | **$1,234.00**            |

El importador ya rechaza lo que no entiende y lo enseña como *"Monto no
válido"* en la previa (`ImportadorAportes.swift:121`, con su `centavos > 0`), así
que la tesorera confía en esa previa. Aquí no hay nada que rechazar: la fila sale
en verde con una cifra que no es la del archivo.

**Prueba:** `pruebas/CSVQueMienteTests.swift`,
`testUnImporteConLetrasSeDeberiaRechazar`.

---

### 6 · Dos columnas del CSV con el mismo nombre: siempre gana la primera

**Severidad: cifra falsa, condicional a un archivo concreto.**

Pasa al pegar dos hojas en Excel. El paso de mapeo ofrece las dos columnas
—se llaman igual, no hay forma de distinguirlas— y `CSVLector.aplicar` resuelve
con `doc.encabezados.firstIndex(of: col)` (`CSVLector.swift`), así que **elija la
que elija, se lleva la primera**.

Medido con `nombre,monto,monto` y la fila `Ana,100,999`: pidiendo la columna
`monto` sale `100`, y no hay ninguna forma de pedir el `999`.

**Prueba:** `pruebas/CSVQueMienteTests.swift`, `testColumnasDuplicadas`.

---

### 7 · El "$" está escrito a mano en cuatro sitios y no sigue a la moneda de la iglesia

**Severidad: molesta, pero se lee como una cifra en otra moneda.**

**Reproducción** (`pruebas/MonedaYCeroUITests.swift`,
`testCambiarLaMonedaAEuros`): Ajustes → Iglesia → Moneda → `EUR €`. Después,
Tesorería.

Las listas obedecen —`+€2,500.00`, `+€6,845.00`—, pero la hoja de alta enseña
**`$` arriba del campo y `EUR` justo debajo**, a dos renglones uno del otro.

Los cuatro sitios, encontrados con `grep` y confirmados en pantalla el primero:

- `NuevoMovimientoView.swift:385` — el campo del alta (**visto**).
- `EditarAsuntoView.swift:64` — el campo de la hoja de «Por revisar» (**visto**
  en el volcado: la sección `AMOUNT` lleva un `$`).
- `Views/Components/CategoryDonutChart.swift:21` — el centro de la dona.
- `RevisarView.swift:298` — el importe de cada fila de la bandeja.

El resto de la app lee `Money.moneda`, que existe precisamente para esto y lo
dice en su comentario: *"antes 'MXN' y el '$' iban escritos a mano en cada
pantalla, así que cambiar de moneda en Ajustes no cambiaba nada en ninguna"*.
Quedaron cuatro.

---

### 8 · Un CSV con `;` de separador y una coma dentro del encabezado se lee como una sola columna

**Severidad: molesta. Falla ruidosamente, no en silencio.**

`detectarSeparador` cuenta `;` contra `,` en la primera línea **sin mirar las
comillas**. Con `"nombre, apellido";monto` gana la coma y el archivo entero se
queda en una columna llamada `nombre, apellido;monto`. La previa dice que faltan
las columnas obligatorias, así que nadie importa nada mal — pero el archivo es
correcto y la app dice que no.

**Prueba:** `pruebas/CSVQueMienteTests.swift`,
`testSeparadorConComaEnElEncabezado`.

---

## Lo que se atacó y aguantó

Va aquí porque una pasada de bugs también sirve para dejar de sospechar, y
porque tres de estos estaban en la lista de sospechosos de esta sesión.

- **Las presentaciones apiladas NO se pisan en iOS 26.** Era el sospechoso nº 6
  y es la causa exacta que dejó los dos importadores sin abrir (`57a2adb`).
  Probadas una a una (`pruebas/PresentacionesUITests.swift`,
  `pruebas/TecladoYHojasUITests.swift`): Membresía abre sus filtros y su alta
  (`["Membership"] → ["Filters", "Membership"]` y `→ ["New member",
  "Membership"]`); Movimientos abre el alta y la hoja de filtros; y los tres
  `.sheet(item:)` de Zona de riesgo presentan la hoja de compartir. **Aviso para
  el que lea esto dentro de un mes:** lo que se midió es que varias `.sheet`
  sobre el mismo cuerpo conviven. Lo que rompió los importadores era otra cosa
  —`.sheet(isPresented:)` con un `if let` dentro, §0.-7— y ese patrón sigue
  siendo veneno.
- **La barra no descarta ninguna cápsula, ni siquiera en AX1.** Volcado de las
  cuatro pantallas de lista en inglés, con `large` y con `accessibility-medium`,
  y **son idénticas** (`pruebas/CapsulasDeBarraUITests.swift`):
  Movimientos 4 (`Period and filters: September ‖ New ‖ Income ‖ Expenses`),
  Aportantes 5, Depósitos 5, Membresía 4. Movimientos no gasta cápsula en el
  buscador porque usa el cajón, que es la decisión que ya está escrita en
  `MovimientosView:125`.
- **El doble toque en Guardar no duplica.** «Guardar y agregar otro» pulsado dos
  veces seguidas deja **una** fila y ningún folio repetido: el formulario se
  vacía en el primer toque y el botón se apaga solo. En el «Guardar» de la barra
  el segundo toque ni encuentra el botón, porque la hoja ya se cerró
  (`pruebas/DobleToqueUITests.swift`).
- **El teclado no tapa el importe.** Pantalla 844 pt, teclado 233, libres 611; el
  campo enfocado está en y=125. Lo que queda debajo es formulario, y se
  desplaza.
- **El lector de CSV aguanta casi todo lo que se le echó:** BOM de Excel, filas
  vacías en medio y al final, comas dentro de un nombre entrecomillado
  (`"Márquez Peña, Lucía"`), encabezados en el otro idioma, los dos formatos de
  importe, y **5.000 filas en 0,02 s**.
- **El 31 de febrero se rechaza.** `Fechas.desdeTextoFlexible("31/02/2026")` da
  `nil`. Año 1900 y año 2999 se aceptan y se imprimen bien.
- **Restaurar un respaldo está bien blindado:** transacción, tabla por tabla y
  columna por columna cruzando nombres, y rechaza un respaldo con migraciones
  que esta app no conoce. Un respaldo corrupto revienta dentro de la transacción
  y deja el aparato como estaba.

Y una **observación sin acción**: `Fechas.desdeTextoFlexible` prueba
`dd/MM/yyyy` antes que `MM/dd/yyyy`, así que un CSV exportado por un programa en
inglés con `09/03/2026` entra como **9 de marzo**, no como 3 de septiembre. Es
una decisión consciente y documentada (la app se usa en México y España), la
previa del importador enseña la fecha ya interpretada, y no hay forma de
adivinar sin preguntar. Se anota, no se propone cambiarlo.

---

## Orden de arreglo que propongo

Decide tú; esto es solo cómo lo ordenaría yo, y por qué.

1. **El nº 1 y el nº 3 juntos, en `NuevoMovimientoView`.** Son el mismo arreglo:
   que el alta use `Money.desdeTexto` y que Guardar exija un importe > 0, como
   ya hace `EditarRecurrenteView`. Es el cambio más pequeño de la lista y el que
   más dinero toca. Con las pruebas ya escritas, se sabe al momento si entró.
2. **El nº 2, la base muda.** Es el único que pierde datos, pero va después
   porque el arreglo es más de diseño que de código: hay que decidir **qué se le
   enseña** a la tesorera —un aviso fijo como el del modo revisión es lo que ya
   hay en la casa— y si la app debe **negarse a escribir** en vez de aceptar
   trabajo que va a tirar. Lo segundo es lo que yo defendería: una app que no
   deja capturar es un mal día; una que acepta la captura y la pierde es un mes
   descuadrado.
3. **El nº 4, «Por revisar».** Bloquea un trabajo entero —la bandeja existe para
   corregir— y el diagnóstico ya está hecho hasta la línea. Antes de escribir el
   arreglo, separar los dos candidatos del campo `categoria`: son dos bugs o
   uno, y no se sabe todavía.
4. **El nº 5**, el importe con letras. Una condición en `Money.desdeTexto`: si
   se borró algo que no era símbolo de moneda ni espacio, devolver `nil`.
5. **El nº 7**, los cuatro `$`. Cuatro líneas, cero riesgo.
6. **El nº 6 y el nº 8**, los dos del CSV. Los dos piden pensar el caso raro y
   ninguno corre prisa.

---

## Lo que probablemente comparte el árbol del iPad · para la sesión siguiente

**No comprobado.** Sale de mirar quién dibuja cada vista, no de correr nada en
un iPad.

**Lo que es la MISMA vista en los dos árboles**, así que el fallo es idéntico y
el arreglo lo cura de una vez:

- **Nº 1 y nº 3 (el importe del alta).** `NuevoMovimientoView` la presentan
  `MovimientosView` y `DashboardView`, que sirven a los dos árboles. En el iPad
  cambia una cosa que conviene medir allí: **con teclado físico el `.decimalPad`
  no manda**, así que el punto sí se puede escribir y el fallo puede no aparecer
  — lo cual lo hace *peor*, no mejor: aparece solo con el teclado en pantalla.
- **Nº 4 («Por revisar»).** `RevisarView` y `RevisarRepository` son comunes.
- **Nº 5 y nº 6 (CSV).** `Money.desdeTexto` y `CSVLector` son comunes, y el
  importador del iPad ya está probado en `pruebas/ImportarIPadUITests.swift`.
- **Nº 7 (los cuatro `$`).** `NuevoMovimientoView:385`, `EditarAsuntoView:64`,
  `CategoryDonutChart:21` y `RevisarView:298` se dibujan igual en iPad. Y hay
  **un quinto sitio propio del iPad que no he mirado**: `ConfiguracionView:550`
  lleva su propio `Picker` de moneda.

**Lo que es OTRA vista y hay que volver a mirar allí:**

- **Nº 2 (la base muda) en `SeccionZona`**, la Zona de riesgo del iPad
  (`ConfiguracionView:1364`). Es código separado de `AjustesZonaView`, pero llama
  a los mismos `Respaldo.crear()` (`:1596`) y `Compactacion.medir()` (`:1502`),
  así que **hereda las dos mitades del fallo**: el "no está disponible" tardío y
  el "Measuring…" eterno. Hay que comprobar si además enseña algo más o menos que
  la del teléfono.
- **Las cápsulas de la barra.** En el teléfono salieron limpias en AX1, pero la
  barra del iPad es de la pantalla entera y con la sidebar fijada el ancho útil
  baja: el recuento hay que rehacerlo allí, no heredarlo.

**Y lo que esta pasada dejó sin tocar en el teléfono**, por si la siguiente
quiere recogerlo:

- Todo lo que pide cuenta: cola de salida, sincronización, reintento idempotente,
  el mismo registro editado en dos aparatos, token expirado, roles contra RLS,
  borrar cuenta, candado biométrico.
- Los PDF: mes sin movimientos, 500 movimientos, sin logo ni firmas, compartir
  mientras se genera.
- `CorteDetalle` y `ActasView`: se llegó a la lista de Depósitos y a la de Actas
  y se volcó la barra, pero **no se abrió ninguna ficha**, así que sus cuatro
  hojas y su alerta siguen sin probarse.
- Un nombre de iglesia de 500 caracteres en el membrete: el intento de esta
  sesión no llegó a vaciar el campo y no mide nada. La prueba está escrita en
  `pruebas/TextoBrutoUITests.swift` pero **no sirve como está**.
