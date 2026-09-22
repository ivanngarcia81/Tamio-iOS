# Las rojas de septiembre · iPhone

22 de septiembre de 2026. Esto lo investigó un equipo de tres: **datos**, **navegacion** y **abogado**, este último encargado de refutar a los otros dos. Los tres solo leyeron: código, documentación, git, los registros que quedaron de las corridas y una base SQLite en solo lectura. **No se corrió ninguna prueba ni se tocó código.** El punto de partida es `CONTEXTO.md §0.-22`, que dejaba 44 rojas «de verdad» en 26 clases, con solo 7 demostradas como no nuestras.

## Lo que sale, en cinco líneas

1. **Ninguna de las 44 rojas es un fallo de la app, y ninguna es una regresión nuestra.** El diff de la app `2555d99..HEAD` no toca navegación, hubs, barra lateral ni la regla de compartir. Y el binario de la corrida parcial de las 03:42 del 22-sep es de `2555d99`. Detalle en «Cómo se sabe» (A1).
2. **Son 28 clases, no 26. Y 25 de las 44 rojas son pruebas de iPad** que se corrieron en el teléfono. `aparato_yaml.py` incluye `*UITests.swift` sin filtrar por aparato, y ninguna de ellas se omite en iPhone. Contarlas como rojas «de verdad» del teléfono es el mismo error de categoría que §0.-22 le reprocha a los paseos.
3. **§0.-22 se equivoca con `DocumentosPDFUITests`.** Su roja también es de datos: la firma de la carta sale del pastor de Ajustes, que en la iglesia sincronizada está vacío.
4. **Hay un fallo real de la app, que no explica ninguna roja.** El primer arranque en un aparato nuevo decide si pedir la configuración de la iglesia con el nombre de ANTES de sincronizar. Si la vuelve a pedir y se rellena, puede pisar en el servidor los datos de la iglesia. Ver §3.
5. **La corrida de las 03:41 del 22-sep probablemente dejó cambiada la iglesia sincronizada:** un ingreso de 12,50, la moneda en euros y dos asuntos devueltos al tesorero. Esa iglesia es toda de pruebas —lo confirmó Iván el 22-sep—, así que no hay daño; lo que hay es **deriva**: la corrida siguiente arranca con otros datos que la anterior. Ver §2.

## 1. Clase por clase

Leyenda de la columna **Evidencia**:
- **L** = hay línea de fallo registrada.
- **I** = sin línea: la salida se cortó (`aparato.sh:91-92`, `sort -u | head -60`) y `prueba.log` se pisó a las 06:45 con una corrida de simulador. La causa se infiere del código.

Son 22 rojas en I.

### Tanda de cartas (6 clases, 7 rojas; mismo resultado exacto en `2555d99`)

| Clase · rojas | Causa | Evid. | ¿Es de la app? | Arreglo propuesto |
|---|---|---|---|---|
| `ConstanciaIPhone` · 1 | Busca «Ana Lucía Torres Beltrán», que es de maqueta (`MiembrosRepository.swift:114`). La iglesia tiene «Ana Torres». | L `:61` | No: **datos** | `-modoRevision YES`, ya puesto en `58d6a71`. Ojo: el «pasa» de §0.-22 es **en simulador**, no en el iPhone. |
| `DocumentosPDFUITests` · 1 (`testLaCartaCompleta…`) | La carta cuenta **4** campos: aportante, iglesia de destino, miembro desde y firma (`Secretaria.swift:723-726`). La firma se propone desde `config.pastorNombre` (`:712`). La prueba teclea 3 (`:58-65`). Con el pastor vacío la carta queda en 3 de 4, y `puedeCompartir` es falso (`CartasView.swift:1310,1336`), así que el «Share» no se dibuja (`SecretariaPDF.swift:335`). La maqueta tiene «Pastor Abel Ramos» (`ConfiguracionIglesiaRepository.swift:101`). La prueba es de `af89086`, del 7-sep a las 13:32. Una hora después, `d13d775` empezó a contar la firma. | L `:70` | No: **datos de configuración** | Teclear también «Signature (pastor)», o `-modoRevision YES`. Su propia cabecera ya pide el modo revisión (`:3-4`). |
| `FilaTraslado` · 1 | Prueba de iPad: busca el botón «sidebar». Detrás pide «Transfer in progress», que es de maqueta. | L `:20` | No: **iPad + datos** | Omitir en teléfono + `-modoRevision YES` |
| `LogoUITests` · 2 | **La de la carta:** busca «Iglesia Nueva Vida», el nombre de maqueta (`ConfiguracionIglesiaRepository.swift:82`). **La del PDF:** toca por coordenadas fijas (`:41`, `(0.893, 0.129)`), y Reportes se rediseñó en tarjetas entre `1b4d7b1` y `47a99b1`, antes de `2555d99`. Que el botón cambiara de sitio es inferido. | L `:57`, `:43` | No: **datos / prueba atrasada** | `-modoRevision YES`, y tocar «PDF preview» por su rótulo (`ReportesView.swift:262`) |
| `PlantillasDeCartaUITests` · 1 (20 vueltas) | «No se llegó a Cartas» es falso: sí se llega, porque DocumentosPDF `:48` y Logo `:55` entran por la misma fila. Lo que falta es el testigo `staticTexts["Templates"]`. Desde `fcca3a2` (13-sep, el carrusel) «Templates» en el iPhone solo es un segmento del `Picker` (`CartasView.swift:137-143`). La cabecera de texto es solo del iPad (`:692`). | L `:70` | No: **prueba atrasada** | Testigo `segmentedControls.buttons["Templates"]`, o reescribirla contra el carrusel. **Hoy nada vigila en el iPhone la carrera de «8 de 40»** (`CartasViewModel.swift:48-56`). |
| `TrasladosYMembreteUITests` · 1 | `buttons["Membership reports"]` en coincidencia exacta. La fila es un `NavigationLink` con `HubRow` y su rótulo es compuesto: «Membership reports, Overview, roster & tracking» (`IPhoneSecretariaView.swift:82-87`). Ese rótulo es lo correcto para VoiceOver. Detrás busca `TS-2026-011`, de maqueta (`MembresiaRepository.swift:156`). | L `:18` | No: **prueba + datos** | `BEGINSWITH 'Membership reports'` + `-modoRevision YES` |

**El hilo de §0.-22, «el acta pasa y la carta falla en la misma clase», no apunta a la navegación.** Las dos pruebas navegan igual. La diferencia es qué comprueban:
- `testElActaTienePDF` solo afirma que existe el título «PDF preview» (`:38`) y **nunca mira Share**.
- La carta exige Share, y Share depende de los 4 campos.

Comparar las dos no discrimina: el acta seguiría verde aunque compartir estuviera roto.

### Las otras 22 clases (37 rojas)

| Clase · rojas | Causa | Evid. | ¿Es de la app? | Arreglo propuesto |
|---|---|---|---|---|
| `AjustesAcceso` · 1 | Mide el Ajustes del iPad. En el teléfono «Send invitation» es un `Button` (`IPhoneAjustesView.swift:833-843`) y «Sync now» vive en otra pantalla (`:1413`). | L `:27-29` | No: **iPad** | Omitir en teléfono |
| `AjustesPorRolUITests` · 1 | Pide una copia parcheada con el rol de tesorero (`:5-10`) y toca la barra lateral por coordenadas (`:21-23`). | L `:31` | No: **montaje + iPad** | Solo manual, o con su parche |
| `AjustesTexto` · 2 | Diseño de iPad, y el tamaño de letra se pone con `simctl` (`:9-10`), que en el aparato no existe. | L `:53-65` | No: **iPad** | Omitir en teléfono |
| `BaseCaida` · 2 | Necesita que el guion dañe `tamio.sqlite` entre pasadas (`:13-23`). En el aparato no se hace. La pasada sana sí da verde. | L `:71-99` | No: **montaje** | No correrla en el aparato |
| `ChipDePeriodoUITests` · 1 | Gira a apaisado, que el iPhone ignora (`project.yml:168`), y busca «Reports» en la barra lateral. | L `:33` | No: **iPad** | Omitir en teléfono, o darle un camino de teléfono: Treasury → `BEGINSWITH 'Reports'` |
| `ColumnaDeCristalUITests` · 4 | Su cabecera dice «solo se dibujan en iPad» (`:7-9`), pero no tiene la omisión. En el hub del teléfono ni existe la fila «Income»: se llama «Transactions». | L `:76` | No: **iPad** | Omitir en teléfono |
| `ContrasteDeCristalUITests` · 1 (H6) | «Va por el iPad» (`:54-58`): busca «Service log» desde el arranque. | L `:48` | No: **iPad** | Omitir la H6 en teléfono. **Y ver §2: las H4 escriben.** |
| `FichaAportante` (la de iPad) · 1 | Busca «sidebar». Detrás, Ana Lucía. `-modoRevision` no la salva en el teléfono. | L `:18` | No: **iPad + datos** | Omitir en teléfono |
| `FichaAportanteIPhone` · 1 | Busca «Ana Lucía» y «$2,800», de maqueta (`MiembrosRepository.swift:98,114`). | L `:57` | No: **datos** | `-modoRevision YES`, ya puesto |
| `FirmaIPhone` · 1 | Afirma que «Save» está apagado sin trazo. Desde `4b637b6` (17-sep, «Trece formularios más dicen qué falta»), Guardar está **siempre encendido** y avisa de lo que falta. No guarda sin trazo (`HojaFirma.swift:129-133,150-152`). | L `:91` | No: **prueba atrasada** a una decisión de diseño | Reescribir contra el aviso |
| `ImportarTelefono` · 2 | Necesita los CSV «givers-template» y «gifts-template» en Archivos del aparato, y toca por coordenadas (`:39-43`). | I | No, probablemente: **montaje** | Sembrar los ficheros; confianza baja |
| `ImporteEnPantalla` · 1 | Guardar siempre encendido (`NuevoMovimientoView.swift:286`). Con basura solo avisa: tanto `:292` como `:475` exigen importe > 0 (`:177-179`). | I | No: **prueba atrasada** | Reescribir. **Y ver §2: otra prueba de la clase escribió.** |
| `InicioEstrecho` · 1 | iPad mini con la barra lateral fijada. Las cifras `$28,633`, `$39,063` y `$7,518` y «Good morning, Iván» son de maqueta o dependen de la hora. | I | No: **iPad + datos** | Omitir en teléfono + `-modoRevision YES` |
| `MonedaYCero` · 1 (`…DeCero`) | Guardar siempre encendido. Con 0 avisa y no graba. | I | No: **prueba atrasada** | Reescribir. **Y ver §2: la otra de la clase pasó y escribe.** |
| `PresentacionesAparatoUITests` · 2 | **Lienzo:** misma causa que FirmaIPhone. **Corte detalle:** no comprobable. Puede influir que «Mark deposited» se apaga con $0 (`CorteDetalle.swift:541`), el menú de cuentas y las fechas en español. | I | No / **sin decidir** | Reescribir la del lienzo; volver a correr la de corte detalle |
| `ReportesEstrecho` · 2 | Declarada para el iPad de 13" y el mini; toca «sidebar» (`:27`). | I | No: **iPad** | Omitir en teléfono |
| `RevisarRedibujo` · 1 | Busca «Missions · La Esperanza Mission Church», de maqueta (`MovimientosRepository.swift:312`). Su cabecera dice «con el modo revisión ENCENDIDO». Por el recuento (2 fallos: `:35` y el toque de `:36`, que corta la prueba) **no llegó a Edit ni a Save changes**. | I | No: **datos** | `-modoRevision YES`. **Escribe: sin eso, el día que encuentre una fila tocará los libros.** |
| `SecretariaEstrecho` · 2 | iPad de 13" con barra lateral. `testInformeGeneral` busca además a «Rosa Elena Vega» y «Daniel Salas Hernández», de maqueta (`MembresiaRepository.swift:142,150`). | I | No: **iPad** (una, además datos) | Omitir en teléfono + `-modoRevision YES` |
| `SegundaFirmaSeAlcanza` · 2 | Busca el corte «Wednesday, September 2 offerings», de maqueta (`DepositosRepository.swift:287`). | I | No: **datos** | `-modoRevision YES`. **Escribe: pide una firma.** |
| `SeleccionAnunciada` · 3 | Barra lateral e `isSelected` del iPad. La de la lista busca además «Mission offering» y «Tithe · Ana Lucía…», de maqueta. | I | No: **iPad** (una, además datos) | Omitir en teléfono (`-modoRevision` ya puesto no basta) |
| `TextoGrande` · 3 | Apaisado y «sidebar» (`:29`), y AX1 por `simctl`. La pastilla exige más de 3 «Not deposited». | I | No: **iPad** | Omitir en teléfono |
| `TextosCorregidosUITests` · 2 | Busca secciones en el primer nivel, que es la barra lateral del iPad. | I | No: **iPad** | Omitir en teléfono |

### El reparto, contado

| | Rojas |
|---|---|
| Pruebas de iPad corriendo en el teléfono (6 de ellas con maqueta detrás) | **25** |
| Datos de maqueta que la iglesia sincronizada no tiene | **7**: ConstanciaIPhone, FichaAportanteIPhone, DocumentosPDF, Logo carta, RevisarRedibujo, SegundaFirma ×2 |
| Prueba atrasada a un cambio deliberado de la app | **6**: FirmaIPhone, Presentaciones lienzo, ImporteEnPantalla, MonedaYCero cero, Plantillas, Logo PDF |
| Rótulo exacto + maqueta | **1**: TrasladosYMembrete |
| Montaje que el aparato no hace | **2**: BaseCaida |
| Sin decidir, hay que volver a correr | **3**: Presentaciones corte detalle, ImportarTelefono ×2 |
| **Fallos de la app** | **0** |
| **Total** | **44** |

**Las que miden algo en un iPhone contra la iglesia sincronizada son del orden de una docena.** La cobertura de teléfono es bastante más fina de lo que dice la cifra, como ya pasaba con el iPad en §0.-22 (36 pruebas, 15 que comprueban algo).

## 2. Lo que la corrida dejó cambiado en la iglesia sincronizada

Nadie lo había contado. Sale de los recuentos «Executed N tests, with M failures» de `tel24.txt`, cruzados con cuántas pruebas y cuántas rojas tiene cada clase. Es inferencia, pero en cada caso solo cabe una lectura:

- **`ImporteEnPantalla`** tiene 4 pruebas y 1 roja, y le toca «4 tests, with 1 failure». O sea que `testDoceCincuentaLlegaAlLibroComoMilDoscientos` **pasó**. Esa prueba pulsa Guardar con 12,50 (`:118-119`) y exige verlo en la lista (`:126`): **grabó un ingreso de 12,50**.
- **`MonedaYCero`** es la única clase de 2 pruebas con 1 roja. `testCambiarLaMonedaAEuros` pasó: elige EUR (`:52-58`) y guarda (`:66`), y Ajustes se guarda solo a los 0,8 s (`ConfiguracionIglesiaViewModel.swift:64-72`). Luego exige que no quede ningún «$» (`:103-110`). Que pase implica que **la iglesia quedó en euros**. Las clases que corren después en orden alfabético pudieron correr ya en EUR.
- **`ContrasteDeCristalUITests` `testH4ToastClaro` y `testH4ToastOscuro`** pasaron, en `HEAD` y en `2555d99`. Cada una pulsa **«Return to treasurer»** sobre el primer asunto de Por revisar (`:138-144`) y no lo deshace. Son dos devoluciones por corrida.

La base local que se usó como foto de la iglesia (`tamio-antes.sqlite`) **no sirve para comprobarlo**. La creó la app del Mac el 19-sep, y su último cursor de sincronización es del 21-sep a las 19:03 EDT, antes de la corrida. Hay que leerlo en el iPhone o en Supabase:
- `iglesias.moneda` y `pastor_nombre`;
- movimientos de 1250 céntimos del 22-sep;
- el `estado_revision` de los asuntos de Por revisar.

**Todo lo de esa iglesia son datos de prueba** (Iván, 22-sep): nada de esto daña a nadie. Pero una suite que cambia la moneda y deja filas y devoluciones detrás **no da el mismo resultado dos veces**, y eso es lo que §0.-22 pedía («una prueba tiene que dejar el aparato como lo encontró»). Para que sean repetibles, tienen que llevar `-modoRevision YES`, que guarda en memoria: ImporteEnPantalla, MonedaYCero, ContrasteDeCristal (H4), RevisarRedibujo, SegundaFirmaSeAlcanza, Presentaciones, LogoUITests, DocumentosPDF y TrasladosYMembrete.

## 3. El fallo real: el primer arranque juzga con la iglesia de antes de sincronizar

Lo encontró el abogado leyendo DocumentosPDF, y navegacion lo verificó en el código. **No explica ninguna roja y no se ha reproducido.**

En `TamioApp.swift`:
1. `:138` · `ConfiguracionIglesiaViewModel.compartido.cargar()` lee la base local. Tiene `guard !cargada`, así que ya no se relee (`ConfiguracionIglesiaViewModel.swift:34`).
2. `:146` · `sincronizar()` baja la fila de la iglesia **a la base**, no al objeto compartido. El motor nunca llama a `recargar()`. Solo lo hacen el paso a primer plano (`:195`), `BorradoMasivo.swift:145` y `Respaldo.swift:282`.
3. `:164` · `decidirConfiguracionInicial()` (`:75-80`) juzga con `compartido.config.nombre`, que en un aparato nuevo sigue siendo `""`.

**Qué pasa:** en un aparato nuevo, o en el primer inicio de sesión, de una iglesia ya montada, `haceFalta` (`AccesoView.swift:862-877`) da `true` y **pide configurar la iglesia otra vez**. Es justo lo que el comentario de `:158-163` dice evitar.

**Y puede pisar datos.**
- `comenzar()` (`AccesoView.swift:1029-1034`) escribe nombre, ciudad y moneda sobre la configuración **vacía de fábrica**.
- `guardar` graba la fila entera en local (`ConfiguracionIglesiaRepository.swift:57-59`) y encola la iglesia.
- `subirIglesia` (`MotorSincronizacion.swift:2021-2063`, leído por el lead) sube **todas** las columnas: pastor, tesorero, secretario, dirección, `logo_path`, saldo inicial, pie institucional…

Si alguien rellena esa pantalla, esos campos de la iglesia se vacían en el servidor.

**Arreglo propuesto:**
- `await ConfiguracionIglesiaViewModel.compartido.recargar()` entre la sincronización (`:146`) y la decisión (`:164`).
- De defensa, que `comenzar()` parta de la configuración recién releída y no de la de fábrica.

Para comprobarlo hace falta un primer arranque, con sesión, en un aparato limpio de una iglesia ya configurada.

## 4. Correcciones a `CONTEXTO.md §0.-22`

- «44 rojas de verdad **en 26 clases**» → **28 clases**: 6 de cartas + 22 de las demás. Y 25 de las 44 son de iPad.
- «14 fallidas y 2 pasadas» en la tanda de cartas se deja fuera **1 omitida**: `TrasladosYMembreteUITests.swift:33` ya usa el salto por aparato, y es la única que lo hace.
- «`DocumentosPDFUITests` **no** [depende de la semilla] … su roja es otra cosa» → sí depende de la configuración de maqueta (el pastor).
- «`ConstanciaIPhone testLaFraseSaleEntera` pasa» → **en simulador** (`58d6a71`, a las 06:45). En el iPhone no se ha visto pasar.
- La pista «no es de cartas, es de navegación» es falsa para DocumentosPDF y para Plantillas, que sí llegan a Cartas.

## 5. Lo que haría falta para cerrar lo abierto

1. **Leer la iglesia en el iPhone o en Supabase** para lo de §2, y decidir con Iván qué se deshace.
2. **Omitir en teléfono** las 25 de iPad: `XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)`, como ya hace TrasladosYMembrete. O que `aparato_yaml.py` reparta por aparato.
3. **`-modoRevision YES`** en las que escriben o buscan maqueta (lista en §2).
4. **Reescribir las 6 atrasadas** contra lo que la app hace hoy: el aviso de Guardar, el carrusel de Cartas y el rótulo del PDF.
5. **Volver a correr las 22 sin línea**, clase por clase, conservando el `.xcresult` y sin `head -60`. Empezar por Presentaciones corte detalle e ImportarTelefono, que son las 3 sin decidir.
6. **Arreglar §3** y probarlo en un aparato limpio.

## Cómo se sabe

- **A1: la línea base era de verdad `2555d99` en un aparato físico.** El binario `Debug-iphoneos` de las 03:42 del 22-sep (DerivedData `Tamio-euhurpfpjqqeeyccfytposlvnqlo`) no contiene textos posteriores a `2555d99`: ni «It will be issued without» ni «Delivered». Sí contiene «must be completed before signing». De la tanda de cartas del 21-sep ya no queda binario.
- **Ninguna corrida llevaba `-modoRevision` ni `-bloqueo.biometrico NO`.** Las corridas son del 21-sep a las 22:28/22:45 y del 22-sep a las 03:41. Esos argumentos entraron en `58d6a71` (06:46) y `7e97169` (04:30). Los números de línea de la corrida casan con `0b8f786`.
- **El candado no intervino, y el idioma tampoco.** DocumentosPDF, TrasladosYMembrete y Plantillas tocaron «Secretary». La app arrancó en inglés con y sin `-prefs.idioma`.
- **El iPhone solo admite vertical** (`project.yml:168`), y la barra lateral solo existe con `sizeClass == .regular` (`RootView.swift:76`).
