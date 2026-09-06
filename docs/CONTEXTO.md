# Contexto de trabajo · Tamio-iOS

Este archivo existe para que una sesión nueva —o una persona que vuelve dentro
de un mes— no empiece de cero. **No es documentación del código**: eso ya está
en los comentarios y en los mensajes de commit, que en este proyecto explican
el porqué y no el qué. Aquí va lo que NO se deduce leyendo el repo.

Última actualización: **5 de septiembre de 2026**.

---

## 1. Dónde está el trabajo

Rama viva: **`liquid-glass`**, sincronizada con `origin/liquid-glass`. Es donde
está todo; `main` se quedó muy atrás.

Ramas viejas ya absorbidas aquí, no hace falta volver a ellas:
`arreglos-interfaz`, `arreglos-revision-iphone`, `revision-y-motor-offline`.
`supabase-wip-respaldo` existe **solo en el Mac**, nunca se subió.

---

## 2. Tres avisos que cuestan caro

### 2.1 NUNCA correr `xcodegen generate` en este repo

**Comprobado el 5 de septiembre, no es una leyenda.** El `project.yml` **no
declara los paquetes SPM**: GRDB y supabase-swift se añadieron a mano desde
Xcode y viven solo en el `.pbxproj`. Al regenerar, el proyecto sale sin ellos y
la compilación muere con `unable to resolve module dependency: 'GRDB'`.

El `.pbxproj` está editado a mano y hay que seguir editándolo a mano al añadir
archivos nuevos. **Si puedes, evita el archivo nuevo**: mete el código en un
archivo que ya exista y el `.pbxproj` no se toca. Así se añadió
`sinBotonVolver()` dentro de `Support/NavHeader.swift`.

### 2.2 El modo revisión está ENCENDIDO

`Support/ModoRevision.swift` tiene `activada = true`: la app salta el login y
sirve datos de ejemplo. Con él encendido **no se ejercita nada de Supabase** —
ni folios, ni sincronización, ni subida de comprobantes—, y los repositorios
que se inyectan son los `Mock*`, no los `Offline*`.

Para probar de verdad hay que ponerlo en `false` y entrar con la cuenta real.
Está dentro de `#if DEBUG`, así que un olvido no llega a la App Store.

### 2.3 Compilar no es verificar

Casi todo lo escrito en las últimas semanas está **verificado solo por
compilación**. Ha pasado ya al menos una vez que algo compilaba, no daba ni
error ni aviso, y estaba roto en pantalla: el sistema descartó en silencio la
quinta cápsula de la barra y Ingresos se quedó **sin botón de crear**.

---

## 3. Cómo verificar en la app corriendo sin tocar el `.pbxproj`

Receta que funcionó el 5 de septiembre y que conviene repetir tal cual:

1. Copiar el repo a un directorio temporal (`rsync -a --exclude .git
   --exclude Tamio.xcodeproj`).
2. En la COPIA, añadir al `project.yml` un target de `bundle.ui-testing` con
   `GENERATE_INFOPLIST_FILE: YES`, **y los paquetes que faltan**:

   ```yaml
   packages:
     GRDB:     { url: https://github.com/groue/GRDB.swift,        majorVersion: 6.29.0 }
     Supabase: { url: https://github.com/supabase/supabase-swift, majorVersion: 2.5.1 }
   ```

3. `xcodegen generate` **en la copia** (nunca en el repo), compilar y correr
   XCUITest ahí.

Detalles que hacen perder tiempo si no se saben:

- Hay varios simuladores arrancados a la vez: `xcrun simctl io booted
  screenshot` coge el equivocado. **Usar siempre el UDID.**
- Al añadir un archivo de test hay que volver a correr `xcodegen` en la copia,
  o el test no entra en el bundle y sale "Executed 0 tests".
- Para fotografiar un estado transitorio: que el test imprima una marca y se
  duerma, y desde el shell esperar la marca y disparar `simctl io <udid>
  screenshot`.
- Las filas del hub no se localizan por su título: su etiqueta de
  accesibilidad es `"Transactions, 28 records · 19 undeposited"`. Usar
  `label BEGINSWITH`.
- El iPhone más estrecho con iOS 26 disponible es el **17e** (390 pt). Probar
  ahí y **en inglés**, que es donde las etiquetas son más largas.
- El tipo de target de XcodeGen es `bundle.unit-test`, **no** `bundle.unit-testing`
  (ese es el de UI). Y hay que declarar un `schemes:` con los targets de test,
  o `xcodebuild` contesta que "isn't a member of the specified test plan".

### Cómo probar una migración, que es lo que no puede fallar en silencio

Si `migrate` lanza, `BaseLocal` **se cae a una base EN MEMORIA sin avisar** y se
pierde todo lo local: una migración rota no se ve, se nota tarde. Además, **en
modo revisión la base ni se abre**, así que arrancar la app no prueba nada.

Lo que sí lo prueba, y funcionó con la v15:

1. En la copia, un target `bundle.unit-test` con `TEST_HOST` y `BUNDLE_LOADER`
   apuntando a `Tamio.app/Tamio`, para poder `@testable import Tamio` y tocar
   `BaseLocal.compartida`.
2. Correr una prueba que **siembre** una fila con el código de la versión
   ANTERIOR (`git stash` de la migración nueva basta).
3. Restaurar la migración, recompilar y correr una segunda prueba **sobre el
   mismo contenedor del simulador**: la fila sembrada sigue ahí, las columnas
   nuevas traen su valor por defecto y `enMemoria` es falso.

**Y hay que desinstalar la app entre pasos** (`xcrun simctl uninstall <udid>
church.tamio.native`): cada instalación puede estrenar contenedor, así que
borrar el `.sqlite` que encuentre un `find` no garantiza estar borrando el que
va a usar la prueba siguiente.

**Editar el cuerpo de una migración YA APLICADA no hace nada y no avisa.** GRDB
solo mira el identificador: si `v15_padron` ya está en `grdb_migrations`, el
cuerpo nuevo no corre y la columna que se añadió no existe, sin un solo error.
Pasó al añadir `activo` a la v15. Mientras una migración no haya salido del
Mac, se corrige y se prueba desde una base limpia; en cuanto haya salido, lo
que toca es una migración nueva.

El archivo está en el contenedor de la app:
`.../Devices/<udid>/data/Containers/Data/Application/<id>/Library/Application Support/tamio.sqlite`.
Se puede mirar con `sqlite3 "$DB" "select identifier from grdb_migrations"`.

---

## 4. Cosas ya medidas · no volver a discutirlas

- **`navigationBarBackButtonHidden` apaga el gesto de volver** en iOS 26.
  Medido con XCUITest: con botón visible el deslizamiento vuelve, ocultándolo
  no. Por eso existe `sinBotonVolver()` en `Support/NavHeader.swift`, que lo
  oculta Y devuelve el reconocedor. **No poner el delegado a `nil`**: eso deja
  el gesto armado también en la raíz, donde no hay nada que desapilar.
- **`.disabled` sobre `.buttonStyle(.glass)` da 1.70:1 de contraste** (el
  mínimo para texto normal es 4.5:1): la etiqueta se borra. No es culpa del
  `tint` —sin él sale el mismo número— y `.secondary` tampoco basta: 3.29:1.
  Lo que sí funciona es `.primary` rebajado: 8.4:1 en claro y 8.3:1 en oscuro.
- **El ancho del segmentado NO era la causa** de que la barra truncara. Se
  probó dos veces, y a 160 pt fijos truncaba igual. Sobraba un control.

---

## 5. Estado por zonas

### Recurrentes — escrito entero, sin probar en aparato

Cuatro commits del 4 de septiembre: modelo (`MovimientoRecurrente`, tabla
propia, **v14** local + `movimientos_recurrentes` en Supabase),
materializador, sincronización e interfaz.

**Lo que falta comprobar, y solo se ve con dos aparatos reales:**

- Que la migración **v14** corre sobre una base que ya tiene datos.
- Que la definición sube y baja de Supabase.
- **La idempotencia entre aparatos**: que al cerrar el mes la renta se genera
  UNA vez y no una por aparato. La marca `ultimoMesGenerado` la puede mover
  otro aparato; por eso la definición baja ANTES de materializar.

### Barra y pie de las listas — hecho y verificado el 5 de septiembre

El chevron se fue de las pantallas que cuelgan de un hub (la pestaña lleva al
mismo sitio), los filtros volvieron arriba y el pie de lista desapareció.

Verificado con la app corriendo en iPhone 17e y en inglés: el `+` está visible
y pulsable en Ingresos y en Gastos, el segmentado se lee entero y el gesto de
volver funciona.

Dónde acabó cada dato del pie:

| Pantalla | Antes, en el pie | Ahora |
|---|---|---|
| Ingresos/Gastos | conteo · mes · total | total y conteo encabezan la hoja de filtros; el mes ya estaba dentro |
| Aportantes | conteo · año · total | conteo en la etiqueta del menú (`Activos (9)`); año y total en su cabecera. **En iPad el pie se queda** |
| Depósitos | cortes pendientes · monto | a la cabecera, y no se dibuja con cero |

### Depósitos — un corte NO se llena solo

Preguntado y confirmado en el código el 5 de septiembre. "Nuevo corte" pide
**solo título y cuenta**; nace **vacío, en $0**. Se llena desde su ficha con
**"Agregar dinero sin depositar"**, que ofrece los ingresos que no estén ya en
otro corte (`LEFT JOIN corteMovimiento ... where cm.id is null`).

Es deliberado: un corte es *"este dinero concreto que llevo al banco hoy"*, y
casi siempre es parcial. La tabla puente en Supabase son dos columnas,
`corte_uid` y `tx_uid`, sin monto ni copia: el total nunca puede desviarse de
la suma de sus movimientos.

### Membresía — repasada el 5 de septiembre, y sigue siendo una maqueta

Se revisó botón por botón y se le puso el mismo trato que a Ingresos, Gastos,
Aportantes y Depósitos: controles en la barra en el teléfono, glass en vez de
cápsulas dibujadas a mano, capas en vez de hermanos, sin pie de lista. Cinco
commits, verificados con la app corriendo en iPhone 17e y en inglés, y en iPad.

Lo que estaba roto y ya no:

- **Asistencia no existía en el teléfono**: el panel solo se dibujaba en la
  columna del iPad, así que la pestaña cambiaba de nombre y no de contenido.
- **Informes: el teléfono solo llegaba a uno de los cuatro.** Ahora se eligen
  los cuatro; tres dicen "Próximamente", que es la verdad.
- **Editar un miembro le borraba la familia**, y tres campos de Servicio y
  habilidades no llegaban a guardarse.
- Los dos únicos botones de la app con la acción vacía estaban aquí.
- La ficha decía "Miembro activo" y "Completo" a todo el mundo.

**Membresía sigue sirviéndose de `MockMembresiaRepository`.** El KPI del hub de
Secretaría es una constante estática. Actas, Cartas, Servicios y Agenda están
igual.

Lo que sí cambió: **la v15 ya abrió el sitio en el aparato.** Y al abrirlo
aparecieron dos cosas que ahorran mucho trabajo y que conviene no volver a
descubrir:

- **No hay tabla `miembro` ni hace falta.** `aportante` ES la fila de la
  persona: su migración v3 se declara "Espejo de `members`" y
  `Aportante.estado` es del tipo `EstadoMiembro`. Dos tablas serían dos
  verdades sobre la misma persona.
- **El servidor ya tiene TODO el dominio de Secretaría.** `public.members`
  trae las diecisiete columnas del padrón (bautismos con fecha, ministerios,
  cargos, instrumentos, habilidades, intereses, disponibilidad, iglesia
  anterior, baja con motivo, `historial_estados`, `seguimiento_notas`), y
  existen además `parentescos`, `servicios`, `servicio_asistencia`,
  `servicio_orden`, `servicio_puestos`, `actas`, `cartas`, `agenda`,
  `traslados_entrada`, `traslados_salida`, `mensajes`, `plantillas`,
  `solicitudes` y `registro`. **Nada de esto hay que diseñarlo: hay que
  reflejarlo.** Las listas viajan como arrays JSON dentro de columnas `text`,
  y los booleanos como 0/1.
- La asistencia que la pantalla finge tiene fuente real: `servicios` +
  `servicio_asistencia`, con `presente`, `razon` y `seguimiento` por persona y
  por culto. De ahí salen la racha, la última visita y el % del roster.

**Antes de escribir la sincronización, leer `docs/PADRON-WEB.md`.** Esas tablas
las creó el app web (`~/Documents/Tamio-app`) y da por sentada una semántica que
el esquema no enseña: el estado de una persona son TRES columnas y no una —dar
de baja es `activo = 0`, y `estado_membresia` ni se toca—, y las listas guardan
claves de catálogo sin acentos (`musica`, `ensenanza`, `liderJovenes`), no las
etiquetas en español que usa `MembresiaView`. Ahí está también el aviso de que
esto ya está mal HOY en Tesorería: una baja hecha desde el teléfono deja a la
persona contada como activa en el web.

**Hecho el 5 de septiembre, ya de noche:** `Miembro` tiene forma de fila
(las claves del web, las listas JSON, las fechas "YYYY-MM-DD", y lo que la
pantalla enseña se calcula), los catálogos están en `Padron` con clave y
etiqueta, `OfflineMembresiaRepository` lee y escribe por `MiembroFila` —la
otra cara de la fila de `aportante`, sin `frecuencia`— y `MotorSincronizacion`
sube `miembro` y `parentesco` y baja las columnas del padrón y los
parentescos. Verificado con pruebas unitarias contra la base local (cuatro:
listas, dos caras sin pisarse, parentesco por los dos lados, resumen contado).

**Lo que NO está verificado: la sincronización contra Supabase.** El modo
revisión no toca la red, así que la subida y la bajada del padrón están
comprobadas por compilación y por la forma de las estructuras contra el
esquema real. La primera sincronización con la cuenta de verdad es la prueba
que falta, y conviene hacerla mirando `members` en el SQL Editor.

**Las capas se eligen juntas.** `OfflineMembresiaRepository` pedía la
asistencia a la fábrica `repositorioAsistencia()`, así que con el modo
revisión encendido un repositorio de disco contaba la asistencia de la
maqueta. Un repositorio offline usa el offline; la fábrica es para las
pantallas.

**Con el modo revisión encendido, Membresía sigue enseñando la maqueta**
(`repositorioMembresia()` elige por `ModoRevision.sinLogin`, igual que los
demás). La asistencia de la ficha y el panel de Asistencia siguen siendo
inventados hasta la v16: `OfflineMembresiaRepository.asistenciaResumen()`
devuelve vacío a propósito.

**El resumen del padrón se fue de la ficha del miembro (5 de septiembre).**
`MiembroDetalle` encabezaba con los ocho indicadores —248 en el padrón, altas
del periodo, Ausencias e Incompletos—: en iPhone la tarjeta agrupada, en iPad
la rejilla de ocho. Son cifras del padrón entero, así que se repetían idénticas
en las 248 fichas y en el teléfono ocupaban media pantalla antes de decir nada
de la persona abierta. Lo dijo Iván mirando la app: *"eso aparece en cada
tarjeta con el nombre de la persona"*. Ese resumen ya vive donde toca —el hub
de Secretaría en el teléfono, Informes de membresía → General en los dos—, así
que en la ficha era un duplicado.

Lo que **no** se podía perder al quitarlo: los botones "Ausencias 9" e
"Incompletos 21" eran la ÚNICA puerta de `filtroAccion` en toda la app (la hoja
de filtros solo tenía Año, Estado y Ministerio). Bajaron a esa hoja, como
sección REQUIERE ACCIÓN **y en primer lugar**: puesta detrás de AÑO DE INGRESO
y ESTADO quedaba fuera de pantalla —ocho años y cinco estados por delante—, o
sea a tres arrastres de donde estaba a un toque. Los otros filtros recortan una
lista; este dice a quién hay que ir a buscar.

Verificado con la app corriendo, no compilando (iPhone 17e y iPad Pro 13", en
inglés): la ficha abre en el nombre y sin ninguna cifra del padrón, la hoja
trae REQUIERE ACCIÓN arriba con sus cifras, y tocar "Incomplete record · 21"
deja la lista en 6 con el chip naranja y el globito en 1. Dos detalles que
cuestan tiempo: la fila de un miembro es una `Cell` con `StaticText` dentro —no
un `Button`—, y una opción de la hoja sí es `Button`; y en iPad no vale buscar
"Transferred" para probar que los indicadores no están, porque es también el
estado de una persona de la lista.

### Cifrado local — decisión pendiente

Ver `docs/CIFRADO-LOCAL.md`. Recomendación escrita: **opción A ahora, B cuando
exista restaurar**. Faltan dos medidas antes de decidir: la clase de
protección real de `tamio.sqlite` **en el iPad** (el simulador no implementa
Data Protection) y qué protección le queda al respaldo en iCloud Drive.

---

### `safeAreaBar`, no `safeAreaInset` — 5 de septiembre

La cabecera de Informes de membresía —los chips de informe y los de periodo—
llevaba una banda de `.regularMaterial` de lado a lado. Los chips YA eran
Liquid Glass (`.glass` y `.glassProminent` en un `GlassEffectContainer`), pero
la banda los estropeaba: iba ENTRE las cápsulas y el contenido que tendrían que
refractar, así que difuminaban un gris plano, y cortaba la pantalla con una
línea dura justo por la mitad de una tarjeta.

**La lección, que sirve para las demás pantallas:** quitar el material no basta.
Sin él el contenido pasa por debajo NÍTIDO —se leía "Kitchen · 12" cruzando por
detrás de "General"— y `.scrollEdgeEffectStyle(.soft, …)` no hace nada, porque
un `safeAreaInset` cualquiera **no es una barra** y no hay borde bajo el que
desvanecer. Con `safeAreaBar` (iOS 26) sí lo es, y entonces aparece el
degradado: el contenido se difumina al pasar bajo los chips y las cápsulas
refractan lo que hay detrás de verdad.

Comprobado con la app corriendo y **el contenido desplazado**, que es la única
postura donde se nota; sin desplazar las tres versiones se ven casi iguales.
Verificado en iPhone 17e y en iPad Pro 13".

**Aplicado después a las cinco que tenían el mismo patrón**: Membresía,
Ingresos/Gastos (`MovimientosView`), Aportantes (`MiembrosView`), Depósitos y el
contador de asistencia de Servicios. En las cinco estaba escrito el MISMO
comentario equivocado —"el material vive AQUÍ… detrás de la lista se resolvía
como un gris plano porque no tenía nada que difuminar"—, así que si aparece esa
frase en otra pantalla, es este mismo caso.

**Hay dos usos distintos de `.regularMaterial` y solo uno es el error.** Actas,
Agenda, Registro, Cartas y Reportes lo llevan detrás de la COLUMNA entera de un
split view, que es legítimo y no se toca. El error es cuando está detrás de una
cabecera fijada con `safeAreaInset` sobre una lista.

**Cuidado con las cabeceras de texto pelado.** El contador de Servicios ("0 de 7
en el padrón") y la franja de cortes pendientes de Depósitos no son cápsulas de
glass: son texto sin fondo propio, y sin material se apoyan en que el
desvanecido borre lo que pasa por detrás. Comprobado que aguanta, pero con los
datos de muestra (7 personas, 3 cortes) **no hay nada que desplazar**: hubo que
girar el aparato a horizontal para quitarle altura a la lista y forzar el caso.
Es la postura a repetir si se vuelve a tocar.

**Actas era un tercer caso: hermanos, no capas.** No tenía material que
quitar; tenía la cabecera, un `Divider` y la lista apilados en un `VStack`, así
que la lista no corría por debajo de nada y al hacer scroll el contenido
**chocaba contra el divisor y se cortaba a media fila**, con la banda del
título vacía encima. Lo vio Iván: *"cuando se hace scroll se corta"*. Arreglado
igual que las demás —`safeAreaBar` + `.soft`, sin `Divider`— y de paso el
título grande ya colapsa como debe, porque ahora la lista ES el scroll de la
pantalla y no un scroll dentro de otra cosa.

**Con la misma estructura y sin arreglar: Agenda y Registro.** No es el mismo
cambio mecánico que Actas porque su contenido no es una lista: Agenda dibuja
una rejilla de calendario (y tres vistas que se alternan) y Registro un
`ScrollView` con `pinnedViews: [.sectionHeaders]`. Cartas NO tiene este
problema: su columna es la lista a secas, sin cabecera.

**Y hay que devolver el simulador a vertical.** `XCUIDevice.shared.orientation`
persiste entre pruebas: la siguiente tanda dio "no abre" en cuatro pantallas de
Secretaría —las filas del hub quedaban fuera de cuadro— y parecía una regresión
del cambio anterior. Un `simctl shutdown` + `boot` lo arregla.

---

### El botón de volver de Secretaría — 5 de septiembre

Las seis pantallas del hub de Secretaría colgaban con `sinBotonVolver()`, así
que ninguna enseñaba chevron. Lo dijo Iván: *"todas las páginas de secretaría
no tienen botón para regresar"*.

Las dos salidas que justificaban quitarlo **existen y funcionan** —comprobado
en las seis con la app corriendo: tocar la pestaña de Secretaría vuelve al hub,
y el gesto desde el borde también, gracias a `RescateGestoVolver`—. Pero
ninguna se ve, y una secretaria no tiene por qué deducirlas.

**Aviso para medir el gesto de borde:** `press(forDuration:thenDragTo:)` a secas
NO dispara el pop interactivo en el simulador y da un falso "no vuelve" en las
seis. Hay que usar `press(forDuration:thenDragTo:withVelocity:.slow,
thenHoldForDuration:)` y arrancar en `dx = 0.0`, no en 0.01.

El otro argumento —"el chevron gasta una cápsula"— solo valía para una.
Cápsulas contadas en el teléfono con la app corriendo:

| pantalla | cápsulas |
|---|---|
| Membresía | 5 — lupa, selector de vista, filtros, `+` |
| Informes, Agenda, Servicios, Actas, Cartas | 1 cada una |

Así que **las cinco de una cápsula recuperan el chevron** (verificado: aparece y
vuelve al hub en las cinco). **Membresía se queda con `sinBotonVolver()`**:
al devolverle el chevron el sistema **tiró el `+` sin avisar** —la barra pasaba
a `Secretary, Search, Members (8), More filters` y desaparecía dar de alta—,
que es exactamente el límite de la quinta cápsula que ya documenta §4. Acortar
el selector no es salida: su conteo es lo único que dice cuántas personas se
ven y que la lista está filtrada.

Queda por decidir qué sale de la barra de Membresía para que quepan las dos
cosas. Y Tesorería y el Dashboard siguen con el mismo patrón, sin revisar.

---

### Dentro de un `glassEffectUnion` no cabe un tinte por miembro — 5 de septiembre

Medido en el simulador quitando y poniendo el union sobre el mismo código: el
union funde a sus miembros en **UNA figura de cristal con UN efecto**, así que
al darle `.regular.tint(Paleta.brand)` solo al chip elegido, el verde se
derramaba por la pieza entera y los cuatro informes salían sobre una única
cápsula verde — no se sabía cuál estaba puesto. Sin el union, el tinte se queda
en su chip y vuelven a ser cuatro cápsulas sueltas.

**Son excluyentes: o una pieza continua, o un fondo teñido para el elegido.**
En Informes se eligió la pieza, y el elegido se marca con el color de marca y el
peso en la ETIQUETA. Contraste medido sobre fondo negro: 8.2:1 los no elegidos
en `.secondary` y 8.1:1 el elegido, holgado para AA, así que no hizo falta
subirle el peso. Comprobado también con Aumentar contraste y Reducir
transparencia encendidos: la pieza sigue leyéndose como grupo.

### El idioma de prueba NO se cambia con `-AppleLanguages`

La app no tiene `es.lproj`, así que `Locale.current` cae a inglés y la app sigue
en inglés aunque el argumento diga `(es)`. Quien manda es
`PreferenciasApp.idiomaGuardado`, en `UserDefaults` bajo **`prefs.idioma`**. En
una prueba de interfaz se pasa como argumento de lanzamiento:
`app.launchArguments += ["-prefs.idioma", "espanol"]`.

### La tira de informes SÍ se ve en el teléfono, y es correcto

Anotado porque el encargo daba por hecho lo contrario. `selectorInforme` estuvo
detrás de `sizeClass == .regular`, pero el commit `f62b932` ("En el teléfono no
había forma de llegar a tres de los cuatro informes") quitó ese gate. Lo que
queda hoy con ese texto es el COMENTARIO que cuenta cómo estaba, no código. En
HEAD la tira se dibuja en las dos plataformas, que es lo que se ve en el
aparato.

---

## 6. Pendientes concretos

1. **El mes es invisible en Ingresos.** Al quitar el pie, el mes solo se lee
   abriendo la hoja de filtros: en agosto las cabeceras dicen "VIERNES 29" y el
   mes no aparece en ninguna parte. Y `filtrosActivos` **no cuenta el periodo**,
   así que el botón no se tiñe al mirar un mes que no es el actual — una lista
   corta no se explica sola. Se arregla sumando el mes al contador.
2. **El total de Movimientos en iPad** ya solo vive en la hoja de filtros. Allí
   el pie no causaba ninguno de los tres problemas del teléfono.
3. **Verificar los recurrentes en aparato** (§5). Es el riesgo real que queda.
4. **Las dos medidas del cifrado** (§5).
5. **Membresía: probar la sincronización con la cuenta real** (§5). El
   repositorio y el motor están escritos —padrón, parentescos, cultos y
   asistencia—; la red no se ha ejercitado nunca.
6. **Los servicios ya tienen forma de fila** (v17: `servicioPuesto` y
   `servicioOrden`), con su repositorio y su sincronización. Lo que falta de
   esa pantalla es el resto de la ficha del culto —cantos, escuela dominical,
   conteos— que sigue guardándose pero sin verse.
7. **"Familia Ruvalcaba" es una familia registrada como UNA persona**, con la
   nota "cuatro miembros · diezman juntos". Para Tesorería funciona —una
   constancia— pero en la lista de asistencia cuenta uno donde hay cuatro y no
   se puede seguir a ninguno. Hay que partirla en cuatro fichas unidas por
   parentescos, o aceptar que esa familia no tiene asistencia real.
8. **Aplicar `frenar_baja_tesorero`.** Está escrito en
   `supabase/sync-p2-padron.sql` del repo del web (rama
   `claude/padron-secretaria`) y sin aplicar. Las dos apps ya esconden los
   botones, así que ya no rompe a nadie; es la base de producción y la aplica
   Iván. Ver `docs/PADRON-WEB.md` §4.
9. **Reflejar `traslados_salida`.** Hasta entonces la pastilla "traslado en
   curso" no se ve: dejó de ser un estado de la persona y el expediente vive
   en esa tabla.
10. Observación sin acción: el hub dice "Transacciones · 29 registros" y la
   lista dice "16 movimientos". No es un error —una suma ingresos y gastos, la
   otra solo el tipo activo— pero se leen como el mismo número.

---

## 7. Cómo se escribe aquí

Los mensajes de commit son **frases que cuentan el problema**, no resúmenes del
cambio: *"El interruptor decía que se repetía y el mes siguiente no aparecía
nada"*. El cuerpo explica el porqué, lo que se descartó y con qué medida se
decidió. Los comentarios del código siguen el mismo criterio: dicen por qué
está así, no qué hace.

Los números se miden, no se estiman. Cuando un comentario dice "medido en
pantalla", es que se midió de verdad.
