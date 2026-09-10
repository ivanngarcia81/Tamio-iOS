# Roturas del iPhone · pasada de QA adversario · 9 de septiembre de 2026

> **Estado: los tres primeros están ARREGLADOS y verificados en la app
> corriendo** (misma sesión, más abajo cada uno lleva su apartado "Cómo quedó").
> Los hallazgos 5 a 8 siguen abiertos, y sus pruebas siguen en rojo a propósito.
>
> **Y el hallazgo 4 era peor de lo que este informe decía en su primera
> versión.** Al escribir la prueba con ids de verdad —UUID, no los "1"/"207" de
> la maqueta— salió que no era solo la edición: **aprobar y devolver al tesorero
> tampoco hacían nada**. La corrección está dentro del apartado 4.

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

**Prueba:** `pruebas/ImporteDelAltaTests.swift` y
`pruebas/ImporteEnPantallaUITests.swift`.

**Cómo quedó (arreglado).** El alta usa `Money.desdeTexto`, el mismo parseador
que el importador: `NuevoMovimientoView.aCentavos` ya no existe y en su lugar hay
`centavos(_:)`, que devuelve **opcional** —lo que no se entiende no vale cero, y
quien llama tiene que decidir—. Verificado con la app corriendo en región
`es_ES`: tecleado `12,50`, la fila del libro dice `+$12,50` (antes `+$1250,00`).
Las 8 pruebas pasan, incluida una de ida y vuelta sobre siete importes.

De paso, el campo ya no propone un punto que ese teclado no tiene: `aTexto` y el
marcador de posición usan el separador del aparato, en el alta y en la hoja de
«Por revisar».

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

**Cómo quedó (arreglado LA MITAD, y es la mitad que importaba hoy).**

Ya no es mudo. `BaseLocal` guarda el error, lo escribe en el log del sistema, y
la app lo dice en dos sitios:

- Una **franja roja fija en todas las pantallas** —"NADA SE ESTÁ GUARDANDO EN
  ESTE APARATO · cierra la app y vuelve a abrirla"—, por delante de la del modo
  revisión. Verificado con la app corriendo, con control positivo: con la base
  sana no sale, con la base estropeada sale en Inicio, Tesorería, Secretaría y
  Ajustes.
- En **Ajustes · Zona de riesgo**, qué hacer y el error tal cual
  (`SQLite error 26: file is not a database…`, seleccionable). Y ahí se acabó el
  "Midiendo…" eterno: `Compactacion.medir()` devuelve `nil` en dos casos que no
  se parecen —aún no terminó, o no hay base— y la vista ya los distingue.

Para que el aviso salga **a la primera** la base se abre ahora en
`TamioApp.init`, antes del primer dibujo: era perezosa y se construía dentro de
un `.task` posterior, así que la franja se habría evaluado antes de que nadie
supiera que la base estaba rota. Efecto lateral buscado: **también se abre en
modo revisión**, así que una migración rota se ve al arrancar en vez de
esconderse. El §3 del traspaso queda corregido.

**Lo que NO se hizo, y es decisión tuya:** la app sigue sin recuperar nada. No
aparta el archivo malo para empezar uno limpio (eso tira lo único que un forense
podría rescatar) ni se niega a escribir (eso deja a la tesorera sin capturar un
domingo). `pruebas/BaseMudaTests.swift` **sigue en rojo a propósito** para que no
se olvide, y su cabecera explica las dos opciones.

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

**Prueba:** `pruebas/ImporteDelAltaTests.swift` y
`pruebas/MonedaYCeroUITests.swift`.

**Cómo quedó (arreglado).** `guardadoHabilitado` exige ahora
`(centavos(importe) ?? 0) > 0`, que es la misma condición que
`EditarRecurrenteView` ya usaba. Verificado con la app corriendo: con `..` en el
importe, **Guardar sale apagado** (antes encendido, y guardaba $0.00). Con eso
caen los tres a la vez: cero, negativo y notación científica, porque
`Money.desdeTexto` no acepta ninguno de los tres.

La misma condición se puso en la hoja de «Por revisar», que tenía el mismo
`importe.isEmpty` y además ni leía el texto.

---

### 4 · La bandeja «Por revisar» entera es inerte con datos de verdad

**Severidad: cifra falsa que la tesorera cree haber arreglado — y la pantalla
que existe para arreglar cifras no arregla ninguna.**

> **Corrección de la primera versión de este informe.** Aquí decía "corregir un
> asunto no guarda nada de lo que se corrige", y se quedaba corto. Al escribir
> la prueba con **ids de verdad** salió que no era solo la hoja de edición:
> **aprobar y devolver al tesorero tampoco hacían nada**. Es la trampa de la
> maqueta otra vez, y esta vez me la tragué yo en la primera pasada.

**La raíz: el id de un asunto se partía por el primer guion de un UUID.**

Un asunto se identifica como `"tx-<id del movimiento>-<tipo>"`, y para
deshacerlo `RevisarCalculado.movimiento(de:)` hacía
`split(separator: "-", maxSplits: 2)` y se quedaba con `partes[1]`. Con los ids
de la maqueta —`"1"`, `"207"`— eso funciona, **y por eso la pantalla parecía
sana en modo revisión**. Los de verdad los genera
`OfflineMovimientosRepository.crear` con `UUID().uuidString`:

```
tx-C9583C40-0389-4E75-B34B-4B356E2D3808-vistoBueno
   └─ partes[1] = "C9583C40"  ← no existe ningún movimiento con ese id
```

`porId` no encontraba nada, el `guard` devolvía y **todo se iba en silencio**:
aprobar, devolver, revertir, editar y reactivar a un miembro dado de baja
(`reactivarMiembro` tenía el mismo `split`).

**Reproducción**, con `pruebas/BandejaConIdRealTests.swift` (modo revisión
APAGADO, contra la base local):

1. Sembrar un gasto pendiente con un id `UUID().uuidString`.
2. Sacarlo de `RevisarCalculado.asuntos()`.
3. `aprobar(id:)`.

**Lo que pasaba:** el movimiento seguía en `pendiente`. Igual con `devolver`
(seguía en `pendiente`) y con editar (`monto` seguía en 60000, la categoría en
"Cleaning", el método en "Cash" y la nota sin tocar).

**Y encima, la hoja tiraba cinco de sus seis campos.** Aunque el id se hubiera
resuelto, `RevisarRepository.swift:85` era:

```swift
func actualizar(_ r: Revision) async {
    guard var m = await movimiento(de: r.id) else { return }
    if let cat = r.editCategoria, !cat.isEmpty { m.categoria = cat }
    try? await movimientos.actualizar(m)
}
```

Importe, concepto, método, aportante y fecha no se escribían en ninguna parte.

**Cómo quedó (arreglado).** Cuatro cosas, y las cuatro hicieron falta para que
la tesorera vea su corrección. Se descubrieron en ese orden porque cada una
tapaba a la siguiente:

1. **El id.** `idDelRegistro(_:prefijo:)` se queda con todo lo que hay entre el
   prefijo y el ÚLTIMO guion, así que un UUID entra entero. Lo usan las cinco
   acciones, `reactivarMiembro` incluido.
2. **Los seis campos.** `actualizar` escribe importe (con `Money.desdeTexto`, y
   **no escribe** lo que no entienda: mejor la cifra vieja que un cero), nota,
   categoría —y `categoriaCompleta` con ella, que es lo que leen las listas y
   los reportes—, método, fecha y aportante. `Movimiento` tenía esos campos como
   `let`; ahora son `var`, con el porqué escrito en el modelo.
3. **La ficha empujada no se enteraba.** El teléfono empujaba el detalle con una
   COPIA del asunto (`navigationDestination(item: $abierto)`), así que se quedaba
   con la cifra vieja. Ahora lo busca por id, como ya hacía bien la columna del
   iPad con `vm.seleccion`.
4. **`Revision` definía `==` por id.** Con eso SwiftUI da por buena la vista que
   ya tiene, y la LISTA seguía en −$600.00 con el dato ya cambiado. Medido con
   `NSLog`: `asuntos(): 106 vale 100` mientras la pantalla enseñaba −$600.00.

   **Solo se tocó `Revision`.** El mismo `==` por id está en `Movimiento`,
   `Aportante`, `Acta`, `Servicio`, `Corte`, `Miembro` y `Apunte` (§0.-7 del
   traspaso), y cambiarlos todos es una tanda de regresión y una decisión tuya.
   Aquí se pudo suelto porque `Revision` no está en ningún `Set` ni en ningún
   `onChange` —comprobado con grep— y su identidad para `ForEach` y
   `.sheet(item:)` sigue siendo el id.

Verificado con la app corriendo (`pruebas/RevisarRedibujoUITests.swift`), que
mide el importe en tres momentos para distinguir cuál de las capas se rompe si
vuelve a fallar: al guardar (`−$1.00`), en la lista (`−$1.00`) y al salir y
volver a entrar (`−$1.00`). Antes: `−$600.00` en los tres.

**Dos cosas más que salieron de la misma hoja y se arreglaron de paso:**

- **El selector de aportante tenía cuatro nombres inventados escritos a mano**
  —"Pedro Salas Aguirre", "Karla Villalobos Ruiz"…—, que es exactamente lo que se
  quitó de los tres selectores de Secretaría el 6-sep y que a este se le pasó.
  Corregir el aportante de un ingreso le ponía el nombre de alguien que puede no
  existir en el padrón. Ahora lee `padronParaSelector()`.
- **El campo "Concepto" se prellenaba con el TITULAR** (`"Misiones · Iglesia La
  Esperanza"`), que es un valor compuesto de categoría y persona y no un campo
  que exista para escribirlo: guardarlo habría metido eso dentro de la nota.
  Ahora prellena y guarda `nota`, que es lo que la hoja de alta llama "Concepto"
  desde siempre.

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

## Lo que queda por arreglar

Los tres primeros están hechos y verificados corriendo. Lo que sigue abierto,
por el orden en que yo lo haría:

1. **El nº 5**, el importe con letras en el importador. Una condición en
   `Money.desdeTexto`: si se borró algo que no era símbolo de moneda ni espacio,
   devolver `nil`. Es el único que queda de la familia "cifra falsa".
2. **El nº 7**, los cuatro `$` escritos a mano. Cuatro líneas, cero riesgo.
   `NuevoMovimientoView:385`, `EditarAsuntoView:64`, `CategoryDonutChart:21` y
   `RevisarView:298`.
3. **El nº 6 y el nº 8**, los dos del CSV. Piden pensar el caso raro y ninguno
   corre prisa.

**Y una que no es un arreglo sino una decisión tuya**, la mitad que quedó del
nº 2: la app avisa de que la base se cayó, pero **sigue sin recuperar nada**.
Las dos salidas son apartar el archivo malo y empezar uno limpio —que tira lo
único que un forense podría rescatar— o negarse a escribir —que deja a la
tesorera sin capturar un domingo—. `pruebas/BaseMudaTests.swift` sigue en rojo
para que no se pierda de vista.

**La otra decisión pendiente, de la misma familia:** el `==` por id de los otros
siete modelos (§0.-7 del traspaso). Aquí se arregló solo el de `Revision`, y se
arregló porque sin él la corrección del nº 4 no se veía en pantalla. Los demás
siguen igual, y ahora hay un precedente medido de qué cuesta dejarlos así.

---

## Lo que probablemente comparte el árbol del iPad · para la sesión siguiente

**No comprobado en un iPad.** Sale de mirar quién dibuja cada vista.

**Lo que YA quedó arreglado también en el iPad**, porque es la misma vista o el
mismo repositorio en los dos árboles — hay que **confirmarlo corriendo allí**,
no darlo por hecho:

- **Nº 1 y nº 3 (el importe del alta).** `NuevoMovimientoView` la presentan
  `MovimientosView` y `DashboardView`, que sirven a los dos árboles. En el iPad
  hay algo que medir aparte: **con teclado físico el `.decimalPad` no manda**,
  así que el punto sí se puede escribir. Eso hacía el fallo *más* traicionero
  —aparecía solo con el teclado en pantalla— y ahora da igual, porque las dos
  formas entran por el mismo parseador.
- **Nº 4 (la bandeja inerte).** `RevisarRepository` es común, así que aprobar,
  devolver, revertir, editar y reactivar estaban rotos también allí y ya no lo
  están. **La parte del redibujo es a medias**: la columna del iPad lee
  `vm.seleccion` y ya iba bien, y el `==` de `Revision` era común. Lo que no
  toqué es el `navigationDestination` del iPad estrecho, que conviene mirar.
- **Nº 2, la mitad del aviso.** La franja vive en `TamioApp`, encima de
  `RootView`, así que sale igual en las dos formas. Y `BaseLocal` se abre ahora
  en `init`, que también es común.

**Lo que es OTRA vista y sigue sin mirar allí:**

- **La Zona de riesgo del iPad, `SeccionZona`** (`ConfiguracionView:1364`). Es
  código separado de `AjustesZonaView`, y **el "Midiendo…" eterno solo se
  arregló en la del teléfono**: ella llama al mismo `Compactacion.medir()`
  (`:1502`) y `Respaldo.crear()` (`:1596`), así que hereda las dos mitades del
  fallo original. Es el primer sitio que miraría la sesión del iPad.
- **Nº 7 (los `$` a mano).** Sigue abierto, y en el iPad hay **un quinto sitio
  propio**: `ConfiguracionView:550` lleva su propio `Picker` de moneda.
- **Nº 5 y nº 6 (CSV).** `Money.desdeTexto` y `CSVLector` son comunes y siguen
  abiertos; el importador del iPad ya está probado en
  `pruebas/ImportarIPadUITests.swift`.
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
