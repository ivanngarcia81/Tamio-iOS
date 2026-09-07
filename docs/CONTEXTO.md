# Contexto de trabajo · Tamio-iOS

Este archivo existe para que una sesión nueva —o una persona que vuelve dentro
de un mes— no empiece de cero. **No es documentación del código**: eso ya está
en los comentarios y en los mensajes de commit, que en este proyecto explican
el porqué y no el qué. Aquí va lo que NO se deduce leyendo el repo.

Última actualización: **7 de septiembre de 2026**, con los sucesos de Tesorería.

---

## 0. Los cinco sucesos de Tesorería · 7 de septiembre

Lo que el §6 llevaba marcado como "lo de más valor que queda en toda la app":
**el registro ya anota los cinco sucesos de Tesorería.** Con esto quedan los
diez del web, no cuatro.

| Suceso | Dónde se anota | Cuándo, exactamente |
|---|---|---|
| `movEliminado` | `OfflineMovimientosRepository.eliminar` | al pasar a borrado; nunca dos veces |
| `corteEntregado` | `OfflineDepositosRepository.agregarAlCorte` | la PRIMERA vez que el corte deja de estar vacío |
| `corteDepositado` | `registrarDeposito` | al pasar a depositado |
| `segundaFirma` | `firmar` | cuando la firma CAMBIA |
| `descuadre` | `firmar` | sin nombre y con un conteo distinto al anterior |

**`corteEntregado` no va donde va en el web, y es a propósito.** Allí el corte
nace ya con sus movimientos dentro (`crearCorte` recibe los `txIds`), así que el
apunte cabe en la creación. Aquí un corte nace VACÍO y el tesorero le va echando
sobres: anotarlo al crearlo daría "con 0 movimiento(s)", que no dice nada. El
momento en que el dinero sale de la caja es la primera vez que el corte deja de
estar vacío, y ahí va.

### Y algo que no se buscaba: las claves de `datos` no eran las del web

La tabla `registro` guarda las PIEZAS y compone la frase al leer — esa es su
razón de ser—, así que **las claves de `datos` son un contrato entre las dos
apps**. Tres no coincidían, y el apunte escrito por una salía con guiones en la
otra:

- `cartaEmitida` escribía `nombre`; el web lee `destinatario`.
- `segundaFirma` leía `quien`; el web escribe `firmante` (y un `modo` que iOS
  ni miraba).
- `movEliminado` no tenía `concepto`, y `actaCerrada` no tenía `titulo`.

Ahora se escribe con las claves del web y **se leen las dos**: los apuntes que
iOS ya dejó en la base de la iglesia siguen legibles. Un `d("firmante", "quien")`
en `Apunte.texto` es exactamente eso.

**Y `datos` no siempre son cadenas.** El web guarda `movimientos` como número
—`txIds.length`—, y `JSONDecoder().decode([String: String])` no falla en esa
clave: falla en el objeto entero y devuelve vacío. Un `corteEntregado` hecho
desde el web se leía en el teléfono como "Salió de la caja el corte «—», con —
movimiento(s)". Se lee suelto con `JSONSerialization` y cada valor se pasa a
texto.

### Lo que se probó, y con qué

**Dieciocho pruebas unitarias, todas en verde**, contra la base de verdad del
contenedor (`SucesosTesoreriaTests`, en la copia del §3 — no en el repo, §5).
Por cada suceso: que anota al hacer la cosa, con sus piezas, y que **no vuelve a
anotar si la cosa se repite**. Ese segundo caso es el que importa: un registro
que anota de más deja de servir igual que uno que no anota.

Dos cosas que solo salieron por correrlas:

- **El folio de un movimiento del teléfono es provisional.** `crear` le pone el
  suyo local ("P-3") y el definitivo lo da el contador del servidor. El apunte
  guarda el que la persona tiene delante, no el del objeto.
- **`esAlerta` es verdadero para DOS sucesos**, y la pastilla roja del detalle
  decía "No cuadró" para los dos. Un movimiento dado de baja no es un conteo que
  no cuadró: ahora la etiqueta la da `TipoSuceso.etiquetaAlerta`.

**Lo que NO se verificó:** verlos aparecer en la pantalla de Registro con la
cuenta real. El código de pantalla no se tocó salvo esa pastilla, y las frases
sí están probadas, pero mirarlo un domingo es lo que lo cierra.

### Y después, lo que quedaba de Tesorería

El §6 lo llamaba "enchufar lo que quede", y **no era eso**: las seis pantallas
ya tenían repositorio y sincronización. Lo que quedaba era **Inicio**, que era
la maqueta entera —la primera pantalla de la app enseñaba la iglesia Getsemaní
con la cuenta de la iglesia de verdad—, el **selector de aportante**, que iba a
la red y sin señal salía vacío, y **dos badges de la sidebar del iPad**.

El detalle está en §5, "Lo que quedaba de Tesorería, enchufado". La lección, en
una línea: **una maqueta leída directamente no es el modo revisión, está clavada
en el código** — y se encuentra con `grep -rn "Mock" Tamio/Views Tamio/ViewModels`.

---

## 0.1 Secretaría, cerrada · 6 y 7 de septiembre

Una sesión larga que cruzó la medianoche. Empezó con una pregunta de Iván
—"¿cuáles son las páginas que faltan por arreglar?"— y la respuesta correcta no
era la que parecía: **las seis pantallas de Secretaría abrían, cargaban y
dejaban volver, y cinco de las seis eran maqueta.**

Trece commits, de `d2e999c` a `5d0d91b`, todos en `liquid-glass`. **`main` sigue
en `4a571ff` a propósito** (§1).

### Dónde quedó Secretaría

Las seis pantallas leen y escriben en la base local y suben y bajan de
Supabase. **La sincronización está probada con la cuenta real en las DOS
direcciones** (§5). Y ninguna pantalla enseña ya un número inventado.

| | Repositorio | Tabla | Sincronización |
|---|---|---|---|
| Membresía | ✅ | v15 | ✅ |
| Servicios | ✅ | v16–v17 | ✅ |
| Agenda | ✅ | v18 | ✅ |
| Actas | ✅ | v19 | ✅ |
| Cartas | ✅ | v20 | ✅ |
| Registro | ✅ | v21 | ✅ |
| Plantillas | ✅ | v22 | solo baja, a propósito |

Lo demás que cayó: el hub dejó de anunciar compromisos de agosto; los tres
selectores de personas leen el padrón; las firmas de un acta constan; el
registro anota los cuatro sucesos de Secretaría; los informes General y
Seguimiento salen del padrón. Y dos cosas que pidió Iván: **tirar hacia abajo
para sincronizar** en catorce pantallas, y los próximos compromisos arriba del
hub.

**Mensajes se quitó, no se hizo.** Ver §5, "Mensajes no existe".

### Lo siguiente

Está en el §6, y lo de más valor es el primero.

### La primera mitad: enchufarlas

**Las cinco pantallas de Secretaría que no estaban enchufadas, lo están.**
Agenda (v18), Actas (v19), Cartas (v20) y Registro (v21): tabla local espejo de
la del web, repositorio `Offline*`, cola de salida, `subirX` y `bajarX` en el
motor, y la fábrica decidiendo maqueta sin sesión / base con ella. Membresía y
Servicios ya lo estaban. **El backend no hizo falta tocarlo**: las tablas del
web ya existían con datos puestos.

**El hub dejó de mentir.** Leía `MockMembresiaRepository.resumenPadron` y
`MockAgendaRepository.pendientesCount` DIRECTAMENTE, saltándose las fábricas:
con la cuenta real habría seguido diciendo 236 de alta de 248. Y sus "próximos
compromisos" estaban escritos a mano en agosto —"MAÑANA · 19:00", "VIE 21",
"En agosto"— estando a 6 de septiembre.

**Mensajes se quitó.** No estaba pendiente de construir: estaba retirada. Ver
§5, "Mensajes no existe".

### El patrón que se repitió cinco veces

No es casualidad, y quien siga por Tesorería se lo va a encontrar igual: **la
pantalla guardaba lo que se VE, no lo que ES.**

- La agenda guardaba el día del mes, sin año: un evento del 21 valía para el 21
  de cualquier mes de cualquier año.
- El acta fundía quince campos del formulario en un `cuerpo` de prosa y
  devolvía eso: existían en pantalla y en ninguna parte más.
- La carta guardaba cuatro campos —"Javier Medina · traslado" entre ellos, ya
  escrito y por tanto congelado en español—; el cuerpo, el destinatario y la
  fecha se tiraban al emitir.
- El registro guardaba la frase redactada, más `hora`, `grupo` y `fecha` como
  texto: un apunte de ayer decía HOY para siempre.
- Las actas guardaban el tipo TRADUCIDO: la misma acta cambiaba de tipo al
  cambiar de idioma.

**El web ya había aprendido esto y está escrito en su código.** Retiró
`mensajes` precisamente porque "guardaba la frase ya armada y por eso se quedaba
congelada en un idioma", y `registro` nació guardando `tipo` + `datos` para
componer al leer. Antes de escribir un repositorio nuevo, mirar cómo guarda el
web esa misma cosa.

### La segunda mitad: que sirvan

Enchufadas no es lo mismo que terminadas. Con la cuenta real puesta salió lo
que la maqueta tapaba: **pasar lista corría sobre doce personas inventadas**,
firmar un acta no dejaba constancia de quién, el registro no registraba nada
automático, las plantillas de carta se leían de un `enum` mientras la iglesia
tenía las suyas en la base, y dos informes seguían con cifras escritas a mano.

Los cinco se cerraron, cada uno verificado en la app corriendo contra la
cuenta. El detalle está en los mensajes de commit y en el §6.

### Las lecciones de esta vuelta

**Comprobar la premisa antes de construir, otra vez.** El encargo era "haz
Mensajes". Diez minutos de leer el web y un `select` contra la base evitaron
construir una pantalla sobre una tabla muerta. Es la misma lección de la familia
Ruvalcaba, con otro disfraz.

**Las tres cosas que rompí las cazó una prueba, ninguna la pantalla.** El mes de
la agenda salía vacío en octubre porque mezclaba una fecha parseada en UTC con
un formateador local; firmar un acta y recargar la enseñaba como "Aprobada"
porque guardaba en local la clave empobrecida del web; el texto del registro se
componía en el idioma correcto solo porque la prueba corría en inglés y lo
enseñó. Ninguna se habría visto mirando la app en modo revisión.

**Una migración se prueba con una prueba unitaria, no arrancando la app.** Si
`migrate` lanza, `BaseLocal` se cae a memoria sin avisar, y en modo revisión la
base ni se abre. Se montó por fin el target `bundle.unit-test` de la receta del
§3; está en el scratchpad, no en el repo (ver §5, "El target de pruebas").

**Leer el §5 ENTERO antes de pelearse con algo.** Se perdió media hora
peleando con `-AppleLanguages` para probar en español, y la respuesta llevaba
ahí escrita desde el 5 de septiembre: se pasa `-prefs.idioma espanol`.

---

## 0.2 Antes, ese mismo día: las salidas y los informes

**Esto es la sesión ANTERIOR, se conserva por el detalle de sus decisiones.**
Su lista de "lo que queda" está desfasada: la de verdad es el §6, y varias de
las de aquí se cerraron en la segunda vuelta.

Doce commits, de `1520d98` a `98ef902`, todos subidos y con `main` adelantada a
la par en aquel momento. Lo que sigue es el resumen; el detalle de cada
decisión está más abajo en su sección y en los mensajes de commit.

### Lo que se cerró

**Todas las pantallas tienen botón de volver.** Eran once colgando de un hub sin
salida visible. Las cinco de Secretaría cayeron el 5-sep; el 6 cayeron
Membresía (el `+` bajó a la lista), cinco de Tesorería y el Dashboard, y por
último Movimientos. `sinBotonVolver()` ya no lo llama nadie.

**El corte al hacer scroll, en Agenda y Registro.** Capas y no hermanos, como
Actas. En Agenda además la fila de nombres de día subió a la barra, y solo en
Mes.

**El disparador `frenar_baja_tesorero` está aplicado** en Supabase
(`hkpbkpojeierxqtbmagh`) y verificado sobre datos reales. Era una de las tres
cosas que esperaban a Iván.

**Tres de los cuatro informes de membresía.** General ya estaba; se añadieron
Miembros (ocho tarjetas que filtran + los cuatro filtros combinables) y
Asistencia (cuatro cifras + los que más vinieron). Reflejados del web.

**Arreglos que salieron de mirar la app, no el código:** el título grande
escondido detrás del cristal (cuatro pantallas), el segmentado de Agenda que era
un parche gris, y la fecha de Servicios que decía "SAT 5" junto a "Sep 6".

### Lo que queda

1. **Probar la sincronización con la cuenta real.** La grande. Padrón,
   parentescos, cultos, asistencia, puestos y orden suben y bajan por código que
   NUNCA ha tocado la red: el modo revisión no la ejercita. Ver §5 y §6.
2. **El informe de Seguimiento**, el cuarto. El web lo tiene resuelto en
   `services/informes/membresia.ts`: `alertasSeguimiento` y sus `TipoAlerta`.
3. **El `+` de Membresía podría volver a la barra.** Bajó a la lista cuando las
   únicas salidas eran esa o quedarse sin chevron; el cajón de la lupa abre una
   tercera. Sin tocar, porque la fila funciona y la decisión fue de Iván.
4. **El resumen de la maqueta miente.** `MockMembresiaRepository.resumen()`
   devuelve 248/236/21 escritos a mano sobre una `lista()` de siete. El hub y la
   cabecera de Membresía lo leen. Arreglarlo cambia lo que enseñan las capturas.
5. **La tira de días de la vista Semana** va dentro del scroll (§ Agenda).
6. **`Aportante.aportes(anio:)` filtra el año en local** sobre fechas que se
   parsean en UTC: un aporte del 1 de enero importado de CSV cae en el año
   anterior. No se tocó porque mueve los importes de una constancia anual.
7. Los recurrentes sin verificar en aparato y las dos medidas del cifrado, de
   antes (§5, §6).

### Las tres lecciones que costaron una vuelta cada una

**Si dos números de una pantalla tienen que cuadrar, se calculan del MISMO
array.** Salió tres veces seguidas haciendo los informes: tarjetas que decían
248 sobre una lista de siete, y "110 de asistencia total" junto a "186 de
promedio por servicio" con 27 servicios. Siempre era mezclar el resumen escrito
a mano de la maqueta con las fichas de verdad. **Las tres las cazó una prueba,
ninguna se vio mirando la pantalla.**

**Un comentario que descarta una familia de soluciones no descarta la que no se
probó.** `MovimientosView` tenía escrito, con cuatro experimentos medidos, que
la lupa no se podía mover. Lo que decía en realidad es que no se podía bajar a
la barra INFERIOR. El cajón va hacia arriba, y resolvió el problema a la
primera.

**Comprobar contra la base antes de anotar un problema de producción.**
"Familia Ruvalcaba" llevaba un día apuntada como una decisión pendiente sobre
datos reales. No existía en `members`: era maqueta, y se había anotado mirando
la app en modo revisión, que es justo donde los datos son inventados. Un
`select` de un minuto lo habría evitado.

---

## 1. Dónde está el trabajo

Rama viva: **`liquid-glass`**, sincronizada con `origin/liquid-glass`.

**`main` está al día en `3ffc483`**, adelantada por avance rápido el 7 de
septiembre (`git push origin liquid-glass:main`). Se había quedado atrás en
`4a571ff` a propósito mientras las cuatro migraciones nuevas (v18–v21) y las
cuatro entidades de sincronización estaban sin probar contra la red; se probaron
con la cuenta real, así que el motivo se acabó. **Repetirlo cuando lo de
`liquid-glass` esté probado**, no antes: es lo que evita que combinarlas se
convierta en un problema.

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

### 2.2 El modo revisión, y qué cambia con él apagado

**APAGADO desde el 7 de septiembre**, que es lo que este aviso llevaba
pidiendo. `Support/ModoRevision.swift` tiene ahora `activada = false`: la app
pide sesión y sirve los datos de la iglesia.

Con él ENCENDIDO no se ejercita nada de Supabase —ni folios, ni sincronización,
ni subida de comprobantes— y los repositorios que se inyectan son los `Mock*`,
no los `Offline*`. Se vuelve a poner en `true` para recorrer pantallas sin
credenciales, y el aviso naranja lo hace visible. Está dentro de `#if DEBUG`,
así que un olvido no llega a la App Store.

**Lo que cambia ahora que está apagado**, y hay que tenerlo presente:

- **Las pruebas corren contra la base de la iglesia.** Ni unitarias ni de
  interfaz deben correr contra un contenedor con sesión: ya subieron una nota y
  dos actividades sin que nadie lo pidiera. Ver §5, "Las pruebas unitarias
  corren DENTRO del contenedor".
- **La suite de interfaz se escribió contra la maqueta.** Lo que mire un dato
  concreto —un nombre, un conteo— va a fallar con datos reales, y eso no es una
  regresión.

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

### Las cinco pantallas de Secretaría, enchufadas — 6 de septiembre, 2ª vuelta

**La receta, que es la misma cuatro veces** y sirve para las que falten en
Tesorería:

1. Migración en `BaseLocal.swift` con una tabla espejo de la del web, columnas
   incluidas. Los nombres en camelCase como el resto de filas de aquí; la
   traducción a los del web se hace en el motor.
2. La `Fila` en `Local/AportanteFila.swift` (ahí viven todas; **no crear
   archivo nuevo**, ver §2.1).
3. `OfflineXRepository` con `lista/guardar/eliminar`, encolando en el outbox.
   Borrar deja **lápida**, no borra la fila: si desapareciera, el otro aparato
   no se enteraría nunca.
4. `subirX` + `bajarX` en `MotorSincronizacion.swift`, su rama en `subir(_:)`
   y su llamada en la tanda de bajadas. El cursor va en `syncEstado` con la
   misma clave que la entidad del outbox.
5. `func repositorioX()` con `ModoRevision.sinLogin ? Mock : Offline`, y el
   view model usándola por omisión.

Entidades del outbox que existen ahora: `evento`, `acta`, `carta`, `apunte`,
además de las de antes.

**Tres cosas que se aprendieron haciéndolo, y que se van a repetir:**

- **La base local NO tiene que empobrecerse para parecerse al web.** Las actas
  tienen siete estados aquí y cinco allá; guardar la clave del web en local
  hacía que firmar un acta la enseñara como "Aprobada" al recargar. Lo local
  guarda los siete y la traducción va en el motor, que es donde va toda.
- **Las listas del web suelen ser objetos, no cadenas.** Los acuerdos de un
  acta llevan `texto`/`responsable`/`fecha_limite`, las mociones cuatro campos
  y las firmas de una carta `nombre`/`cargo`. Escribir una lista de cadenas
  produce JSON que el web no sabe abrir.
- **Lo que el formulario no pisa, no se pisa.** `guardar` de un acta no toca
  `firmas` ni `testigo`, y el de una carta no toca `historial_estados`:
  corregir una coma habría borrado las firmas.

**Lo que NO trae:** la recurrencia de la agenda viaja como el JSON que es, sin
interpretarla; el responsable de una actividad se guarda como texto y no como
`member_uid`; y las cartas se folian contando el máximo del año, que se queda
corto si dos aparatos emiten a la vez sin sincronizar —lo que lo resuelve de
verdad es el contador de Postgres que ya usan los movimientos, y todavía no
cubre cartas—.

### Mensajes no existe: está retirada, no pendiente

`supabase/retiro-msg1-mensajes.sql` en el repo del web, del **26 de agosto de
2026**, abre citando a Iván: "cerrar el reemplazo de Mensajes y borrar". La
tabla la sustituyó `registro` en su migración 50.

Comprobado contra la base y no contra el archivo: `public.mensajes` tiene siete
filas y **las siete están marcadas como borradas**. La tabla remota sigue
existiendo vacía a propósito —el paso 2 del retiro no la suelta hasta que todos
los aparatos lleven la 1.2.12, para que un iPad viejo no rompa su
sincronización—, así que **verla en `list_tables` no significa que esté viva**.

La fila del hub se quitó el 6 de septiembre y en su sitio va el Registro. Iván:
"Mensaje no es necesario lo puedes eliminar".

### El target de pruebas unitarias vive en la COPIA, no en el repo

Se montó por fin el `bundle.unit-test` de la receta del §3 y con él se probaron
las cuatro migraciones nuevas, que es lo único que no puede fallar en silencio.
**No está en el repo**: vive en el directorio temporal, junto al `project.yml`
parcheado, porque meterlo aquí obliga a tocar el `.pbxproj` a mano (§2.1).

Quien vuelva: `TEST_HOST` y `BUNDLE_LOADER` apuntando a `Tamio.app/Tamio` para
poder `@testable import Tamio`, y el tipo es `bundle.unit-test`, **no**
`bundle.unit-testing`. Las pruebas escritas cubren, por cada entidad: que la
base abre EN DISCO con la migración aplicada, la ida y vuelta por la tabla, que
un alta editada antes de subir sigue siendo alta, y que el borrado deja lápida.

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

**Agenda y Registro, arreglados el 6 de septiembre.** Cartas NO tiene este
problema: su columna es la lista a secas, sin cabecera.

Registro resultó ser el caso de Actas exacto —pastillas, `Divider` y scroll
apilados—, así que fue el mismo cambio. El riesgo que había que comprobar era
si las cabeceras de día se seguían fijando: sí, porque `pinnedViews` es del
`LazyVStack` y no del contenedor de fuera, así que se pegan bajo la barra en
vez de bajo el `Divider` que ya no está.

Agenda sí pidió una decisión. Su barra pasa a ser el selector de vista + la
navegación de mes, y las tres vistas corren por debajo. **La fila de nombres de
día (`SUN MON TUE…`) sube a la barra, y solo en Mes**: es cabecera de la
rejilla, no contenido suyo, y si viaja con el scroll un mes desplazado deja de
decir qué columna es cuál. Semana no la necesita —cada celda lleva el suyo, ver
`celdaSemana`— y Lista no tiene columnas.

**Observado y NO cambiado en Agenda:** en Semana, la tira de los siete días va
DENTRO del scroll, así que con un día muy cargado se iría hacia arriba y el
selector de día desaparecería. Hoy no pasa —ningún día del mes de prueba tiene
eventos suficientes para desplazar esa tira— y subirla a la barra es otra
decisión, no la de este arreglo. Queda escrito para que se note antes de que lo
note un usuario.

**De paso, un array de días escrito a mano por segunda vez.** `diasSemana`
existía justo para que el calendario no dijera "DOM LUN MAR" con la app en
inglés, y `etiquetaDiaLista` tenía su propia copia que no pasaba por
`L.diaSemana`: la vista Lista seguía en español. Salió en la captura de
verificación, no leyendo el código.

Verificado corriendo, con el contenido desplazado, que es la única postura
donde se nota: Agenda en iPhone 17e en sus tres vistas y Registro en iPad Pro
13" —que es donde de verdad se usa: **Registro no está en el hub del teléfono**,
solo en la barra lateral—. En las cuatro el contenido se difumina por debajo de
la barra en vez de chocar.

**Aviso para medir un scroll de columna en iPad:** un `swipeUp` en el centro de
la pantalla cae en el PANEL DE DETALLE y la lista no se mueve, así que la
prueba pasa sin haber ejercitado nada. Hay que coger el `ScrollView` de la
mitad izquierda y afirmar que algo se movió de verdad.

**Y hay que devolver el simulador a vertical.** `XCUIDevice.shared.orientation`
persiste entre pruebas: la siguiente tanda dio "no abre" en cuatro pantallas de
Secretaría —las filas del hub quedaban fuera de cuadro— y parecía una regresión
del cambio anterior. Un `simctl shutdown` + `boot` lo arregla.

---

### Informe de Asistencia — 6 de septiembre

Reflejado del web (`resumenAsistencia` + `topAsistencia`): cuatro cifras del
periodo y quiénes vinieron más, con su mismo criterio de desempate —a igual
porcentaje, primero el que vino a más cultos, o el que vino a UNO solo
encabezaría la lista de los más constantes—.

**Dos cosas las encontró la prueba, no la vista.**

1. **Una persona de baja salía en "los que más vinieron", con 0%.** Rosa Elena
   Vega se trasladó en marzo. No es un dato malo, es una pregunta mal hecha:
   dejó la iglesia, no faltó a los cultos. Las bajas quedan fuera del top.
2. **Las cuatro cifras salían de dos sitios y se contradecían en pantalla**:
   "110 de asistencia total" al lado de "186 de promedio por servicio", con 27
   servicios. El 186 venía del resumen congregacional —un número de una iglesia
   de 248— y el 110 de sumar las siete fichas. Ahora las cuatro se derivan de
   las fichas y del número de servicios, con la fórmula del web. Del resumen
   congregacional ya no se lee nada más.

   Por lo mismo se quitó "mejor servicio": venía de esa otra fuente y decía
   "214 · 23 ago" bajo una asistencia total de 110. El web tampoco lo pone aquí.

**Es la tercera vez en dos informes** que dos cifras de la misma pantalla salen
de dos sitios y acaban discrepando. La regla, ya sin excusa: **si dos números de
una pantalla tienen que cuadrar, se calculan del mismo array.**

`Paleta.porcentajeAsistencia` recoge los dos umbrales del color del porcentaje
(85 y 65), que vivían privados en `MembresiaView`: duplicarlos era garantizar
que un día el mismo miembro saliera verde en una pantalla y ámbar en otra.

Verificado corriendo en iPhone 17e, con una prueba que además comprueba que el
promedio ES el total entre los servicios y que el top va de mayor a menor.

Falta **Seguimiento**: `alertasSeguimiento` y sus `TipoAlerta` en el web.

---

### Informe de Miembros — 6 de septiembre

De los cuatro informes de membresía, tres decían "Próximamente". **Miembros ya
no.** No estaba a medias: no existía nada, ni datos ni modelo.

**Reflejado del web, no diseñado.** `InformesMembresia.tsx` lo tiene entero, con
sus ocho tarjetas que filtran (`TarjetaFiltro`), en el mismo orden y con las
mismas identidades. Se copió también su decisión para el teléfono: allí las ocho
pasaron de rejilla a **lista agrupada** porque *"ocho tarjetas de media pantalla
eran ~900px de resumen antes de la primera fila del registro"* — la misma razón
por la que estos ocho indicadores se fueron de `MiembroDetalle`. En iPad sí van
en rejilla de cuatro.

**El descuadre que encontró la prueba, y que es la razón de que el informe esté
hecho así.** La primera versión leía las cifras de `repo.resumen()` y filtraba
la lista aparte. Resultado medido: las tarjetas decían **248 total, 236 activos,
21 incompletos** encima de una lista de **siete personas**, porque
`MockMembresiaRepository.resumen()` devuelve un resumen escrito a mano que su
propia `lista()` desmiente.

Así que la cifra de la tarjeta **se cuenta con el mismo predicado que filtra la
lista** (`TarjetaPadron.incluye`), no se pide al repositorio: las dos son la
misma expresión sobre el mismo array y no pueden divergir. Es la lección que ya
tenía escrita `MembresiaResumen.total` —*"no se escribe, se suma"*— aplicada a
las ocho.

**Y queda un descuadre de antes, sin tocar:** con el modo revisión encendido, el
hub de Secretaría y la cabecera de Membresía siguen leyendo ese resumen escrito
a mano, así que dicen 248 sobre un padrón de siete. No es de este informe y
arreglarlo cambia lo que enseña la maqueta en las capturas.

Verificado corriendo en iPhone 17e, con una prueba que compara cada tarjeta con
el largo de su lista: 7 de 7 sin filtrar, Active 6=6, Inactive 0=0, New 1=1,
Incomplete 4=4, y el segundo toque quita el filtro.

**Los cuatro filtros combinables, después.** Al informe de Miembros le faltaba
lo otro que el web tiene: estado, ministerio, cargo e instrumento. **Combinan
con la tarjeta, no la sustituyen** —"Incompletos" y luego "música" es la
pregunta real: a quién de la alabanza le falta expediente—, y van en la hoja de
filtros que ya existía, así que no gastan una sexta cápsula.

Dos medidas que se repiten de Membresía y de Ingresos: **la sección del padrón
va PRIMERA en la hoja**, porque detrás de PERIODO y AÑO quedaba a tres arrastres
—cinco periodos y ocho años por delante— de donde tiene que estar a un toque; y
**el globito del botón los cuenta**, porque una lista recortada a "los de
música" no se explica sola. La tarjeta no entra en ese conteo: ya se ve
encendida en su propia fila, y contarla dos veces es el error que Membresía
cometió con el año.

Son `Menu` y no `Picker` para que "Todos" pueda ser `nil` de verdad: "sin
filtrar" no es una opción más del catálogo.

Verificado corriendo: 7 sin filtrar, 6 con la tarjeta Active, y 1 al añadir
Ministerio = música encima. La prueba afirma que añadir un filtro nunca AMPLÍA
la lista —que es como se notaría que la tarjeta se perdió— y que el conteo
cuadra con las filas.

Falta **Seguimiento**. El web lo tiene resuelto en
`services/informes/membresia.ts`: `alertasSeguimiento` con sus `TipoAlerta`.

---

### La fecha se PARSEA en UTC, así que también hay que LEERLA en UTC — 6 de septiembre

En Servicios la pastilla decía "SAT 5" al lado de un subtítulo que decía
"Sep 6, 2026", que es domingo. **Un día entero de diferencia dentro de la misma
fila**, y justo en la pantalla que sirve para saber qué culto es cuál.

`Fechas.desdeTexto` fija `timeZone = UTC` al parsear, y `diaLegible` lo fija
también al formatear —su comentario ya avisaba: *"un depósito del 17 salía
impreso como 16"*—. Pero `Servicio.diaSemana` usaba `L.formateador("EEE")` sin
zona y `numDia` usaba `Calendar.current`: los dos leían con el calendario del
aparato, que en cualquier zona al oeste de Greenwich corre la medianoche UTC al
día anterior.

El aviso estaba escrito y aun así volvió a pasar, porque era un comentario y no
una herramienta. Ahora `Fechas` tiene `diaSemanaCorto(_:)`, `numeroDeDia(_:)` y
`calendarioUTC`, y `Servicio` los usa.

**La regla:** `Calendar.current` es correcto para HOY —la secretaria vive en su
zona— y equivocado para una fecha que se guardó como texto. Si el dato salió de
`desdeTexto`/`desdeTextoFlexible`, se lee con `calendarioUTC`.

**Revisado el resto y NO es un problema general.** `periodoLegible` y
`Reporte.composicionMesCorto` parsean y formatean los dos en local, así que son
coherentes; el resto de `Calendar.current` de la app son sobre `Date()`.

**Queda uno observado y sin tocar, a propósito:** `Aportante.aportes(anio:)`
filtra con `Calendar.current.component(.year, from: $0.fecha)`, y en la
importación de CSV esa fecha viene de `desdeTextoFlexible`, o sea UTC. Un aporte
del 1 de enero importado desde un archivo caería en el año anterior. **No lo
cambio porque eso mueve los importes de una constancia anual**, que es un
documento que se firma: es una decisión de Iván, no un arreglo de paso.

Verificado corriendo en iPhone 17e: "SUN 6 · Sep 6, 2026" y "THU 3 · Sep 3,
2026", pastilla y subtítulo de acuerdo.

---

### Un segmentado NO es de cristal, aunque esté dentro de una barra que sí — 6 de septiembre

`Picker(.segmented)` dibuja el fondo opaco de UIKit. Dentro de la barra de
cristal de Agenda se leía como un parche gris pegado encima en vez de como parte
de la barra. Lo señaló Iván rodeándolo en una captura.

**No se envuelve el `Picker` en `.glassEffect`**: su fondo es opaco y taparía el
cristal, que es la misma razón por la que las bandas de `.regularMaterial` había
que QUITARLAS y no esconderlas. Van tres cápsulas en un `GlassEffectContainer`,
como los demás controles de cristal de la app.

**Y no contradice la nota de Ingresos**, donde el segmentado se queda `Picker` a
propósito: allí vive en el `toolbar` y el sistema ya le pone su cápsula —glass
dentro de glass, que es lo que Apple desaconseja—. En una `safeAreaBar` no hay
cápsula del sistema, así que hay que ponerla.

Dos cosas que costaron una vuelta cada una:

- **La elegida tiene que ir `.glassProminent` y teñida.** Tres cápsulas iguales
  se leen como tres acciones, no como "elige una".
- **Y las NO elegidas hay que destintarlas con `.tint(Color.primary)`.**
  `.glass` hereda el tinte del TabView: las tres salían en verde y las tres
  parecían activas. Es la misma lección que ya tenía escrita `filaFiltro` de
  Informes, en otra forma. **`.foregroundStyle` en la etiqueta NO sirve** —
  probado—: el estilo de botón pinta por encima. La palanca es `.tint`, como en
  Servicios.

Verificado corriendo con una prueba que lee `isSelected`, no solo con la vista:
al abrir marca Mes, y tocar Semana marca Semana y solo Semana.

---

### El título grande no cabe con una barra de cristal — 6 de septiembre

Lo vio Iván en dos capturas del teléfono, rodeando el hueco con el dedo: *"el
título se esconde detrás del frosted glass"*. En Agenda y en Actas el título
—"Calendar", "Minutes"— salía gris sobre negro y borroso, ilegible, **sin hacer
scroll siquiera**.

Con `safeAreaBar` el contenido corre por debajo de la barra: eso es lo que le da
al glass algo que refractar, y es justo lo que se buscaba. Pero el **título
grande** vive en esa misma franja, así que queda debajo del desvanecido.

**Su hipótesis era acortar el cristal, y no es eso**: la barra mide lo que mide
su contenido, y encogerla apretaría los controles sin devolver el título. El
arreglo es subir el título a la barra de navegación (`.inline`), donde siempre se
lee. `navigationSubtitle` se conserva: sale bajo el título, más pequeño.

**Y ya estaba resuelto en la mitad de la app sin que nadie lo hubiera escrito.**
De las nueve pantallas con `safeAreaBar`, cinco ya ramificaban —`.inline` en el
teléfono, `.large` en iPad— y por eso a Membresía, Ingresos, Aportantes y
Depósitos no les pasaba. Las cuatro que pedían `.large` en las dos son
exactamente las cuatro que fallaban: **Actas, Agenda, Servicios y Registro**.

Regla, entonces: **`safeAreaBar` y `.large` no conviven en compacto.** Si una
pantalla lleva barra de cristal, su título va `.inline` en el teléfono.

Verificado corriendo en iPhone 17e: "Calendar · September 2026 · 7 pending",
"Minutes · Minutes 2026-08 in draft" y "Service log · Roster & attendance by
service" se leen enteros, con el chevron y el `+` a los lados.

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
vuelve al hub en las cinco). Membresía se quedó con `sinBotonVolver()` esa
tarde: al devolverle el chevron el sistema **tiró el `+` sin avisar** —la barra
pasaba a `Secretary, Search, Members (8), More filters` y desaparecía dar de
alta—, que es exactamente el límite de la quinta cápsula que ya documenta §4.

**Resuelto: el alta bajó a la lista.** `MembresiaView.listaCuerpo` abre con una
fila "Nuevo miembro" —`plus.circle.fill` y el texto en la marca, con el icono al
ancho del `Avatar` para que el nombre arranque en la misma vertical que los
demás—, y `botonNuevo` desapareció de la barra del teléfono. Así **las seis
pantallas de Secretaría tienen chevron**.

Se eligió frente a la otra salida —bajar el selector a un segmentado como el de
iPad— por dos costos medidos: el conteo de la etiqueta es lo único que dice
cuántas personas se ven y que la lista está filtrada, así que moverlo obligaba a
inventarle sitio; y ese sitio es una franja fija de cromo, justo lo que los
siete commits de esa tarde estuvieron quitando. La fila, en cambio, no gasta
cromo nuevo: la lista ya estaba.

**El costo aceptado, y medido:** la fila solo sale en Miembros. Seguimiento es
una lista de alertas —de ahí no nace un alta— y Asistencia no es una lista, así
que desde esas dos vistas hay que pasar a Miembros para dar de alta. Hay una
prueba que lo fija (`testElAltaSoloEstaEnMiembros`), para que sea una decisión y
no una sorpresa.

Verificado con la app corriendo, no compilando (iPhone 17e y iPad Pro 13", en
inglés): la barra del teléfono queda `Secretary, Search, Members (8), More
filters` con las cuatro cápsulas vivas, el chevron vuelve al hub, la fila abre
la hoja de alta, y en iPad el `+` sigue arriba y la fila no se dibuja. **El
quinto botón que sale al listar la barra no es un menú "More"**: es el
duplicado interno del `Menu` del selector —mismo marco y `hittable=false`—, así
que no hay nada escondido detrás.

### Lo que quedaba de Tesorería, enchufado — 7 de septiembre, 2ª vuelta

El §6 decía "enchufar lo que quede de Tesorería, mismo trabajo que Secretaría".
**No lo era**: las seis pantallas ya tenían su repositorio `Offline*` y su
sincronización. Lo que quedaba era otra cosa, y se encontró buscando quién
seguía leyendo una maqueta con la sesión abierta.

**1. Inicio, la primera pantalla de la app, era la maqueta entera.**
`DashboardViewModel` traía `MockDashboardRepository()` como valor por omisión
—sin mirar `ModoRevision` siquiera—, así que con la cuenta de la iglesia de
verdad seguía enseñando la iglesia Getsemaní de Monterrey, seis meses de barras
escritas a mano, cuatro movimientos inventados y una agenda de agosto. El hub
de Tesorería del teléfono lee ese mismo ViewModel: su KPI de saldo en caja
mentía igual.

Ahora `DashboardCalculado` lee de los mismos repositorios que las pantallas de
las que Inicio es resumen. Cuatro criterios que conviene no volver a discutir:

- **Solo lo aprobado cuenta** en ingresos, gastos y saldo — la regla del web y
  de los informes. Pero `movimientosTotal` y `sinDepositarCount` cuentan TODO:
  son trabajo pendiente, no cifras contables.
- **Seis barras siempre**, aunque estén vacías.
- **Lo reciente no se filtra por periodo**: es "lo último que pasó", y por mes
  estaría vacío cada día 1.
- **"Esta semana" sale de `AgendaRepository.resumen()`**, que ya calcula los
  próximos contra hoy.

**2. El selector de aportante de la hoja de captura iba a la red.**
`SupabaseAportantesCatalogo` consultaba `members` cada vez que se abría. Sin
señal —en el templo, que es donde se captura el sobre— el menú salía vacío y el
aporte se quedaba sin persona, y un aporte sin aportante no sale en su
constancia anual. Lee ya el mismo `padronParaSelector()` que los tres de
Secretaría.

**3. Dos badges de la sidebar del iPad** salían de `MockMiembrosRepository` y
`MockAgendaRepository` leídos a mano, saltándose las fábricas. Es exactamente el
fallo que ya se había arreglado en el hub del iPhone en junio de código: **una
maqueta leída directamente no es el modo revisión, está clavada en el código.**
Si aparece otro número raro, ese es el patrón que hay que buscar:
`grep -rn "Mock" Tamio/Views Tamio/ViewModels`.

**Lo que NO se tocó, y por qué:** `agregarCuenta` guarda la cuenta bancaria en
memoria y no en una tabla. **El web tampoco la tiene**: propone la cuenta del
último depósito y ya. Una cuenta escrita a mano sobrevive en cuanto se usa en un
corte, porque `cuentas()` las saca de los cortes guardados; solo se pierde la
que se teclea y no se usa. Reflejar, no diseñar.

**Probado:** diez pruebas nuevas (`InicioCalculadoTests`), 28 en total en verde.
**Sin verificar:** verlo en el aparato con la cuenta real — Inicio con datos de
verdad, y el selector de aportante en avión.

---

### Tesorería y el Dashboard — 6 de septiembre

Mismo criterio y misma forma de decidirlo: **contar la barra antes y después**
de devolver el chevron, con la app corriendo, y comparar. El sistema tira la
cápsula que no cabe sin avisar ni fallar, así que una sola medición no dice
nada; lo que informa es la diferencia.

Colgaban con `sinBotonVolver()` siete sitios: cuatro del hub de Tesorería
(Movimientos, Aportantes, Depósitos, Reportes) y tres del Dashboard (Por
revisar, Movimientos otra vez, y Agenda).

| pantalla | barra antes | con el chevron | |
|---|---|---|---|
| Movimientos | Search · filtros · **New** · segmentado | Treasury · Search · filtros · segmentado | **se cae el `+`** |
| Aportantes | File · Search · Active (9) · New | las cinco, enteras | cabe |
| Depósitos | Sort · New · segmentado | + chevron | cabe |
| Reportes | vacía | chevron | cabe |
| Por revisar | Approve N of M | + chevron | cabe |
| Agenda (Dashboard) | New | + chevron | cabe |

**Las seis recuperan el chevron**, aunque Movimientos tardó un día más.

**Movimientos: la lupa al cajón, y cabe todo.** Con el chevron, el sistema
tiraba el `+`. Las dos salidas que se barajaban costaban algo —bajar el `+` a la
lista como en Membresía, o renunciar al chevron— hasta que Iván propuso una
tercera: *"y si se pone la lupa cuando uno hace scroll down que salga"*.

Es `.searchable(placement: .navigationBarDrawer(displayMode: .automatic))`: el
campo se esconde y aparece al tirar hacia abajo, como en Mail. **No gasta
cápsula**, y esa cápsula libre es la que deja entrar el chevron sin quitarle
nada a nadie. Medido: la barra pasa de `Search · filtros · New · segmentado` a
`Treasury · filtros · New · segmentado`, y el segmentado hasta se lee más
holgado.

**Por qué no se había encontrado antes:** los experimentos que quedaron escritos
en `MovimientosView.pantalla` iban todos a bajar la lupa a la BARRA INFERIOR
—y ahí sí no hay salida, la barra del sistema queda debajo del TabView
flotante—. El cajón es hacia arriba, no hacia abajo, y nadie lo había probado.

**Y deja una pregunta abierta para Membresía:** allí el `+` bajó a la lista
porque las dos únicas salidas conocidas eran esa o quedarse sin chevron. Con el
cajón hay una tercera, y el `+` podría volver a la barra. No se ha tocado: la
fila de "Nuevo miembro" funciona y la decisión fue de Iván.

**`sinBotonVolver()` se queda sin usar.** No se borra: documenta con una prueba
que `navigationBarBackButtonHidden` apaga el gesto de borde, y eso vale aunque
hoy no lo llame nadie.

**Agenda se salía o no según por dónde entraras**: desde el hub de Secretaría
traía chevron desde el 5-sep y desde el Dashboard no. La misma pantalla.

Dos cosas que costaron una medición falsa cada una:

- **La pestaña "Por revisar" se llama igual que el aviso del Dashboard**, y
  `app.buttons` incluye la de la barra de pestañas. La prueba tocó la pestaña,
  abrió Revisar como raíz —donde no hay chevron que valga— y midió un "no cabe"
  que era mentira. Hay que filtrar por marco, fuera de la barra de pestañas.
- **Un segmentado sale como varios botones** al listar la barra
  (`Income`, `Expenses`), pero es UNA cápsula. Contar elementos en vez de
  cápsulas da un número inflado.

**Reportes tiene la barra vacía a propósito** hasta que se abre un informe: es
una pantalla de elegir entre dos. No es un fallo ni una barra que se cayó.

**Y una prueba de iPad corriendo en el iPhone parece una regresión.**
`IPadMembresiaTests` falló con `barra = ["Month", "Quarter", "Year"]` al correr
la tanda entera en el teléfono. Lleva un `XCTSkipUnless` por idioma de
dispositivo; si se escribe otra prueba solo de iPad, el mismo guardia.

---

### Las capturas de revisión SÍ son de HEAD — 5 de septiembre

Dos encargos seguidos dieron por hecho que el teléfono corría un build viejo,
por dos cosas de Informes de membresía que "no podían estar ahí": la tira de los
cuatro informes en iPhone y el botón de compartir en la barra. Las dos son de
HEAD, y las dos las puso el MISMO commit, `f62b932` ("En el teléfono no había
forma de llegar a tres de los cuatro informes"): quitó el gate
`sizeClass == .regular` y añadió el `.toolbar` de la pantalla. Lo que queda con
el texto del gate es un COMENTARIO que cuenta cómo estaba.

**Antes de escribir que una captura es de un build viejo, mirar `git log -S`.**

### El periodo de un informe no se lee de `r.periodo`

`InformeResumen.periodo` es texto del mock y con un rango devuelve la cadena
fija "Rango personalizado", sin las fechas. Quien sirve para enseñar el periodo
elegido es **`vm.etiquetaPeriodo`**, que cubre los cinco tipos —mes, trimestre,
año, rango con sus fechas, y todo el historial—. Es la diferencia entre poder
sacar los selectores de la pantalla o esconder estado sin sustituto.

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

### XCUITest NO sabe hacer un tirón de refresco — 6 de septiembre

`.refreshable` no se puede comprobar con una prueba de interfaz. Se intentó de
cuatro maneras —`swipeDown`, `swipeDown` doble, un arrastre lento sostenido con
`press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`, y buscar el
indicador entre `activityIndicators` y `progressIndicators`— y **ninguna
dispara el gesto ni lo detecta**: el control de recarga de SwiftUI no aparece
en el árbol de accesibilidad, así que no encontrarlo no prueba ni desmiente
nada.

Lo que sí lo zanja, y es lo que se hizo:

1. En la COPIA, meter dentro del cierre de `sincronizable` una escritura a
   fichero (`Documents/tiron.txt` al entrar y `tironFin.txt` al salir).
2. Instalar ese build, y **tirar con el dedo** en el simulador.
3. Leer el fichero desde el shell: `find .../Data/Application -name "tiron*.txt"`.

Salieron los dos con dos segundos de diferencia: el cierre corre, sincroniza
contra la red y recarga. La instrumentación no llega al repo.

**La moraleja no es sobre este gesto.** Es que una prueba que no encuentra algo
solo vale si sabes que sabría encontrarlo. Aquí se estuvo a punto de dar por
roto un gesto que funcionaba.

### La subida SÍ funciona — probada contra la cuenta el 6 de septiembre

**Las cuatro entidades nuevas suben.** `subirEvento`, `subirActa`, `subirCarta`
y `subirApunte` se ejercitaron contra `hkpbkpojeierxqtbmagh` con una fila
marcada por entidad (`PRUEBA-SYNC-NO-USAR`): las cuatro llegaron y la cola de
salida quedó vacía. Se enterraron después y la base quedó como estaba —agenda
3, actas 1, cartas 1, registro 0—.

Y la bajada también: la primera sincronización trajo 5 actividades, 5 actas y
5 cartas reales, y las cuatro migraciones corrieron en disco.

Dos cosas que salieron de hacerlo:

- **El motor rebota si ya está sincronizando.** `sincronizar()` tiene un
  guardia `estado != .sincronizando` y vuelve en el acto. El host de las
  pruebas ES la app, así que su `.task` de arranque ya lanzó una: llamar encima
  parece "no subió nada" cuando lo que pasó es que ni se intentó. Hay que
  esperar y reintentar.
- **`certificacion` no existía en el catálogo de cartas de iOS.** Dos de las
  cinco cartas de la iglesia lo usan y se leían como "Personalizada". Con
  datos de maqueta era invisible. Ver `TipoPlantilla.clave`.

### Las pruebas unitarias corren DENTRO del contenedor de la app

Y por tanto sobre la MISMA base local. Mientras el contenedor estuvo en modo
revisión eso era inofensivo. En cuanto se entró con la cuenta real, volver a
correrlas escribió en la base de la iglesia: `testEscribirYLeerUnaNota` era la
única de las cuatro que no borraba su fila al terminar, quedó en la cola de
salida y **la siguiente sincronización la subió a `public.registro`**.

Las de agenda, actas y cartas sí borran la suya, así que lo que mandaron fueron
lápidas contra filas que allá no existen: cero efecto. Por eso solo se coló una.

Dos reglas que salen de ahí:

- **Toda prueba unitaria borra lo que escribe**, aunque parezca que da igual.
- **No correr pruebas contra un contenedor con sesión.** Ni unitarias ni de
  interfaz: `AgendaTests.testAltaPersiste` da de alta una actividad llamada
  "Ensayo de prueba" desde el formulario, y con la sesión puesta subió dos a
  la agenda de la iglesia sin que nadie lo pidiera. Si hace falta correrlas,
  desinstalar la app antes (`xcrun simctl uninstall <udid>
  church.tamio.native`), que se lleva la base local con ella.
- **Y mirar la tabla remota después, no solo la cola.** Las dos de "Ensayo de
  prueba" no se vieron al revisar la cola de salida —ya estaba vacía porque ya
  habían subido—; aparecieron al listar `public.agenda` entera. Lo que
  demuestra que algo no subió es la cola vacía; lo que demuestra qué subió es
  la tabla.

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

### LO SIGUIENTE, en orden

**1.** ~~Los cinco sucesos de Tesorería.~~ **— HECHO el 7 de septiembre.** Los
diez sucesos del web se anotan ya en iOS. Dónde va cada uno y por qué
`corteEntregado` no va donde va en el web: §0. Dieciocho pruebas unitarias, cada
suceso con la suya de que anota **solo al cruzar el umbral**.

De paso: las claves de `datos` de tres sucesos no eran las que lee el web, y un
`datos` con un número dentro dejaba el apunte entero en guiones. También en §0.

**2.** ~~Enchufar lo que quede de Tesorería.~~ **— HECHO el 7 de septiembre**, y
no era lo que parecía: las pantallas ya estaban enchufadas y lo que quedaba era
Inicio entero, el selector de aportante y dos badges del iPad. Ver §5, "Lo que
quedaba de Tesorería, enchufado".

**3.** ~~Adelantar `main`.~~ **— HECHO el 7 de septiembre**, por avance rápido
hasta `3ffc483` (§1).

**4. Los cuatro de acabado de Secretaría**, que no impiden usarla:

- **"Próximos" en Servicios incluye cultos pasados**: la cabecera es un `Text`
  fijo sobre la lista entera, sin filtrar por fecha.
- **El selector de "Tipo de carta" ofrece quince** y cinco no existen en el
  catálogo del web —`autorizacion`, `solicitud`, `reconocimiento`, `bautismo`,
  `bienvenida`—: una carta de esos tipos sube un `tipo` que el web no sabe
  dibujar. La lista de PLANTILLAS ya solo enseña las once reales.
- **El responsable de una actividad se guarda como texto**, no como
  `member_uid`. `padronParaSelector()` ya devuelve el id de cada persona:
  falta usarlo al guardar.
- **En Actas y Servicios el estado sale dos veces** —en el subtítulo y en la
  pastilla— y por eso los títulos se cortan.

**Y lo que NO hay que hacer todavía:** soltar la tabla remota `mensajes`. Sigue
existiendo vacía a propósito hasta que todos los aparatos actualicen (§5).

---

### ~~El de arriba de todo~~ — HECHO el 6 de septiembre

**La sincronización se probó con la cuenta real, en las dos direcciones.** Ver
§5, "La subida SÍ funciona". Lo que queda de Secretaría ya no es verificar: es
código que falta.

Por orden de lo que más se nota usando la app un domingo:

1. ~~Pasar lista corre sobre nombres inventados.~~ **— HECHO el 6 de
   septiembre.** Los tres selectores leen `padronParaSelector()`. Comprobado
   en la app con la cuenta real: la hoja de asistencia y el responsable de una
   actividad enseñan las mismas siete personas del padrón.
2. ~~Firmar un acta no guarda quién firmó.~~ **— HECHO el 7 de septiembre.**
   `Acta.firmas` lleva los tres renglones con las claves del web —`preside`,
   `secretario`, `testigo`—, con su día. La hoja precarga lo ya firmado, y
   corregir el acta después no las borra: solo se pisan si el acta trae unas.

   De paso salieron dos cosas que solo se ven mirando la pantalla: el cuerpo
   decía **"se reunió el administrativa"** —el artículo se pegaba a una
   etiqueta que a veces es adjetivo, roto al pasar al catálogo del web— y el
   encabezado decía **"ACTA DE REUNIÓN DEL CONSEJO" para todas**. Ver
   `TipoActa.fraseEnActa`.
3. ~~El registro no anota nada automático.~~ **— HECHO a medias el 7 de
   septiembre.** Los cuatro sucesos de Secretaría ya se anotan solos:
   `cartaEmitida`, `actaCerrada`, `estadoMiembro` y `bajaMiembro`. Las llamadas
   van en los repositorios y no en las pantallas, como en el web, y solo al
   CRUZAR el umbral: guardar dos veces una carta ya emitida no anota dos veces.

   ~~Faltan los cinco de Tesorería.~~ **— HECHO el 7 de septiembre**, con el
   mismo `anotarSuceso(_:_:)` en `OfflineMovimientosRepository` y
   `OfflineDepositosRepository`. Ver §0.
4. ~~Las plantillas de carta viven en el `enum`.~~ **— HECHO el 7 de
   septiembre.** Tabla `plantilla` (v22) y `repositorioPlantillas()`. Bajan las
   once de la iglesia con su nombre y su texto, y elegir una rellena asunto,
   saludo, cuerpo y despedida.

   **Solo BAJAN**: el iPhone no crea ni edita plantillas —eso se hace en el
   web—, así que no hay `subirPlantilla` ni entidad en la cola. Código de
   subida que nadie puede ejecutar es código que nadie prueba.

   El cuerpo llega en HTML con variables `{{miembro_nombre}}`; `cuerpoLlano`
   le quita las etiquetas y conserva las variables, porque el editor del
   iPhone es de texto llano y las sustituye quien imprime.

**Con esto, Secretaría queda cerrada.** Lo que sigue está en "Lo que queda de
Secretaría, ya no bloquea" y en el §5 de Tesorería.

### Lo que queda de Secretaría, ya no bloquea

- ~~El informe General son constantes y Seguimiento enseña "Próximamente".~~
  **— HECHO el 7 de septiembre.** El General se calcula del padrón, como ya
  hacían Miembros y Asistencia; Seguimiento refleja `alertasSeguimiento` del
  web, con sus cuatro tipos de alerta, y el badge cuenta las de verdad.

  **`miembroDesde` NO es una fecha.** Es texto para leer —"Ingresó 2026"—; la
  fecha es `fechaIngreso`, "YYYY-MM-DD". Usar la primera hacía que las altas
  por mes salieran todas en cero y que una alerta dijera "desde Ingresó 2026".
  Lo mismo pasa con `Acta.fechaLegible` y `Apunte.texto`: en este código hay
  pares de campo-guardado y campo-para-leer, y el que se compara es el
  primero.
- **"Próximos" en Servicios incluye cultos pasados**: la cabecera es un `Text`
  fijo sobre la lista entera, sin filtrar por fecha.
- **El selector de "Tipo de carta" ofrece quince** y cinco no existen en el
  catálogo del web —`autorizacion`, `solicitud`, `reconocimiento`, `bautismo`,
  `bienvenida`—: una carta de esos tipos sube un `tipo` que el web no sabe
  dibujar. La lista de PLANTILLAS ya solo enseña las once reales.
- **El responsable de una actividad se guarda como texto**, no como
  `member_uid`. El selector ya lleva el id de cada persona: falta usarlo.
- **En Actas y Servicios el estado sale dos veces** y por eso los títulos se
  cortan.

### Lo que ya no bloquea

~~Probar la sincronización con la cuenta real.~~ Ya no son solo el padrón y los
cultos: son **cuatro entidades nuevas** —`evento`, `acta`, `carta`, `apunte`—
con su subida y su bajada escritas y jamás ejercitadas. El modo revisión no
toca la red, así que arrancar la app no prueba nada de esto.

Se hace poniendo `ModoRevision.activada = false` (§2.2) y entrando con la
cuenta. Conviene hacerlo **antes de acumular la quinta**: cuatro sin estrenar a
la vez es donde los errores se juntan y luego cuesta saber de cuál es cada uno.
Las migraciones sí están probadas contra la base local.

### ~~Los tres selectores de personas~~ — HECHO el 6 de septiembre

Eran `ServiciosView.miembrosMock` (12 nombres), `AgendaView.miembrosMock` (8) y
`CartasView.miembrosMock` (4), cada uno con su lista a mano y **sin coincidir
entre sí**: "Brenda Rosado" vs "Brenda Castillo", "Pedro Salas" vs "Pedro
García", "Susana Orts" vs "Susana Ortiz".

Los tres leen ahora `padronParaSelector()`, en `MembresiaRepository.swift`: id
y nombre, sin bajas, ordenado. El id se lleva aunque el selector solo enseñe el
nombre, que es lo que permitirá guardar el responsable de una actividad como
`member_uid` —eso sigue pendiente, la vista guarda el nombre—.

**Y las pruebas de interfaz ya no pueden mirar nombres.** `testMiembroDetalle`
buscaba "María Hernández Ríos" y fallaba con la sesión puesta: la lista trae el
padrón de verdad. Ahora toca la celda por posición. La suite se escribió contra
la maqueta y con sesión corre contra datos reales; lo que mire un dato concreto
va a fallar.

### El resto

1. **El mes es invisible en Ingresos.** Al quitar el pie, el mes solo se lee
   abriendo la hoja de filtros: en agosto las cabeceras dicen "VIERNES 29" y el
   mes no aparece en ninguna parte. Y `filtrosActivos` **no cuenta el periodo**,
   así que el botón no se tiñe al mirar un mes que no es el actual — una lista
   corta no se explica sola. Se arregla sumando el mes al contador.
2. **El total de Movimientos en iPad** ya solo vive en la hoja de filtros. Allí
   el pie no causaba ninguno de los tres problemas del teléfono.
3. **Verificar los recurrentes en aparato** (§5). Es el riesgo real que queda.
4. **Las dos medidas del cifrado** (§5).
5. ~~Membresía: probar la sincronización con la cuenta real~~ **— sigue
   pendiente y ahora es el punto de arriba de esta sección**, porque ya no es
   solo membresía.
6. **Los servicios ya tienen forma de fila** (v17: `servicioPuesto` y
   `servicioOrden`), con su repositorio y su sincronización. Lo que falta de
   esa pantalla es el resto de la ficha del culto —cantos, escuela dominical,
   conteos— que sigue guardándose pero sin verse.
7. ~~"Familia Ruvalcaba"~~ **— era una falsa alarma, resuelta el 6 de
   septiembre.** Estaba anotada como un problema de datos reales que esperaba
   una decisión de Iván. No lo era: **no existe en la base** —cero filas en
   `members` con ese apellido— y solo vivía en los datos de maqueta del iOS, en
   cinco archivos. Lo dijo Iván: *"la familia Rubalcaba es ficticio lo puedes
   borrar"*.

   **Borrada del todo**, no renombrada. El primer intento fue cambiarle el
   nombre por otro inventado, y Iván lo cortó —*"ella es ficticia también"*—:
   cambiar una ficha ficticia por otra no borra nada. La maqueta del padrón
   pasa de ocho fichas a siete, se va del catálogo de aportantes y de los
   destinatarios de Cartas, y su diezmo de $2,500 (cheque 8823) lo paga ahora
   Ana Lucía Torres, que sí está en el padrón: un movimiento cuyo aportante no
   existe en ninguna lista es una incoherencia que la maqueta no debe enseñar.
   Nada la referenciaba por parentesco, que era lo que había que comprobar
   antes de quitarla.

   **La lección es la de siempre:** un `select` de un minuto contra la base
   habría evitado anotar como pendiente de producto algo que era maqueta. Se
   apuntó mirando la app corriendo en modo revisión, que es justo donde los
   datos son inventados.
8. ~~Aplicar `frenar_baja_tesorero`~~ **— HECHO el 6 de septiembre.** Aplicado
   en el proyecto `hkpbkpojeierxqtbmagh`, que es al que apuntan las DOS apps
   (`Supabase.swift` y el `.env` del web). Antes se comprobaron los requisitos
   contra la base, no contra el archivo: las siete columnas que el disparador
   toca existen y con los tipos que da por hechos —`activo` entero con default
   1, `deleted` booleano, `fecha_baja`/`motivo_baja` texto y `updated_at`
   timestamptz—, y el de P1 vive en `transactions`, así que no había conflicto
   en `members`.

   Verificado con el bloque de comprobación del propio archivo, sobre los datos
   de verdad: `bloqueado=t` (la baja del tesorero rebota), `relevo=t` (una baja
   que YA estaba arriba, retransmitida, pasa limpia) y `sello_avanzo=t`. El
   `raise` final lo deshizo todo; comprobado después que no quedó ninguna fila
   con el rastro de la prueba.
9. **Reflejar `traslados_salida`.** Hasta entonces la pastilla "traslado en
   curso" no se ve: dejó de ser un estado de la persona y el expediente vive
   en esa tabla. Las tablas `traslados_salida` y `traslados_entrada` existen en
   Supabase y están vacías; Cartas ya sube a `public.cartas`, que es la mitad
   del expediente.

11. **El informe General sigue escrito a mano.** `InformesMembresiaViewModel`
   guarda las cifras de cada periodo como constantes, y el de Año dice 262
   miembros / 248 activos mientras el hub dice 248 / 236 y el informe de
   Miembros —el de al lado, mismo periodo— dice 7. Las tres se ven a la vez.

12. **El informe de Seguimiento promete tres alertas y enseña "Próximamente".**
   El badge `(3)` de `InformesMembresiaView.swift` está escrito a mano y al
   entrar sale un `ContentUnavailableView`. El web lo tiene resuelto en
   `services/informes/membresia.ts`: `alertasSeguimiento` y sus `TipoAlerta`.

13. **"Próximos" en Servicios incluye el pasado.** La cabecera es un `Text`
   fijo sobre `vm.lista` entera, sin filtrar por fecha, así que bajo "Próximos"
   aparecen cultos que ya pasaron.

14. **En Actas y Servicios el estado sale dos veces** —en el subtítulo y en la
   pastilla— y por eso los títulos se cortan ("Minutes 2026-07 · Asse…").
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
