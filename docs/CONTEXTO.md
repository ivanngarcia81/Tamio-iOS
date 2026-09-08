# Contexto de trabajo · Tamio-iOS

Este archivo existe para que una sesión nueva —o una persona que vuelve dentro
de un mes— no empiece de cero. **No es documentación del código**: eso ya está
en los comentarios y en los mensajes de commit, que en este proyecto explican
el porqué y no el qué. Aquí va lo que NO se deduce leyendo el repo.

Última actualización: **8 de septiembre de 2026**, al arreglar el folio que
impedía subir cualquier movimiento (§0.-5).

---

## 0.-5 Un día entero sin poder subir un solo ingreso ni gasto · 8 de septiembre

**El fallo más caro encontrado hasta ahora, y lo destapó una prueba de
recurrentes que parecía ir bien.**

Iván capturó dos gastos con el interruptor de "se repite cada mes". La
definición del recurrente subía; el movimiento, no. Ajustes decía **"Sin subir:
2 cambios"**, pulsó "Sincronizar ahora", el estado volvió a poner la fecha —o
sea, éxito— y **seguía diciendo 2**. Sin un solo aviso por ninguna parte.

### Qué era

`20260907_folios_por_serie_y_anio.sql` añadió `anio` a `folios_contador` y
rehízo la clave primaria como `(church_id, serie, anio)`. Escribió
`siguiente_folio_anual` con su `on conflict` de tres columnas, correcto. Pero
**dejó intacta la `siguiente_folio` de antes**, que seguía diciendo
`on conflict (church_id, serie)`: dos columnas contra una clave de tres.

Sin índice único que case, Postgres levanta `42P10` y PostgREST lo devuelve
como **400**. Y esa es justo la función que piden los movimientos —cartas y
actas van por la anual, por eso ellas nunca fallaron—.

**Desde el 7-sep a las 15:21 UTC hasta el 8-sep a las 15:48, ningún ingreso ni
gasto podía subir desde ningún aparato**, con la app asegurando que todo estaba
sincronizado. Un día entero de contabilidad quieta. No se perdió nada —la cola
reintenta, no tira— pero nadie tenía forma de enterarse.

### Cómo se encontró, que es lo reutilizable

El camino, en este orden, y ninguno de los pasos sobró:

1. **El `select` contra la base**, no la captura de pantalla. Las definiciones
   estaban arriba y los movimientos no: eso ya decía que el fallo estaba en la
   subida del movimiento y no en el recurrente.
2. **El contador de folios como testigo.** `folios_contador.gasto` seguía en 2
   con la marca del día anterior. El folio lo entrega el servidor al subir, así
   que un contador parado prueba que **ningún gasto había subido**, sin
   necesidad de mirar la app.
3. **Los logs de PostgREST**, que es lo que cerró el caso:
   `POST /rpc/siguiente_folio → 400`, dos por sincronización, decenas de veces.
4. **Y que NO hubiera nada en los logs de Postgres.** Esa ausencia es la pista
   fina: si el error no llega a Postgres, lo da el planificador antes de
   ejecutar —y `42P10` es de planificación—.
5. **La hora cuadró sola.** Último folio de gasto bueno: 14:29:30 del 7-sep.
   Contadores de carta y acta: 15:21:20 del 7-sep, que es cuando entró la
   migración anual. Todo lo de antes, bien; nada de lo de después.

**La lección, y es la misma de esta jornada:** una migración que cambia una
clave primaria tiene que revisar **todas** las funciones que hacen `on conflict`
sobre esa tabla, no solo la que se está escribiendo. Aquí se escribió la nueva y
se dejó la vieja mirando a una clave que ya no existía.

### Lo que dice de los seis arreglos de esta tarde

Esto estaba pasando **mientras se arreglaban**, y es la demostración en vivo de
que el §0.-4 no era teórico:

- Con la compilación de ayer el motor decía `.reposo` y la pantalla decía que
  todo iba bien. Con la nueva habría dicho **"2 cambios no pudieron subir:
  …"** con el error del servidor dentro, que es el hilo del que se tira.
- Y el reintento sin tope, que se apartó como defecto, aquí **salvó los datos**:
  los dos movimientos llevaban un día reintentando y subieron solos en cuanto
  la función respondió bien. Por eso se aparta y **no se tira**, y por eso el
  botón de sincronizar a mano las despierta.

### Cómo se arregló y cómo se comprobó

`20260908_el_folio_de_un_movimiento_no_se_podia_pedir.sql`, **aplicada y
verificada ANTES de que ningún aparato la usara**: bloque `do $$ … $$` que se
hace pasar por un miembro con `set_config` de `request.jwt.claims` —desde el
editor no hay `auth.uid()` y la comprobación de pertenencia rebota— y termina en
un `raise` que deshace el bloque entero. Contador antes 2, devolvió 3, y volvió
a quedar en 2. **El `raise` es la forma de que la prueba te cuente el número sin
gastarlo**, y aquí importaba: un folio emitido no se devuelve.

Después, la prueba de verdad, en el aparato de Iván: el "Sin subir" bajó a 0
solo, el contador pasó de **2 a 4**, y los dos gastos llegaron con folios 3 y 4.
**Dos folios para dos movimientos**, que era el otro riesgo después de un día de
reintentos.

### Lo que queda de aquí

- **`folio_previsto` lee sin filtrar por `anio`**. Hoy da igual —una serie de
  movimiento solo tiene la fila del año 0— pero es un `select into` que se
  traería una fila cualquiera si alguna vez hubiera dos. Anotado en la
  migración, sin tocar: no está roto y tocarlo sin necesidad es peor.
- **Los datos de prueba siguen en los libros**: cuatro definiciones recurrentes
  y sus gastos (Utilities $200 y $500, Limpieza $600 y $300). Dos de las
  definiciones están activas y **van a generar todos los meses** a partir del 1
  de octubre. Decisión de Iván: borrarlas, o apagar el interruptor —que para la
  serie sin hacer desaparecer lo ya registrado, que es lo que descuadraría un
  cierre—.

---

## 0.-4 La cola de salida, repasada entera · 8 de septiembre

Primera pasada de debug sobre `MotorSincronizacion.swift` —2 607 líneas, el
archivo más grande del repo— y los doce `encolar`. Es la zona a la que las
sesiones del 6 y el 7 le fueron colgando seis entidades nuevas (`evento`,
`acta`, `carta`, `apunte`, `plantilla`, `trasladoSalida`), cada una escrita por
separado y ejercitada una sola vez. Salieron seis cosas, y **cinco de las seis
eran variantes del mismo error de fondo**: dar por hecho que el servidor avisa.

### Lo que se arregló, y por qué son la misma historia

1. **Once `update` daban por bueno no haber tocado ninguna fila** (`82ac930`).
   PostgREST devuelve 204 y se va. Esto ya había costado TODO lo que se escribía
   en Ajustes · Iglesia, se diagnosticó, y `subirIglesia` se blindó con
   `nadieRecibioLaIglesia` — **solo esa**. Su propio comentario dejaba escrita
   la regla general y nadie la aplicó a las otras once. Ahora hay un
   `exigir(_:tabla:_:)` que pide `.select("uid")` y lanza si vuelve vacío.

   **El borrado queda fuera a propósito**: crear algo sin red y darlo de baja
   antes de que salga deja un solo `eliminar` en la cola pidiendo borrar una
   fila que allá no se creó nunca. Exigir confirmación la atascaría para
   siempre.

2. **`crear` no era idempotente** (`2d02056`). Once `insert` contra cinco
   `upsert(onConflict: "uid")`: el corte seguía exactamente la fecha en que se
   escribió cada zona, las cinco de Tesorería bien y las once anteriores no.
   Si el servidor guarda y la respuesta no vuelve, cada vuelta reintenta el
   mismo `insert` y recibe `duplicate key`. **Comprobado contra la base antes de
   tocar nada**, que era lo arriesgado: `uid` es la clave primaria de las
   catorce tablas.

3. **Editar algo lo mandaba al final de la cola** (`f4effe5`). Los doce
   `encolar` relevaban la operación previa con la fecha de AHORA, y
   `subirPendientes` ordena por `creadoEn`. Una persona de alta en Membresía y
   editada en Tesorería son dos entidades sobre la MISMA fila de `members`:
   corregir la ficha colocaba el alta detrás de la edición, el `update` salía
   contra un `uid` inexistente, y la `frecuencia_aporte` no llegaba. Ahora se
   conserva el turno. El porqué vive en `OperacionPendiente.creadoEn`.

4. **`intentos` y `ultimoError` no los leía nadie** (`9ba1ee7`). Cuatro
   apariciones en el proyecto: una escritura, dos declaraciones y la migración.
   **Cero lecturas.** Sin tope, una operación que no puede salir se reintenta
   para siempre y el motor sigue diciendo `.reposo`. Tras cinco intentos ahora
   **se aparta, no se tira** —descartarla sería perder algo escrito— y la
   sincronización termina en `.fallo` con la cuenta y lo que dijo el servidor.
   Los tres sitios donde se sincroniza A MANO las despiertan.

5. **La bajada descartaba una fila y adelantaba el cursor por encima**
   (`4b2f77d`). Una fila con algo pendiente de subir no se aplica, pero el
   cursor pasaba igual y la consulta es `>`: esa versión no se pedía nunca más.
   Y como se sube ANTES de bajar, estar pendiente ahí significa que la subida
   acaba de fallar. `AvanceCursor` se planta en el primer hueco.

6. **Una baja del padrón se podía resucitar** (`cfdbdaf`). Las dos subidas de
   `members` miraban solo la operación y no `fila.borrado`; las otras seis ya
   miraban las dos cosas.

### Lo que conviene no volver a descubrir

- **La lección que se repite:** cuando un comentario de este repo dice "esto se
  queda por si mañana pasa otra vez", conviene mirar **cuántos sitios más tienen
  la misma forma**. Aquí la regla estaba escrita, bien escrita, y aplicada en
  uno de doce sitios. Lo mismo con `.insert` frente a `.upsert` y con
  `fila.borrado`: en los tres casos el arreglo correcto ya existía en el
  archivo, copiado en unos sitios y no en otros. **Contar primero**, como con
  las píldoras del §0.0.
- **`XCTAssertEqual` y `XCTUnwrap` toman `@autoclosure`**, que no soporta
  concurrencia: un `try await` dentro no compila. Hay que llamar antes y
  comparar la constante. Costó dos vueltas de compilación de la copia.
- **Un `var` capturado y mutado dentro del closure de `cola.write` es aviso hoy
  y error en Swift 6.** `AvanceCursor` se declara DENTRO de la escritura.
- **Dos `xcodebuild` a la vez sobre el mismo DerivedData chocan**: `database is
  locked`, y el error no dice que el culpable seas tú. Uno cada vez.

### Cómo se verificó, que es lo reutilizable

Receta de §3, con dos cosas que conviene copiar tal cual:

- **Simulador propio y limpio**: `xcrun simctl create "Tamio pruebas limpio"
  "iPhone 17e"` → `535B863C-BCD2-4D92-AB5D-6FE9ED41FF02`. Nunca ha tenido
  sesión, así que el llavero está vacío y no hay a dónde subir (§3). **Se deja
  creado**: es la forma barata de correr la suite sin arriesgar la base.
- **Con el modo revisión APAGADO.** Encendido salen **43 fallos de 143**, y no
  son regresiones: la mitad de la suite pide los repositorios `Offline*` y en
  modo revisión se inyectan los `Mock*`. §3 los da como alternativas —"modo
  revisión encendido **o** simulador limpio"— y para las unitarias la buena es
  la segunda. Anotarlo aquí ahorra una tarde de perseguir fallos inventados.

Resultado: **143 pruebas, 0 fallos** (10 nuevas en
`pruebas/ColaDeSalidaTests.swift`, sobre las 133 que había). Y el `select` de
comprobación contra la base de la iglesia después de correrlas: cero filas con
los ids de prueba y cero filas tocadas en cuatro horas en `members`,
`transactions`, `cartas`, `registro` y `cortes`.

### Lo que queda abierto de esta zona

- **Nada de las once subidas se ha ejercitado contra el servidor.** Compila y la
  suite pasa, pero `exigir` y los `upsert` solo se demuestran con red. Es lo
  primero que hay que mirar la próxima vez que se entre con la cuenta.
- Las cinco subidas que ya usaban `upsert` —cortes, corte_movimientos,
  depósitos, categorías, recurrentes— **siguen sin comprobar que tocaron algo**.
  Se dejaron así a propósito: un `upsert` cuya política de UPDATE filtra sí da
  error, al contrario que el `update` suelto. Merece una comprobación con red
  antes de darlo por cerrado.
- **M2 sin verificar en la app**: falta saber si la interfaz deja llegar a
  editar una ficha ya dada de baja.
- Una operación apartada tras cinco intentos **no se ve en pantalla como tal**:
  se cuenta dentro de "Sin subir" y el estado dice el error, pero no hay una
  lista de qué se quedó fuera. Es lo siguiente si esto llega a pasarle a
  alguien de verdad.

---

## 0.-3 Una cuenta real destapó que la configuración inicial no se enseñaba nunca

8 de septiembre de 2026. Iván pidió que **Dennys Castillo** (`denedycastillo@hotmail.com`)
pasara a administradora de su propia iglesia; estaba de `secretaria` y sola en
ella desde julio, o sea **encerrada**: el único miembro de una iglesia que no es
administrador no puede invitar a nadie —la Edge Function lo comprueba— ni
administrar nada. Su rol ya está cambiado.

**Eso vale por sí solo como aviso de producto:** el disparador de registro te
hace ADMINISTRADOR de tu iglesia nueva. En una prueba se le bajó el rol y quedó
en un callejón sin salida que el producto ni impide ni detecta.

**Y de mirar su cuenta salió un fallo en el código de la víspera.** Su iglesia se
llama **"Mi Iglesia"**, que es lo que siembra el disparador:

    insert into iglesias (nombre)
    values (coalesce(nullif(meta->>'iglesia',''), 'Mi Iglesia'))

`ConfiguracionInicialView.haceFalta` comprobaba si el nombre estaba **vacío**. Un
nombre vacío no ocurre nunca, así que **la pantalla de configuración inicial no
se habría enseñado JAMÁS** — ni a Dennys ni a ningún cliente nuevo. El comentario
decía que reflejaba la regla del web, y el web compara contra el literal
(`esPrimerArranque`, `church.nombre === "Mi Iglesia"`). Se leyó la regla, se
resumió y se implementó el resumen.

Arreglado: el centinela es "Mi Iglesia" (y el vacío se sigue aceptando, por si
alguien lo borra a mano), con `PreferenciasApp.iglesiaConfigurada` de guarda —el
equivalente del `localStorage` del web— para que a una iglesia que de verdad se
llame así no se le pregunte en cada arranque. Dos pruebas nuevas, una por cada
mitad.

**La lección, que no es nueva pero volvió a costar:** cuando se refleja una regla
del web, se copia la regla, no lo que uno entendió de ella. Y el fallo no salió
de leer el código: salió de mirar una cuenta de verdad.

---

## 0.-2 El bundle id, y la trampa que deja escrita

Decidido con Iván el 8 de septiembre de 2026, y anotado porque es una decisión
que solo se puede tomar UNA vez.

**Ya hay una app publicada.** `com.tesoreria.app` es la de Tauri del repo
`Tamio-app`: en App Store desde el 13 de agosto de 2026, hoy con la 1.3.5 en
TestFlight. Corre en macOS, iPad y iPhone desde una sola base de código. Y
salió **gratis, sin login y 100 % local** — sus propios documentos dicen que se
hizo así para pasar la revisión.

**Y la nativa sale como ficha NUEVA, en `1.0.0`.** Estuvo un rato puesta en
`2.0.0`, cuando el plan era heredar la ficha de Tauri. Se revirtió el mismo día
tras razonarlo: son dos productos distintos —la publicada es gratis, offline y
de un solo usuario; la nativa es nube, tres roles y cuenta obligatoria—, la
ficha tiene tres semanas y media, y una 2.0 rechazada se quedaría encima de un
producto que hoy se vende. "2.0" además solo significa algo para quien conoció
la 1.x, y esa gente no va a ver esta ficha.

**El nudo, que hay que resolver antes de la primera subida:**

1. **Una app publicada NO puede cambiar de bundle id.** "2.0 de esa misma app"
   y "id propio" no pueden ser las dos verdad el día de la subida. Hoy el id se
   queda en `church.tamio.native`, a petición de Iván; el día que se suba a esa
   ficha tiene que decir `com.tesoreria.app`. Equivocarse ahí crea una app
   distinta **para siempre**.
2. **El número de compilación tendrá que subir por encima del de Tauri.**
   `CURRENT_PROJECT_VERSION` es `1`, y en esa ficha ya hay builds de la 1.3.5.
   Hay que mirar el número real en App Store Connect y ponerlo por encima, o la
   subida se rechaza.
3. **El cobro: verificado el 8-sep-2026 contra el texto vigente de las
   directrices, y hay camino limpio.** No hace falta escribir compras dentro de
   la app.

   - **3.1.3(c) Enterprise Services**: *"If your app is only sold directly by
     you to organizations or groups for their employees or students… you may
     allow enterprise users to access previously-purchased content or
     subscriptions."* Tamio se vende POR IGLESIA, a una congregación con tres
     roles. Encaja.
   - **3.1.3(f) Free Stand-alone Apps**: una app gratis compañera de una
     herramienta de pago web queda fuera de la compra integrada *"provided
     there is no purchasing inside the app, or calls to action for purchase
     outside of the app"*. Es el respaldo del argumento.
   - **3.1.3(b) Multiplatform Services NO sirve**: permite honrar lo comprado
     en la web *"provided those items are also available as in-app purchases
     within the app"*. Exige IAP igual.
   - **Enlazar fuera**: 3.1.1(a) dice que los entitlements *"are not required…
     in their United States storefront apps"*. En EE. UU. se puede enlazar;
     fuera hace falta el entitlement.
   - **Exigir cuenta está permitido**: 5.1.1(v) solo obliga a dejar entrar sin
     login si la app *"doesn't include significant account-based features"*.
     Nube, tres roles e invitaciones lo son.

   **Lo que eso obliga:** la app no puede decir dónde se paga. Por eso el pie
   del plan dejó de decir "para cambios de plan o cortesías contacta soporte" y
   ahora solo dice que aquí no se cambia. Y conviene que la ficha y la web
   dejen claro que se vende **a iglesias**: 3.1.3(c) añade que *"Consumer,
   single user, or family sales must use in-app purchase"*, y un pastor solo
   comprando para sí es el punto flojo del argumento.

   Lo que queda del choque no es de negocio sino de producto: la publicada
   funciona 100 % local sin cuenta y la nativa no, así que a esos usuarios una
   actualización los dejaría colgados. Es la razón que sostiene la ficha nueva.

---

## 0.-1 El español que asomaba con la app en inglés

Iván mandó una captura de **Ajustes · Institución en inglés** con las siete
sugerencias grises en español —"p. ej. Nuevo León", "p. ej. Lucía Márquez"— y
una frase: *"Si la app está en inglés no debería salir esto en español"*. De
ahí salieron **dos fallos distintos**, y el segundo no era de interfaz.

### Uno: diecisiete ejemplos sin pasar por `L.t`

Cinco en Iglesia, siete en Institución, dos en Tesorero y pastor, el correo de
la invitación en Acceso, el de la ficha de Membresía y uno del iPad.

**El criterio ya existía y no hubo que inventarlo**: el iPad traducía los suyos
CAMBIANDO el ejemplo —"Nuevo León" → "New Jersey", "Lucía Márquez Peña" →
"Jane Smith"—, que es lo único que tiene sentido en un campo de ejemplo. El
teléfono nunca recibió esa pasada. Es la misma forma de fallo que tenían las dos
tablas de iconos antes de `SeccionAjustes`: un dato con dos dueños que se
separan.

Dos cosas que solo se supieron mirando, no leyendo:

- **El ejemplo del iPad NO cabe en el teléfono.** "e.g. 1420 Constitution Ave."
  salía cortado con puntos suspensivos. El teléfono lleva uno corto; el iPad
  conserva el suyo, que allí entra de sobra.
- **La maqueta llena todos los campos, así que el ejemplo NO SE VE NUNCA** con
  los datos de muestra. Hay que vaciar `MockConfiguracionIglesiaRepository` en
  la copia para que asome. Es lo que hace `pruebas/EjemplosEnInglesUITests.swift`.

Y una del método: **el grep que los encontró se comió `correo@ejemplo.com`**
—ni tildes ni artículos—. Apareció en la foto, no en el barrido. Un detector de
español que solo busca acentos deja fuera justo los literales técnicos, que son
los que más se olvidan.

### Dos: el cargo por omisión, que no era interfaz sino dato

En esa misma fila, **"Title · Secretario" no era una sugerencia gris: era un
valor guardado.** `ConfiguracionIglesia` traía `pastorCargo = "Pastor"`,
`tesoreroCargo = "Tesorero"` y `secretarioCargo = "Secretario"`, y los tres
suben tal cual a `iglesias.pastor_cargo`, `tesorero_cargo` y `secretaria_cargo`.

**El web lo resuelve al revés, y aquí manda él**: deja la columna NULA y traduce
al imprimir (`church.secretaria_cargo ?? t("cartas.rolSecretaria")`). O sea que
en cuanto un iPhone guardaba Ajustes · Iglesia escribía "Secretario" en la
columna compartida y **le apagaba al web su traducción para siempre**. Se veía
además en Tesorero y pastor: la fila decía "Tesorero" mientras su propio Picker
ofrecía "Treasurer".

Lo que más vale guardar de esta parte:

1. **`Catalogos.Cargos` ya había arreglado esto para las OPCIONES del Picker**,
   con un comentario que describe el fallo entero. Las omisiones del modelo se
   quedaron atrás. Cuando un comentario cuenta un fallo, conviene preguntarse
   si el arreglo llegó a todos sus lados.
2. **Vaciar en el aparato no bastaba.** La siguiente bajada traía "Secretario"
   otra vez, porque el servidor lo tiene escrito desde que una versión anterior
   lo subió. Por eso la semilla se reconoce también AL BAJAR
   (`Catalogos.Cargos.sinSemilla`). Un arreglo que solo mira la escritura deja
   la lectura resucitándolo.
3. **La subida manda NULO, no `""`.** El `??` del web solo salta con nulo: una
   cadena vacía le dejaría el pie de la carta sin cargo en vez de traducido.
4. **La v26 vacía solo lo que es EXACTAMENTE la semilla.** No hay forma de
   distinguirla de un "Tesorero" tecleado a mano, y no hace falta: vacío se
   imprime igual "Tesorero" en español y "Treasurer" en inglés, que es lo que
   esa iglesia quiere en los dos casos. "Tesorera" y "Pastor asociado" no se
   tocan.

De vocabulario: la omisión de la secretaria pasa a "Secretaria", no
"Secretario", que es lo que dice el web y lo que ya decía el rótulo de al lado.

### Queda abierto

- **La fila del servidor sigue con la semilla** hasta que alguien guarde Ajustes
  desde iOS: entonces sube nula y el web recupera su traducción. Si se quiere
  antes, es un `UPDATE ... SET secretaria_cargo = NULL WHERE secretaria_cargo =
  'Secretario'` en `iglesias` (y las otras dos). **No se corrió**: el
  clasificador bloqueó el `select` de comprobación, así que no se llegó a ver
  qué tiene la fila real.
- **El resto de la app no se barrió a fondo.** El barrido ampliado dejó unos
  cuantos candidatos fuera de Ajustes que resultaron falsos —`L.plural`,
  ternarios sobre `L.esEspanol`, claves de `Chart(.value:)`—, pero el detector
  no es una garantía: se le escapó uno en la primera pasada. Vive en el
  historial de esta sesión, no en el repo.

### Cómo se verificó

La receta del §3, con dos apaños que se pueden reutilizar:

- **Una prueba por pantalla, cada una desde cero.** El botón de volver de esta
  app NO vive en `navigationBars` —es el chevron redondo de `NavHeader`— y
  buscarlo ahí no devuelve nada. Relanzar sale más barato que perseguirlo.
- **"Church" es a la vez la fila y el título de su sección**, así que
  `staticTexts["Church"]` toca la cabecera y no navega. La cabecera NO está
  dentro de una celda y la fila sí: `app.cells.containing(.staticText,
  identifier:)` las separa.
- Las capturas, con el bucle de `simctl io … screenshot` cada dos segundos
  contra la prueba corriendo en segundo plano, y después agrupando por tamaño
  de archivo: las pantallas quietas salen repetidas y las de transición no.
- **Y con el modo revisión encendido en la copia, 43 unitarias se caen.** No es
  una regresión: en modo revisión los repositorios son maquetas con datos, así
  que "sin movimientos no inventa nada" recibe cifras de verdad. Hay que
  apagarlo antes de correr la suite. Con él apagado, **112 en verde**.

---

## 0.0 Los arreglos visuales del iPad · rama `arreglos-ipad`

**Dieciocho arreglos —veintiún commits con los de este archivo— en una rama
aparte**, reposada sobre `liquid-glass` y fusionada por avance rápido. Los
quince primeros son la revisión del iPad; los tres últimos, los pendientes que
esa pasada dejó abiertos y que se cerraron después. Se trabajó en un `git
worktree` propio (`~/Desktop/Tamio-iOS-ipad`) porque otra sesión tenía el árbol
de `~/Desktop/Tamio-iOS` ocupado a la vez.

Origen: una revisión de doce capturas del iPad en apaisado y en inglés, con la
cuenta real. El encargo venía escrito contra `0c8a914`; la rama estaba dos
commits más adelante y se partió del extremo.

**Dos de los diecisiete arreglos se cayeron al reposar la rama, y conviene
saber por qué**: la otra sesión los había hecho mientras tanto, y mejor.

- **A6, la fecha de la carta**, lo resolvió `af89086` de raíz: la vista previa
  ya no es una tarjeta aparte con su propio membrete, es **la hoja que se
  imprime**. Mi versión solo cambiaba la fecha de las dos tarjetas.
- **B7, el folio del informe**, lo resolvió `fb91edb` — y mi conclusión era
  falsa. Yo miré `TrasladoEnCurso` y la lectura del repositorio, vi que
  filtraba por `enCurso`, y deduje que el folio de un traslado cerrado **no
  existe**; propuse quitar las dos columnas y así se decidió. Lo que pasaba es
  que el dato **sí está en la base del aparato** y ese filtro lo tiraba al
  leer. Quitar la columna habría escondido un dato que estaba a un `guard` de
  distancia. La lección no es nueva y está tres líneas más abajo: comprobar la
  premisa, también cuando la premisa es tuya — y "no existe" hay que
  perseguirlo hasta la consulta, no hasta el modelo.

### Lo que se cerró

Un commit por punto, y el título de cada uno cuenta el problema:

- **La dona sumaba 101 %.** Cada porcentaje se redondeaba por su cuenta.
  `Money.reparto` da los puntos que faltan a las partes con el resto decimal
  mayor, en la dona y en las tres tablas de categoría (pantalla y los dos PDF).
- **"1 records".** `L.plural` en el `enum L`, aplicado en los cinco sitios que
  lo pedían.
- **Los dos meses de la dona** ("September" en Inicio, "september" en
  Reportes), unificados en `L.mesSuelto`.
- **Seis plantillas de carta que decían "Iglesia Getsemaní"** dentro del
  cuerpo, con el nombre real de Ajustes. Más el typo "oficiant".
- **`.disabled` sobre `.glass`** a 1.70:1, en los cuatro botones que lo tenían.
- **El título de la ficha de aportante** pisaba el de la columna en iPad.
- **El resumen mensual partía los importes** en dos y tres renglones.
- **Las tarjetas vacías de Inicio**, la **fila del aportante con la fecha ISO**,
  **la píldora de la bandeja**, **los dos botones grises del corte**, **el ancho
  de la columna del calendario**, **el día vacío dicho dos veces** y **el
  detalle de un ingreso repetido**.
- **A8**, que era decisión de Iván: el contador de la carta cuenta la firma.

Y después, los que la pasada había dejado abiertos:

- **"May" se partía en "Ma" sobre "y"** en la gráfica de altas por mes. Doce
  columnas en el ancho del teléfono dan 25 pt, y a `.caption2` cuatro meses no
  caben. Apareció mirando lo anterior, en la misma pantalla.
- **Las tarjetas vacías del teléfono**, que era el mismo hueco tapado en el iPad.
- **B5, las tres píldoras en minúscula.**

### Lo que NO era lo que el pendiente decía

Esto es lo que ahorra tiempo a la próxima sesión:

1. **B1 tenía un comentario que lo justificaba, y el comentario era falso.** La
   píldora cian se defendía con «lo que reclama ya lo dicen los badges naranjas
   de al lado»: en esa fila **no hay más badges**, esa es la única. Merece la
   pena leer la fila entera antes de creerse un comentario.
2. **B2 decía "el único `.bordered` con tinte gris de la app". Eran dos**, los
   dos en `CorteDetalle`: "Nuevo corte" y "Segunda firma". Arreglar solo el
   primero dejaba el panel con dos estilos de botón a la vez, peor que antes.
3. **A6 se quedaba corto.** El literal "20 de agosto de 2026" estaba en la
   tarjeta de vista previa, sí, pero la hoja grande ponía **la fecha de hoy**,
   no la de la carta: el mismo documento cambiaba de fecha según el día en que
   se abriera.
4. **A2 se dejaba uno fuera.** El subtítulo del día de Agenda dice "1
   pendientes" y "1 completos", y no estaba en la lista de cinco.
5. **A5 se dejaba tres fuera.** Hay cuatro `.buttonStyle(.glass)` con
   `.disabled` en la app, no uno.
6. **A10 le pasa igual al teléfono** (`tarjetaListaIPhone` tiene el mismo
   hueco). No se tocó: taparlo cambia el alto de una pantalla que no entraba en
   esta pasada. Queda apuntado.
7. ~~**B7 es un hueco de esquema.**~~ **Era falso, ver arriba.** El folio de un
   traslado cerrado sí está guardado; lo tiraba un filtro de la consulta. Lo
   arregló `fb91edb`.
8. **`Money.reparto` se comprueba a sí mismo.** Hay porcentajes que a propósito
   no suman 100 (los gastos del mes contra el ingreso del mes). La función mira
   si las partes SON el total y, si no lo son, redondea cada una por su cuenta:
   la regla no depende de que quien llama se acuerde.

### La decisión de Iván

- **A8 · el contador de la carta cuenta la firma** (`0 de 4`). No era solo
  cuadrar el número: ese contador es lo que deja emitir, y hasta ahora una carta
  podía emitirse **sin ningún firmante**.

De B7 se decidió lo contrario de lo que acabó pasando —quitar las columnas—
sobre un diagnóstico mío que era falso. No se llegó a fusionar; manda `fb91edb`.

### Dos cosas de la lista de "no tocar", ya resueltas mirándolas

- **Los conteos que no cuadraban entre pantallas** cuentan universos distintos,
  y se ve en la maqueta: Aportantes dice 9 y el informe de membresía dice «7
  members» con Active 6 · Removed 1 — que cuadra consigo mismo. No hay nada que
  arreglar; son el padrón y los aportantes, que no son la misma lista.
- **El icono de filtro que asomaba tras la sidebar** en la captura de
  "Membership reports" **no se reproduce**. En el simulador la barra de esa
  pantalla sale entera y en su sitio.

### Cómo se verificó, que es reutilizable

La receta del §3 funciona; esto es lo que le faltaba para una revisión visual:

- **El apaisado se consigue con XCUITest**, no con `simctl`:
  `XCUIDevice.shared.orientation = .landscapeLeft` en el `setUp`. El simulador
  no gira desde el shell, y hacerlo por AppleScript se queda colgado pidiendo
  permiso de accesibilidad.
- **Las capturas, con `simctl` y no con `XCTAttachment`.** El adjunto de
  XCUITest en apaisado devuelve la imagen rotada dentro de un lienzo apaisado y
  **recorta**; `xcrun simctl io <udid> screenshot` más `sips -r -90` sale
  entera. El truco de la marca y el `sleep` del §3 es el que las sincroniza.
- **Los estados que la maqueta no produce se fuerzan en la COPIA**: las tarjetas
  vacías de Inicio, el botón de depositar apagado, y los millones de la tabla
  del resumen (multiplicar por 185 en `ReportesRepository.mensual`). Nunca en el
  repo.
- **La comprobación del teléfono se hace con un diff de píxeles** entre la rama
  y su base, con el mismo recorrido de nueve pantallas en el 17e. Las nueve
  salen idénticas — **pero un diff solo vale con una corrida de control**, y
  aquí hizo falta dos veces:
  - La cápsula de cristal del botón "Nuevo" de Inicio cambia un 0.018 % **entre
    dos corridas del mismo código**. Es ruido de render.
  - Agenda salió una vez con los puntos de evento ausentes y "0 pending" en el
    subtítulo: la captura llegó **antes de que cargara la agenda**. El
    subtítulo es el testigo — si dice "0 pending", la foto es prematura y no
    hay nada que investigar.

  Las dos veces, la primera lectura era "hay una regresión" y la segunda
  corrida la desmontó.
- **El modo revisión (`Support/ModoRevision.swift`) se enciende en local para
  recorrer pantallas sin credenciales** y se apaga antes de commitear. Ninguno
  de los diecisiete commits lo lleva encendido.

---

## 0. La sesión del 7 de septiembre, entera

**Empezó por el §6 —los cinco sucesos de Tesorería— y acabó en el contador de
folios de Postgres.** Diecisiete commits en iOS (`deae12c`…`5849caa`), dos en el
web (`790a95f`, `b9f1ba5`) y una migración aplicada en Supabase. **El §6 quedó
sin trabajo pendiente**: lo que resta son dos decisiones de Iván.

### Lo que se cerró, por orden

1. **Los cinco sucesos de Tesorería** se anotan (§0.0.a). Con eso, los diez del
   web.
2. **Las claves de `datos` del registro no eran las del web** en tres sucesos, y
   un `datos` con un número dentro dejaba el apunte entero en guiones.
3. **Lo que quedaba de Tesorería** no era enchufar pantallas —ya lo estaban—:
   era **Inicio**, que era la maqueta entera con la cuenta real abierta, el
   selector de aportante, que iba a la red, y dos badges del iPad (§0.0.b).
4. **La recarga al terminar la sincronización** (`sincronizable`), que solo se
   ve corriendo la app.
5. **Los cuatro de acabado de Secretaría**, de los que dos no eran lo que el
   pendiente decía (§6, punto 4).
6. **El año de un aporte se leía en local sobre una fecha guardada en UTC**: el
   1 de enero contaba en el año anterior y su importe se iba de la constancia.
7. **El `+` de Membresía volvió a la barra** y la lupa al cajón, y **el iPhone
   dejó de girar** (§4).
8. **El mes, visible** en el encabezado de cada día de Ingresos. **La ficha del
   culto** enseña lo que se capturaba y no se veía. **`traslados_salida`**
   reflejado (v23), con su pastilla.
9. **Se podía firmar y emitir una carta sin escribir nada** (§4).
10. **El folio de los documentos que se firman, al servidor** (§4 y §6).
11. **Las ocho secciones de Ajustes se pintaban para todos los roles**, aunque
    el web ya escondiera dos. Ver §0.0.c.
12. **El logo de la iglesia**, que la pantalla llevaba prometiendo como
    "Próximamente". Ver §0.0.d.
13. **Secretaría no producía ningún PDF**: ni cartas ni actas. Ver §0.0.e.
14. **Los traslados del informe salían sin folio y sin iglesia**, con los dos
    datos en el aparato. Y se fueron 154 líneas de maqueta muerta. Ver §0.0.f.
15. **La restauración de un respaldo**, que llevaba desde siempre en
    "Próximamente" y tenía apagados otros dos botones. Ver §0.0.g.
16. **Tres frases de pantalla que decían algo sin haberlo mirado**: el
    subtítulo de Actas, el "guardado hace 2 minutos" y un "Próximamente" de
    Reportes que era en realidad la carga. Ver §0.0.h.
17. **La última pasada de promesas**: la purga se descartó, Ayuda y Acerca de
    se fueron, el membrete tiene su vista previa y los traslados se ven enteros
    en el teléfono. Ver §0.0.i.

### Las tres lecciones de esta vuelta

**Un pendiente escrito no es un hecho.** De los diez que se tocaron, **cuatro
decían algo falso**: "enchufar Tesorería" ya estaba enchufado, "cinco tipos de
carta" eran dos, "Próximos incluye el pasado" era un rótulo equivocado y no un
filtro, y el responsable de una actividad no solo se guardaba mal —una actividad
creada en el web llegaba al teléfono SIN responsable—. Comprobar la premisa
cuesta un `grep` o un `select`.

**Y una premisa mía también.** Propuse renumerar tres actas con folio repetido;
al mirarlas antes de tocar, **cuatro de las cinco estaban borradas** y no había
duplicado vivo. La causa tampoco era la que dije: el `count(*)` del web hacía
que al borrar un acta la siguiente volviera a nacer 001. Un aparato solo bastaba.

**Correr la app encuentra lo que 55 pruebas no.** El fallo de la recarga —Inicio
en ceros según quién terminara antes— solo aparece con la base vacía y la
sincronización a medias. Y el mes escrito en el botón de filtros lo descartó el
simulador, no el razonamiento: no cabía y el sistema se lo comía sin avisar.

### Cómo se verifica ahora

**55 pruebas unitarias** en `pruebas/`, que ya no viven solo en el temporal. La
copia lleva **bundle id propio** (`church.tamio.pruebas`): con el de la app real
compartían contenedor y SESIÓN, y el anfitrión sincronizaba en mitad de una
prueba (§3). Para las pruebas de INTERFAZ hay que ponerle el id real, porque
necesitan la sesión.

### Lo que queda, y es decisión de Iván

- ~~El cifrado local~~ **decidido y hecho el 7 de septiembre**: opción A. Ver
  `docs/CIFRADO-LOCAL.md`, que ahora abre con lo que se decidió y por qué.
- **No soltar la tabla `mensajes`** hasta que todos los aparatos actualicen.
- ~~Adelantar `main`~~ **hecho el 7 de septiembre**: `3ffc483` → `46dd4fe`,
  veintinueve commits, y lo corrió la sesión (§1).

---

### 0.0.c Ajustes no filtraba por rol, y de ahí salían los CSV

El app web lleva las dos reglas escritas en su tabla `ZONAS`: Categorías con
`visible: verTesoreria` y la zona delicada con `visible: esAdmin`. En iOS no
estaban, ni en el teléfono ni en el iPad: las ocho filas se pintaban para
cualquiera.

**No era cosmética.** Los dos botones destructivos de la Zona de riesgo estaban
apagados esa mañana —dejaron de estarlo por la tarde, §0.0.g—, pero la pantalla
EXPORTA desde siempre: de ahí
salen "Exportar movimientos (CSV)" y "Exportar aportantes (CSV)". Una secretaria
—a quien `Permisos.ve(.tesoreria)` le cierra Tesorería entera— se llevaba la
tesorería completa desde Ajustes, y un tesorero sin `tesoreroVePadron` se
llevaba el padrón que no puede ni abrir. Es el mismo agujero que ya cierra
`areasDelRegistro`, y con el mismo argumento escrito allí: lo que la navegación
cierra por delante no puede quedar abierto por detrás.

La regla vive en `Permisos.veAjuste(_:)` y no en las vistas, porque la pregunta
la hacen dos pantallas y tienen que contestar igual — que es exactamente lo que
no pasaba cuando cada una tenía su propia enumeración de secciones (§ el
comentario de `SeccionAjustes`).

**Dos detalles que solo se ven corriendo la app:**

- El número de versión vivía al pie de la ÚLTIMA sección de la lista del
  teléfono, que era la Zona de riesgo. Al esconderla, la versión se iba con
  ella. Ahora el pie salta al grupo "General" cuando la Zona no está.
- En el índice del iPad, la Zona de riesgo va detrás de un `Divider`. Esconder
  solo el botón dejaba el separador y su hueco. Se esconde el bloque entero.

Verificado con seis pruebas unitarias (`pruebas/SeccionesDeAjustesTests.swift`)
y corriendo la app en los dos aparatos con el perfil de ejemplo parcheado al rol
(`pruebas/AjustesPorRolUITests.swift` explica cómo).

**Lo que NO se tocó, a propósito:** Cuenta y Preferencias las ve todo el mundo
—cerrar sesión, el candado y el idioma no son de un rol—, y las cuatro del grupo
Iglesia siguen abiertas: el membrete y las firmas los usan los documentos de las
dos áreas, y Acceso ya se reserva por dentro con `administraPermisos`.

**La promesa del logo, que estaba en falso**, se cumplió en la misma sesión:
ver §0.0.d.

### 0.0.d El logo de la iglesia

Iván lo pidió al ver que la descripción de Ajustes · Iglesia prometía un logo
que no existía ni en iOS ni en el web. **Se decidió el esquema aquí**, así que
esta vez iOS va por delante del web y no al revés.

**Las tres decisiones, con su porqué:**

- **La columna guarda la RUTA, no la imagen** (`iglesias.logo_path`, migración
  `20260907_logo_de_la_iglesia.sql`, aplicada). Los bytes viven en Storage y
  cacheados en Application Support. La ruta lleva un UUID nuevo cada vez, así
  que **la ruta ES el número de versión**: "¿tengo yo este logo?" se contesta
  mirando si existe ese archivo, sin marcas de tiempo ni banderas.
- **En el bucket `comprobantes`**, bajo `<church_id>/logo/<uuid>.png`, y no en
  uno propio: sus tres políticas ya aíslan por iglesia mirando el primer
  segmento de la ruta. Un bucket `logos` habría sido escribir esas mismas tres
  políticas otra vez para no ganar nada.
- **El logo SÍ se sincroniza, la firma NO**, y es la pareja que conviene leer
  junta (`LogoIglesia` contra `FirmasLocales`). Una firma que viaja a todos los
  aparatos es un sello que cualquiera estampa; un logo no autoriza nada, y un
  membrete que cambia según el aparato desde el que se imprime no es un
  membrete. Por lo mismo el logo **no entra en el respaldo**: vuelve solo con la
  siguiente sincronización, mientras que la firma solo existe en el aparato.

**Dónde sale:** los seis membretes —estado financiero, reporte anual, reporte de
aportes, constancia, carta y acta—. Los tres primeros lo llevan a la izquierda,
que es como encabezan; carta y acta, centrado sobre el nombre. La constancia
faltó en el primer recuento porque su encabezado se escribe con `iglesia.nombre`
y no con `membrete`, así que no aparecía al buscar los membretes — y es el
documento que la gente lleva a hacer su declaración.

**Lo que encontró correr la app, y ninguna prueba unitaria podía:**

1. **El logo salía en Ajustes y no en el PDF.** `LogoMembrete` guardaba la
   referencia en un `@State`, y el PDF se dibuja con `ImageRenderer` FUERA de la
   jerarquía de vistas, donde ese `@State` no llega a instalarse. `FirmasPDF` ya
   lo tenía resuelto con una propiedad normal; bastaba mirarlo.
2. **El membrete de los tres reportes se fue al centro de la página.** Meterlo
   en un `HStack` hace que ocupe todo el ancho y reparta el sobrante. Un
   `Spacer(minLength: 0)` al final lo devuelve a la izquierda — y de paso dejó
   de truncarse la línea de la ubicación.

**Verificado**: siete pruebas unitarias (`pruebas/LogoDeLaIglesiaTests.swift`),
entre ellas la v25 aplicada sobre una base sembrada con la v24 —la receta del §3
automatizada, sin desinstalar nada, gracias a que `BaseLocal.migrador` dejó de
ser `private`—; y la app corriendo: la fila de Ajustes, el PDF con logo, la
carta con logo y **el PDF SIN logo**, que es el caso que más se va a dar y sale
igual que antes, sin hueco reservado.

**Lo que NO está probado y hay que probar con sesión:** el viaje real a Storage
—subir, bajar en otro aparato y borrar el anterior al reemplazarlo—. En modo
revisión el almacén es un `Mock` y el archivo no sale del teléfono. Es lo
primero que hay que mirar en la próxima sesión con credenciales.

**El web no lo lleva todavía** (decisión de Iván, 7-sep): el esquema queda
puesto y lo adopta cuando toque. Mientras, un documento generado desde el web
sale sin logo.

### 0.0.e El PDF de las cartas y las actas

Salió de preguntar "¿qué más falta?" y mirar el código en vez de la lista de
pendientes. `PDFExport.render` se llamaba en cuatro sitios y **ninguno era de
Secretaría**: el botón de compartir de una carta era literalmente
`// Compartir — placeholder (requiere UIActivityViewController)`, habilitado en
cuanto la carta estaba completa, y el pie del formulario del acta prometía que
"el PDF incluye espacio de firma para la secretaria y el directivo". Se llenaba
una carta, se firmaba, se emitía con su folio del servidor — y no salía del
teléfono. Es lo más gordo que quedaba en el área que el §6 daba por cerrada.

**Lo que se hizo**, en `Tamio/Views/Components/SecretariaPDF.swift`:
`CartaHojaPDF`, `ActaHojaPDF`, `FirmaEnLinea` —la raya con la rúbrica encima,
que ahora comparten tres documentos— y `DocumentoPDFSheet`, la previa con el
botón de compartir. `ReportePDFSheet` y `ReporteAnualPDFSheet` son dos copias de
esa misma hoja escritas aparte; los nuevos no son la tercera y la cuarta.

**La previa de la carta ES ahora la hoja que se imprime.** Antes era una tarjeta
propia, con su membrete y su fecha: dos documentos distintos llamados igual, y
el que se veía no era el que se iba a entregar.

**Tres cosas que solo dijo verlo impreso:**

1. **La hoja salía estrecha y con TODO el texto cortado en "…".** Faltaba
   `.frame(width: PDFExport.anchoCarta)` en la raíz de cada hoja: es el contrato
   que documenta `HojaCartaEscalada` —"las hojas de los documentos llevan…"— y
   que cumplen las otras cuatro. Sin nadie que proponga un ancho, cada `Text` se
   mide a UNA línea. Y aun con el ancho puesto, los textos largos necesitan
   `.fixedSize(horizontal: false, vertical: true)` para envolver.
2. **El acta imprimía dos veces la lista de asistentes.** Se le había añadido
   una tabla con lugar, hora, quién preside, presentes y ausentes sin ver que
   `Acta.cuerpo` ya narra todo eso. Quedó una sola línea, la del quórum, que es
   lo único que el cuerpo no dice.
3. Lo primero que se probó —mover la marca de agua de `ZStack` a `overlay`— **no
   era la causa** de nada. Se dejó igualmente, porque una marca de agua no debe
   empujar el layout de la hoja, pero conviene saberlo: el fallo era el ancho.

**De paso, la fecha de la carta.** Estaba escrita a mano —`Text("20 de agosto de
2026")`— en la previa del detalle, y calculada como "hoy" en la hoja larga.
Ninguna de las dos es la que la carta dice llevar: el formulario recoge
`fechaEmision`. Ahora las dos usan `Fechas.diaLegibleLargo`, que nació aquí.

**Verificado** con tres pruebas unitarias (`pruebas/DocumentosPDFTests.swift`:
que el archivo se genera y pesa) y corriendo la app: el acta con su hoja
completa, la carta a medias con "BORRADOR" y SIN botón de compartir, y la carta
llena con el botón puesto.

**Lo que este trabajo deja al descubierto:** el logo que se metió en el membrete
de carta y acta (§0.0.d) hasta ahora solo se veía en pantalla, porque esos dos
documentos no llegaban a imprimirse. Ahora sale en los seis de verdad.

### 0.0.f Los traslados del informe, y la maqueta que sobraba

La tabla "Movimientos de membresía" del informe pintaba una columna de folio de
110 puntos **en blanco** y la iglesia vacía, en un documento que se comparte con
la junta. Los dos datos estaban en el aparato:

- **El folio y el destino** viven en `trasladoSalida`, y el repositorio los
  descartaba: filtraba por `enCurso` al leer, así que en cuanto el expediente se
  cerraba —que es justo cuando el traslado sale en el informe— sus datos no
  salían de esa función. Ahora se leen todos y **quién sigue abierto lo decide
  `Miembro.trasladoEnCurso`**, que se deriva en vez de guardarse aparte.
- **La iglesia de origen de una entrada** es `iglesiaAnterior`, el mismo campo
  que define `esRecibido`: quien esté en la lista lo tiene, y se estaba
  poniendo `""` teniéndolo al lado.

**Una entrada no tiene folio y no es un olvido**: el expediente lo abre y lo
numera la iglesia que ENVÍA. Se enseña "—", que es lo que la app usa para "no
hay".

**Dos cosas que aparecieron por el camino:**

- **La pastilla de sentido nunca acertaba.** La vista comparaba
  `t.tipoTraslado == L.t("Enviado", "Sent")` y el origen escribía "Salida": la
  condición era falsa siempre y las salidas salían del color de las entradas.
  Es el error que ya documentan `Catalogos` y `TipoActa` — comparar contra texto
  traducido no acierta ni en el idioma en que se escribió—, así que
  `MovimientoTraslado` lleva ahora un `Sentido` con clave.
- **`TrasladoEnCurso` pasó a llamarse `TrasladoDeSalida`.** El nombre dejó de
  ser cierto en cuanto hizo falta el expediente cerrado: son los mismos tres
  campos, y cuál se tiene delante lo dice la propiedad, no el tipo.

**Y 154 líneas de maqueta muerta fuera** de `InformesMembresiaViewModel`:
`resumenMes`, `resumenTrimestre`, `resumenRango`, `resumenTodo` y los tres
traslados de ejemplo (Javier, Daniel, Rosa). **Nadie los llamaba** —comprobado
símbolo por símbolo antes de tocar—, pero el comentario del archivo seguía
diciendo que "el General sigue leyendo `resumenMes`/`resumenAnio`", que ya no
era verdad, y este traspaso avisaba de no confundirlos con lo real. El aviso
sobra si la trampa no está.

**Cuidado al borrar por rangos**: el primer corte se llevó por delante
`csvExportString` y `textoInforme`, que sí se usan, porque el bloque muerto
tenía la sección de Exportación en medio. Compiló mal y se restauró; el segundo
corte fue símbolo a símbolo con las líneas comprobadas antes de borrar.

**El padrón de ejemplo trae ya los dos expedientes** —el abierto de Javier y el
cerrado de Rosa—, porque el comentario decía "vivirá en `traslados_salida`;
mientras, aquí no se ve", y sin ellos el modo revisión no podía enseñar ni la
pastilla de la ficha ni el folio del informe.

**Verificado** con tres pruebas nuevas (`pruebas/TrasladosDelInformeTests.swift`,
con un repositorio inyectado) y las **73 unitarias en verde**, más la tabla en
pantalla: "TS-2026-011 · Salida" en naranja y "— · Entrada" en verde, cada una
con su iglesia.

**Lo que sigue mal ahí y no se tocó:** las columnas de esa tabla son de ancho
fijo y suman 580 puntos, así que en el teléfono la fecha y el estado se quedan
fuera de la pantalla. Es anterior a esto y se nota más ahora que el folio tiene
contenido.

### 0.0.g Restaurar un respaldo, borrar y reiniciar

El pie de la Zona de riesgo lo decía: *"Borrar y reiniciar se encienden cuando
exista la restauración: hoy no habría a dónde volver"*. Ya existe.

**El obstáculo era abrir el `.zip`.** El paquete se comprime con
`NSFileCoordinator(.forUploading)` —el mecanismo del sistema para adjuntar una
carpeta en Mail—, y **descomprimir no tiene equivalente público en iOS**. Las
salidas eran tres: añadir una dependencia a un `.pbxproj` que se edita a mano
(§2.1), cambiar el formato a AppleArchive y perder que el respaldo se abra con
doble clic en cualquier ordenador, o leer el zip. `ZipLectura` lee el zip: unas
180 líneas, directorio central y `compression_decode_buffer` con
`COMPRESSION_ZLIB`, que en Apple significa deflate crudo — que es justo lo que
guarda un zip. Solo abre lo que la app misma escribe, y lo que no reconoce lo
dice en vez de devolver basura.

**La restauración NO sustituye el archivo `tamio.sqlite`**, que es lo primero
que uno piensa. Hay una `DatabaseQueue` abierta encima de él toda la vida de la
app —`BaseLocal.compartida.cola` es `let`— y cambiar el archivo por debajo de un
handle abierto es cómo se pierden las dos bases. Se hace con `ATTACH` y una
transacción: o entra todo, o el aparato se queda como estaba.

**Tabla por tabla y columna por columna, no `select *`.** Un respaldo de hace
dos versiones tiene menos columnas que la base de hoy, y copiar por posición
pondría el teléfono de una persona en su dirección. Se cruzan los nombres. Al
revés se rechaza: si el respaldo trae migraciones que esta app no conoce,
restaurar sería perder columnas sin decirlo.

**El fallo que se llevó media tarde**, y que enseña por qué las pruebas de esto
no son opcionales: el zip envuelve todo en una carpeta con su propio nombre
(`tamio-2026-09-07/`), así que `respaldo.json` no estaba en la raíz de lo
extraído. Y **no fallaba ruidosamente**: `DatabaseQueue` abre una base que no
existe creándola VACÍA, o sea que la restauración habría "funcionado" dejando el
aparato sin nada. Lo cazó la prueba que abre la base extraída y le pide las
tablas.

**Los otros dos botones** viven en `BorradoMasivo` y no son lo mismo:

- **Borrar los registros se PROPAGA**: marca cada fila como borrada y encola su
  baja, igual que borrar un movimiento a mano. La configuración se conserva.
- **El reinicio de fábrica es de ESTE aparato**: vacía base, carpetas y
  preferencias y cierra sesión. Lo del servidor sigue ahí y vuelve a bajar. Es
  lo que ya decía el texto del iPad ("Borrar datos de este iPad").

**El mapa tabla → entidad de sincronización** salió de leer qué encola cada
repositorio, no de suponerlo, y hay **dos pruebas que lo cuidan**: que ninguna
tabla con borrado lógico se quede fuera, y que el mapa no nombre tablas que ya
no existen. Escribir mal una sola deja filas borradas en el teléfono que el
siguiente `sync` vuelve a bajar — un fallo que no se ve al probarlo a mano, se
ve un minuto después.

**Verificado** con siete pruebas nuevas y las **80 unitarias en verde**: la ida
y vuelta entera (respaldar, estropear la base a propósito, restaurar), que
inspeccionar no toca nada, que un archivo cualquiera se rechaza con su motivo, y
que borrar da de baja Y encola. Y la pantalla, con las tres acciones vivas.

**Lo que NO está probado**: el flujo desde el selector de Archivos con un
paquete guardado de verdad —la prueba pasa la URL directamente— y la propagación
del borrado contra Supabase. Las dos piden un aparato con sesión.

**Y "Compactar base de datos" dejó de mentir** (`Compactacion.medir`). Decía
"La base ya está compacta" siempre, sin haber mirado. Ahora dice lo medido: lo
que ocupa la base —con su `-wal` y su `-shm`, que también son la base—, cuántos
registros borrados siguen guardados, cuántos recibos no reclama ningún depósito
y cuánto espacio tiene SQLite ya libre dentro del archivo.

**Solo mide, y la frase no promete limpiar**: hay una prueba que comprueba justo
eso, que el resumen no diga "recuperar" ni "se pueden quitar", porque cambiar una
frase falsa por otra no habría sido ganar nada.

Lo que la medición deja visto, y que decide el paso siguiente:

- **Nadie purga nunca.** No hay un solo borrado físico en la app, y la bajada
  guarda además las filas que el SERVIDOR marca como borradas: la base acumula
  lo que ya no existe aunque desde este aparato no se borre nada.
- **Purgar es seguro**, porque la bajada es incremental por cursor `updated_at`:
  lo purgado no vuelve salvo que cambie en el servidor.
- **La condición que lo hace seguro** ya está medida aparte (`filasPurgables`):
  solo se puede purgar lo que no tenga nada pendiente en la `outbox`. Borrar
  físicamente una baja que aún no ha viajado es la forma de que el servidor no
  se entere nunca.

**Las dos preguntas las contestó Iván el 7 de septiembre** —después de haber
descartado la purga y de volver sobre ella— y con eso quedó hecha:

- **El Registro NO se purga nunca.** Es la constancia de qué pasó con cada cosa,
  y sus apuntes son justo lo que hace falta cuando alguien pregunta meses
  después por algo que ya no está.
- **Solo lo borrado hace más de 30 días.** Es el margen para notar un borrado
  equivocado —hecho desde otro aparato, o el martes por la tarde— y deshacerlo
  mientras la fila todavía existe.

`Compactacion.purgar` aplica **tres condiciones y las tres importan**: la fila
está borrada, no tiene nada pendiente en la cola —purgar una baja sin subir es
la forma de que el servidor no se entere nunca— y lleva más de ese plazo. Al
final, un `VACUUM` fuera de transacción, que es lo único que devuelve el espacio
al sistema en vez de dejar las páginas libres dentro del archivo.

**La cuenta que se enseña es la que se borra**, y hay una prueba que lo sujeta:
si `medir()` y `purgar()` usaran criterios distintos, el número de la pantalla
sería una promesa incumplida. Por eso el resumen dice los dos —"132 registros
borrados siguen guardados (87 ya se pueden quitar)"— cuando no coinciden.

El botón solo aparece si hay algo que quitar. Con la base de revisión vacía no
sale, comprobado en el simulador.

### 0.0.h Tres frases que decían algo sin haberlo mirado

Las tres son del mismo tipo —texto escrito a mano donde tenía que haber un
dato— y por eso se cerraron juntas.

- **El subtítulo de Actas** decía "Acta 2026-08 en borrador" hubiera las actas
  que hubiera y en el estado que estuvieran: una iglesia sin ninguna a medias
  leía que tenía una, con el folio de otro año. Ahora lo cuenta
  `ActasViewModel.subtitulo`, y un borrador manda sobre el recuento porque es lo
  accionable.
- **"Guardado hace 2 minutos"** iba bajo cada borrador, tanto en uno recién
  tecleado como en uno de hace tres meses. El dato estaba en
  `acta.actualizadoEn` de la base y no llegaba al modelo. Ahora sube y se
  enseña relativo mientras es reciente y con fecha cuando ya no lo es: "hace 94
  días" no dice nada que "el 5 de junio" no diga mejor. **Sin fecha no se dice
  nada**, que es más honesto que una hora inventada.
- **El "Próximamente" de Reportes** anunciaba que "este reporte llega en un
  próximo slice" en una rama a la que solo se llega **mientras las cifras
  cargan** —los tipos son dos y los dos están hechos—, o cuando el año elegido
  no tiene datos. Ahora es un indicador de carga, y para el año vacío un "Sin
  datos para 2024" que dice dónde cambiarlo.

**La trampa al verificar el primero**, que vale para la próxima vez: el texto
calculado sale IDÉNTICO al que estaba escrito a mano —"Minutes 2026-08 in
draft"— porque el acta de ejemplo es justo la que le dio nombre. La pantalla se
ve igual antes y después, así que mirarla no prueba nada; lo que lo prueba son
las tres unitarias con listas distintas. La prueba de interfaz quedó apuntando a
lo único que sí se ve: que bajo el borrador ya no aparece la hora inventada.

Verificado con cinco pruebas nuevas y las **88 unitarias en verde**.

### 0.0.i La última pasada: cuatro promesas, cuatro decisiones distintas

Cuatro cosas del mismo tipo que se resolvieron de cuatro maneras, y esa es la
parte que vale la pena recordar: **no toda promesa incumplida se arregla
cumpliéndola.**

- **La purga de compactar: descartada** (decisión de Iván, 7-sep). Con eso el
  pie de la sección —"lo que se borra queda marcado hasta que se compacta"— pasó
  a prometer algo que no va a llegar, así que ahora dice lo que de verdad pasa:
  que lo borrado sigue ocupando sitio, **y por qué** — es lo que permite que la
  baja se propague. Y el título dejó de ser "Compactar base de datos", que
  nombraba un botón inexistente: la fila informa, así que se llama "Espacio en
  este aparato".
- **Ayuda y Acerca de: fuera.** No se rellenaron. Una ayuda necesita texto
  escrito por alguien que conozca a las iglesias que la van a leer, y un
  "Acerca de" no tiene nada que decir que no esté en la fila de la versión,
  justo encima. Dos filas que llevan meses sin llevar a ninguna parte enseñan
  que la pantalla no se mira, y eso contagia al resto.
- **La vista previa del membrete: hecha**, y no hacía falta inventar nada. Los
  documentos ya se arman con `LogoMembrete`, `FirmasPDF` y
  `PieInstitucionalPDF`; `MembreteHojaPDF` los pone juntos, así que la previa es
  literalmente lo que va a salir impreso. El cuerpo son cuatro rayas grises y no
  un texto de ejemplo **a propósito**: lo que esa pantalla configura es el
  marco, y una carta inventada invitaría a revisar la prosa en vez del membrete.
- **Los traslados en el teléfono: rehechos.** Aquí el diagnóstico de la mañana
  era impreciso: no es que la tabla se saliera de la pantalla, es que estaba
  dentro de un `ScrollView(.horizontal, showsIndicators: false)`. La fecha y el
  estado existían, pero fuera de la vista y sin nada que insinuara que se podía
  arrastrar — que para un informe que se enseña en una junta es lo mismo que no
  estar. En compacto ya no hay tabla: dos renglones por traslado con las cinco
  cosas. **En iPad la tabla se queda**, que allí caben las 580 puntos de
  columnas.

Verificado con las **89 unitarias en verde** y las cuatro pantallas corriendo,
iPad incluido — la cabecera FOLIO sigue existiendo allí, que es lo que dice que
no se perdió la tabla.

### 0.0.j La tarde en el aparato: lo que el simulador no podía decir

Iván instaló la app en su iPhone el 7 de septiembre por la tarde y en veinte
minutos salieron cinco cosas. **Ninguna era visible desde el Mac.**

**Lo gordo: `iglesias` no tenía política de UPDATE.** RLS activo y una sola
política, `leer_mi_iglesia`, de SELECT. Y esto es lo que lo hacía invisible: un
`update` que RLS filtra **no da error** — afecta a cero filas y devuelve 204—,
así que `subirIglesia` lo daba por bueno, borraba la operación de la cola, y la
siguiente bajada devolvía los valores viejos y pisaba lo editado. **Nada de lo
que se escribe en Ajustes · Iglesia se había guardado nunca desde iOS.** El
síntoma que lo destapó no fue el logo: fue Iván diciendo que **la moneda vuelve
a MXN cada vez que abre la app**. Sin ese dato yo habría seguido persiguiendo el
logo, que era el mismo fallo con otra cara.

Las huellas, para la próxima: `logo_path` en null y un `updated_at` congelado
semanas atrás. Cuando una columna no cambia NUNCA, la sospecha es el permiso, no
el código.

Arreglado en `20260907_iglesias_se_pueden_actualizar.sql` —política de UPDATE
más un trigger que congela id, plan, suscripción y los dos permisos del
tesorero—, **aplicada por Iván**: el clasificador bloquea las migraciones desde
la sesión. Y el cliente dejó de tragarse el silencio: la subida pide
`select("id")` y comprueba que tocó una fila.

**El logo, tres fallos más:**

1. **La ruta se guardaba 800 ms tarde**, con el temporizador que comparte con
   los treinta campos de texto de la pantalla. El logo no es un campo que se
   teclea: es un suceso único. En esa ventana, una sincronización releía la
   configuración sin la ruta.
2. **Y `sincronizar` borraba el archivo por una ruta vacía.** Vacía también
   significa "todavía no se ha guardado la que acabo de poner". Ahora solo borra
   si la iglesia no tiene nada pendiente de subir.
3. **El anterior no se borraba.** Estaba escrito en un comentario de `quitar` y
   no implementado en `poner`. Cuando se vio, ya había SEIS archivos de 1,6 MB
   en el bucket, así que la limpieza acabó barriendo la carpeta entera en vez de
   "el anterior": un borrado que solo mira la ruta que conoce no alcanza lo que
   ya se acumuló.

**Y el formato.** PNG por la transparencia es correcto para un logo recortado;
para una FOTO del carrete, que es lo que se elige la primera vez, son 1,6 MB que
se baja cada aparato de la iglesia. Ahora se mira si hay alfa de verdad y sin él
va JPEG al 90 %. El detector de alfa nació mal —partía de un lienzo opaco, así
que un píxel transparente no dejaba marca— y lo cazó su propia prueba.

**La medida del cifrado, por fin tomada** (§5): `tamio.sqlite` está en
**`completeUntilFirstUserAuthentication`**, el valor por defecto de iOS. Apagado
el teléfono, la base es ilegible; desde el primer desbloqueo tras encenderlo, la
clave queda disponible hasta el siguiente apagado. O sea: un iPhone robado
ENCENDIDO y bloqueado tiene la base al alcance de quien sepa extraerla.

**El borrado masivo y la restauración, probados contra el servidor de verdad.**
Borrar dio de baja 87 registros en el teléfono y dejó en CERO las diez tablas
sincronizables del servidor —transactions 27→0, members 10→0, y actas, agenda,
cartas, registro, depósitos, servicios, cortes y categorías—, sin una sola fila
descolgada: es lo que la prueba de cobertura del mapa tabla→entidad existía para
garantizar. Restaurar devolvió las cifras exactas de antes: $1,442,201.00, 28
movimientos, 22 sin depositar, 2 cortes. Y la hoja de confirmación enseñó lo que
se diseñó para que enseñara — "Iglesia principal · Sep 7, 2026 at 5:52 PM · 28
transactions, 10 contributors, 2 deposits".

**Pero restaurar no le decía nada al servidor**, y eso solo se ve con un
servidor al otro lado. El aparato quedó con sus 28 movimientos y el servidor con
los 66 marcados de baja, esperando a que la primera sincronización se los pisara
— o sea, la restauración se deshacía sola. Ahora `Respaldo.reencolar` deja una
subida por cada fila viva recuperada, y va como ACTUALIZACIÓN y no como alta:
el servidor conserva las filas con su `deleted` puesto, así que un update las
resucita, mientras que un alta le pediría al contador de Postgres un folio nuevo
y cada movimiento recuperado cambiaría de número.

**Y el último, que fue una palabra:** `TransaccionInsert` no llevaba la columna
`deleted`. El update de un movimiento mandaba sus veinte columnas menos esa, así
que una fila marcada de baja en el servidor seguía marcada después de
actualizarla. Se vio al recuperar: los aportantes, las actas, las cartas, los
servicios, los depósitos y los apuntes volvieron —sus escrituras sí mandan la
bandera— y los 66 movimientos se quedaron de baja. Un movimiento que se crea o
se corrige está vivo por definición; dar de baja es `eliminar`, que manda
`deleted: true` por su cuenta.

**El ciclo, cerrado y comprobado contra el servidor**: respaldar → borrar (87
registros, diez tablas a cero) → restaurar → sincronizar → las nueve tablas con
sus filas vivas otra vez, `transactions` incluida.

**Y de paso se explicó un desajuste que llevaba semanas**: el teléfono contaba 28
movimientos y el servidor 27. No faltaba ninguna fila —las 66 estaban en los dos
lados—: ese movimiento estaba marcado de baja en el servidor y vivo en el
teléfono, porque su update nunca le había quitado la marca. Al recuperarlo,
volvió a cuadrar.

**Lo que sí salió bien a la primera:** la migración v25 corrió sobre la base real
de un aparato con datos y no se llevó nada —la fila "Espacio en este aparato"
midió 336 KB y 76 registros borrados, y de haber caído a memoria se habría
quedado en "Midiendo…"—, y el respaldo se armó, se guardó en Archivos y trae sus
dos piezas (`respaldo.json` y un `tamio.sqlite` de 328 K).

### 0.0.a Los cinco sucesos de Tesorería

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

### 0.0.b Y después, lo que quedaba de Tesorería

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
3. ~~El `+` de Membresía podría volver a la barra.~~ **— HECHO el 7 de
   septiembre, lo pidió Iván**: el `+` arriba a la derecha, donde estaba la
   lupa, y la lupa al cajón, que se abre tirando hacia abajo, donde estaba la
   fila de "Nuevo miembro". Medido antes y después con la app corriendo:
   `Secretary · Search · Members (8) · More filters` pasa a `Secretary ·
   Members (8) · More filters · New`. Cuatro cápsulas las dos veces: no se cayó
   ninguna. **Y probado por Iván en el aparato**, que es donde cuenta: tirando
   hacia abajo sale la lupa.
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

## 0.1 El reparto entre sesiones (7-sep-2026)

**Esta sesión y las que sigan aquí van a lo de iOS.** El app web la lleva otra
conversación en paralelo, y Iván lo dijo expresamente al final de la tarde del 7
de septiembre.

**Cuidado con esto**, que es lo que puede morder: antes de saberlo, esta sesión
tocó el web y **empujó tres commits** a `claude/padron-secretaria` de
`Tamio-app` (`bb9892e`, `d497bea`, `8e58c90`): la sincronización de la
configuración de la iglesia, la migración local 52 —`churches.updated_at`— y la
fusión del primer encuentro. Quien esté trabajando allí debería traerlos antes
de seguir, o se encontrará una migración nueva y un `sync.ts` cambiado bajo los
pies.

Y al revés: **este repo también se mueve solo**. Mientras esta sesión trabajaba,
aparecieron veintidós commits de otra en `liquid-glass`, uno de los cuales
—`d13d775`, el contador de campos de la carta— dejó `CartaNaceVaciaTests` en
rojo durante una hora sin que nadie se enterara. Conviene mirar `git log` antes
de dar por bueno el estado de la rama.

---

## 1. Dónde está el trabajo

Rama viva: **`liquid-glass`**, sincronizada con `origin/liquid-glass`.

**`main` está al día en `46dd4fe`**, adelantada por avance rápido el 7 de
septiembre por la tarde (veintinueve commits desde `3ffc483`). Se había quedado
atrás en `4a571ff` a propósito mientras las cuatro migraciones nuevas (v18–v21)
y las cuatro entidades de sincronización estaban sin probar contra la red; se
probaron con la cuenta real, así que el motivo se acabó. **Repetirlo cuando lo
de `liquid-glass` esté probado**, no antes: es lo que evita que combinarlas se
convierta en un problema.

**Sobre el push, que aquí decía que lo tenía que correr Iván a mano:** se corrió
desde la sesión y salió a la primera, pero con un matiz que conviene saber. Un
`git push origin HEAD:main` **suelto, y pedido por Iván**, pasa. El mismo push
**encadenado detrás de un `git commit`** lo bloqueó el clasificador de modo
automático. Así que se puede hacer desde aquí; lo que no se puede es colarlo al
final de otra cosa — que es justo la distinción que tiene sentido: publicar es
una orden, no un paso más del trabajo.

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
- **`swipeDown()` sobre una fila se interpreta como un TOQUE** y abre la ficha,
  así que no sirve para probar el cajón de la lupa. Hay que arrastrar por
  coordenadas y despacio: `coordinate(...).press(forDuration: 0.2, thenDragTo:)`.
  Ver `pruebas/BarraMembresiaUITests.swift`.
- El tipo de target de XcodeGen es `bundle.unit-test`, **no** `bundle.unit-testing`
  (ese es el de UI). Y hay que declarar un `schemes:` con los targets de test,
  o `xcodebuild` contesta que "isn't a member of the specified test plan".
- **A la copia hay que cambiarle el `PRODUCT_BUNDLE_IDENTIFIER`**
  (`church.tamio.pruebas`). Con el de la app real comparte contenedor con la app
  instalada: el anfitrión de las pruebas arranca la app, esta sincroniza, y los
  datos de la iglesia aparecen en mitad de una prueba que sembró los suyos
  —seis fallos el 7 de septiembre, todos por filas que nadie había sembrado—.

- **PERO el id propio NO aísla la sesión.** Aquí decía que "con id propio, las
  pruebas no pueden tocar la base de la iglesia ni aunque se equivoquen", y es
  **falso**. Comprobado el 7 de septiembre por la noche: la app de la copia
  arrancó **autenticada y con los datos reales de la iglesia** —28 movimientos,
  27 aportantes— sin que nadie escribiera una contraseña.

  El motivo es que `supabase-swift` guarda la sesión en el **Keychain**
  (`KeychainLocalStorage`, servicio `supabase.gotrue.swift`, sin grupo de
  acceso), y **en el simulador el llavero es común a todas las apps**. El
  bundle id separa el CONTENEDOR —la base local, `UserDefaults`— pero no el
  llavero. Así que la copia hereda la sesión que dejó la app real.

  Lo que eso provocó: correr la suite unitaria con el modo revisión APAGADO
  dejó dos operaciones en la cola de salida intentando subir miembros de
  maqueta (`m1` "María Hernández", `m2` "Ana Torres") a `members` de verdad.
  Fallaron con `duplicate key value violates unique constraint "members_pkey"`,
  o sea que no crearon nada — **pero fallaron porque esos ids YA ESTÁN en la
  base de la iglesia**, puestos por alguna corrida anterior.

  **La regla, entonces:** las pruebas de la copia se corren con el **modo
  revisión ENCENDIDO**, o en un **simulador propio y limpio** creado para eso
  (`xcrun simctl create`). Un simulador que alguna vez tuvo sesión de la app
  real la sigue teniendo aunque se desinstale la app: el llavero no se va con
  el contenedor.

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

- **El folio de un documento lo da el repositorio, no la pantalla.** El de las
  cartas se calculaba en `CartasViewModel`, contando de la lista que tuviera
  cargada —que puede estar filtrada o a medio cargar— y con OTRO formato:
  escribía `2026-014` mientras el escritorio emitía `CAR-2026-0014`. La misma
  iglesia llevaba dos series de folios, y la del teléfono no veía las cartas del
  escritorio, así que contaba solo las suyas.

  Ahora es el formato del web (`nextFolio` en su `db.ts`: prefijo, año y cuatro
  dígitos) y se cuenta contra la base entera, **borradas incluidas** —ese número
  se emitió y está citado en algún papel—. Comprobado sobre los datos de la
  iglesia: con `CAR-2026-0001…0005` dentro, el siguiente sale `CAR-2026-0006`.

  **Y desde el 7 de septiembre el número lo da el SERVIDOR** —migración
  `20260907_folios_por_serie_y_anio`—, que es lo único que hace imposible
  repetirlo: entregar y reservar son un solo statement. Mientras el documento no
  ha subido lleva un folio provisional marcado con "P-", como los movimientos, y
  por eso no se imprime hasta sincronizar. **Las dos apps a la vez**: iOS canjea
  al subir (`canjearFolio`), el web pide al insertar y cae al conteo local sin
  red, donde su `repararFoliosDuplicados` sigue cubriendo.

  Dos detalles que costaron una vuelta: el folio se guarda ANTES de subir —si la
  subida falla, el reintento no pide otro número; gastar un folio es barato,
  repetirlo no— y **los provisionales cuentan para el siguiente provisional**,
  que si no dos borradores sin subir salen los dos "P-1".

- **Un formulario no nace con datos dentro.** `CartaEnEdicion` traía cuatro
  valores de maqueta escritos —"Javier Medina Cruz", "Iglesia El Buen Pastor",
  "2018", "Pastor Abel Ramos"— y son exactamente los que cuenta
  `camposCompletos`: la comprobación de "faltan campos por completar" se cumplía
  sola y se podía **firmar y emitir una carta sin escribir nada**, a nombre de
  alguien que no existe. Pasó tres veces en la iglesia de verdad el 7 de
  septiembre, y se destapó mirando el Registro.

  **Cómo se encuentra el siguiente:** un apunte con un nombre que no está en el
  padrón. Y la regla: proponer un dato de la IGLESIA (el pastor de Ajustes) es
  ayudar; inventar una persona es otra cosa.

- **El teléfono no gira: solo vertical.** En apaisado, un iPhone grande pasa a
  clase de tamaño **regular**, y toda la app decide su forma con
  `sizeClass == .compact`: girar el teléfono daba las dos columnas y la sidebar,
  o sea la app del iPad en un teléfono. Lo señaló Iván —"parece iPad"—. El iPad
  conserva las cuatro orientaciones, que ahí las dos columnas son la pantalla y
  no un accidente.

  Va en `INFOPLIST_KEY_UISupportedInterfaceOrientations` (la clave SIN sufijo es
  la del teléfono; `_iPad` manda en el iPad). **Se toca en los dos sitios**: el
  `.pbxproj`, que es el que compila, y el `project.yml`, que no se regenera
  nunca (§2.1) pero es lo que alguien leerá para entender el proyecto. Medido
  girando el simulador con `XCUIDevice.shared.orientation`: la ventana se queda
  en 390×844 (`pruebas/OrientacionUITests.swift`).

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

### Recurrentes — PROBADOS por Iván el 7 de septiembre

Cuatro commits del 4 de septiembre: modelo (`MovimientoRecurrente`, tabla
propia, **v14** local + `movimientos_recurrentes` en Supabase),
materializador, sincronización e interfaz.

**Lo que falta comprobar, y solo se ve con dos aparatos reales:**

- Que la migración **v14** corre sobre una base que ya tiene datos.
- Que la definición sube y baja de Supabase.
- **La idempotencia entre aparatos**: que al cerrar el mes la renta se genera
  UNA vez y no una por aparato. La marca `ultimoMesGenerado` la puede mover
  otro aparato; por eso la definición baja ANTES de materializar.

**Probado en el aparato y sale bien** (Iván, 7-sep-2026). Era el único riesgo
real que quedaba: código escrito entero que crea movimientos solo y que nunca
había corrido fuera del Mac.

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

**Atención al cambio de estado (7-sep-2026):** la condición de la opción B —"que
exista restaurar"— **se cumplió esta tarde** (§0.0.g). Lo que bloquea ahora no
es la restauración: son las dos medidas, y las dos piden un iPad de verdad.
Conviene releer la recomendación con eso delante antes de decidir, porque fue
escrita cuando restaurar era la parte imposible.

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

**El año de un aporte, la misma piedra — 7 de septiembre.** `aportes(anio:)`
leía el año con `Calendar.current` sobre una fecha guardada como texto y
parseada a medianoche UTC: en Monterrey, un aporte del 1 de enero contaba en el
año anterior **y su importe se iba de la constancia de ese año**, que es un
documento que se firma. La cuenta estaba escrita CUATRO veces —dos en el modelo
y dos en la pantalla que imprime la constancia—, y el periodo "Año" del PDF
además arrancaba el 1 de enero LOCAL, así que dejaba fuera el mismo aporte por
el otro lado.

Ahora hay un solo sitio, `Fechas.anio(de:)` y `Fechas.inicioDeAnio(_:)`, y la
pantalla usa las funciones del modelo en vez de repetirlas. **Regla:** el
calendario local es el correcto para "hoy" —quien mira vive en su zona— y el de
UTC para una fecha GUARDADA. Son dos preguntas distintas y no llevan el mismo
reloj. Prueba en `pruebas/AnioDeUnAporteTests.swift`, que se salta sola al este
de Greenwich porque allí no probaría nada.


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

**Probado:** diez pruebas nuevas (`InicioCalculadoTests`), 28 en total en verde,
**y en el simulador con la cuenta real**: Inicio enseña las cifras de la iglesia
y el selector de aportante ofrece el padrón del teléfono (foto en la sesión).

**Y ahí salió lo que ninguna prueba podía ver.** En un teléfono recién estrenado
la base local está vacía, el arranque lanza la sincronización, y la pantalla se
dibuja mientras los datos bajan: Inicio leía la base UNA vez, con `.task`, y se
quedaba en ceros hasta que alguien tiraba hacia abajo. Dos arranques seguidos
daban pantallas distintas según quién terminara antes. Mientras Inicio fue una
maqueta no podía pasar; aparece justo al enchufarlo.

El arreglo va en `sincronizable` —las catorce pantallas con ese gesto tienen el
mismo problema—: además del tirón, recargan cuando el motor termina una
sincronización, escuchando `ultimaSincronizacion`, que ya se publicaba.

**La receta de la prueba de interfaz** quedó en `pruebas/`: un target
`bundle.ui-testing` en la copia, imprimir `app.buttons...map(\.label)` para
saber cómo se llaman las cosas, y una marca en el log + `simctl io screenshot`
desde el shell para fotografiar un estado transitorio (§3).

**Y el rastro, de punta a punta.** Con permiso de Iván se capturó un ingreso de
$1.00 y se dio de baja deslizando en la lista: el Registro lo anotó solo, en
rojo y bajo el filtro de Tesorería —*"Transaction «PRUEBA Claude · borrar» for
$1.00 MXN was deleted (folio 6)"*, con su autor y su hora—. **La frase salió en
inglés** porque el aparato está en inglés, que es la razón de ser de esta tabla:
se guardan las piezas y se compone al leer.

Dos cosas que solo se ven ahí: el folio del apunte es el DEFINITIVO ("folio 6")
y no el provisional que enseñaba la lista, porque el movimiento ya había subido
antes de borrarlo; y las cartas emitidas hace unas horas —escritas con la clave
vieja `nombre`— **se leen enteras**, que es justo para lo que se dejó la lectura
con dos claves.

**Sin verificar:** el selector de aportante con el aparato en avión. El camino no
toca la red y la prueba unitaria lo cubre, pero no se ejercitó sin señal.

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

### El idioma de prueba: qué manda y qué cambió

Quien manda el idioma de la INTERFAZ es `PreferenciasApp.idiomaGuardado`, en
`UserDefaults` bajo **`prefs.idioma`**. En una prueba se pasa como argumento:
`app.launchArguments += ["-prefs.idioma", "espanol"]`.

**Lo que decía aquí antes ya NO es cierto** y conviene saber por qué. Decía que
`-AppleLanguages (es)` no hacía nada porque la app no tenía `es.lproj` y
`Locale.current` caía a inglés. Dos cosas cambiaron el 8 de septiembre:

1. El caso "Automático" pasó a mirar `Locale.preferredLanguages` —la lista del
   APARATO— en vez de `Locale.current`, así que `-AppleLanguages (es-MX)` sí
   mueve la app.
2. Y ahora existen `en.lproj` y `es.lproj` de verdad, con los textos de los
   permisos. `Locale.current` ya resuelve a español en un aparato en español.

Eso último arregla de paso `L.locale`: comparaba contra `Locale.current`, que
siempre daba inglés, así que en español devolvía un `Locale(identifier: "es")`
genérico y **perdía la región**. Ahora conserva `es_MX`, que es lo que su
propio comentario decía querer. Comprobado con la app corriendo en es-MX:
"Martes 8 de septiembre" y los meses del gráfico en español.

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

**4.** ~~Los cuatro de acabado de Secretaría.~~ **— HECHOS el 7 de
septiembre**, y uno de ellos resultó ser otra cosa (ver debajo de la lista):

- ~~"Próximos" en Servicios incluye cultos pasados.~~ **El rótulo era el
  equivocado, no el filtro.** La lista es la bitácora entera del más reciente al
  más antiguo, que es como la enseña el web —"historial completo"— y como debe
  ser: un registro de servicios es sobre todo lo que YA pasó, con su asistencia
  y quién predicó. Se rotula igual que allí, y el método del repositorio deja de
  llamarse `proximos()`, que era el nombre que mentía.
- **El selector de "Tipo de carta": SON DOS, no cinco.** Este pendiente estaba
  mal escrito y se comprobó contra el web el 7 de septiembre. Hay que mirar DOS
  listas distintas de `Tamio-app`, no una:

  - `TIPOS_CARTA` (`components/CartaEditor.tsx`) son los **14 tipos que el web
    ofrece y sabe dibujar**, e incluye `autorizacion`, `solicitud` y
    `reconocimiento` — o sea que esos tres NO son problema.
  - `TIPOS_INICIALES` (`services/cartas/plantillas.ts`) son las **11 plantillas
    sembradas**, que es otra cosa: un tipo puede existir sin plantilla.

  iOS ofrece 16. Los únicos que el web no conoce son **`bautismo` y
  `bienvenida`**, los dos marcados "legacy — kept for existing mock data" en
  `TipoPlantilla`. Una carta de esos tipos se lee en el web como la clave cruda
  (`cartas.tipoDoc.bautismo`) y no sale en su selector. **Pendiente de decisión
  de Iván**: o se añaden al web, o se quitan de iOS.
- ~~El responsable de una actividad se guarda como texto.~~ **Y era peor de lo
  escrito**: en el web las dos columnas son EXCLUYENTES —si el responsable es
  del padrón guarda el id y deja el texto en nulo—, así que una actividad creada
  en el escritorio llegaba al teléfono **sin responsable ninguno**. La columna
  local `miembroId` y el `member_uid` de la sincronización ya existían: solo
  faltaba que el formulario guardara el id y que la lectura resolviera el
  nombre. Ahora el nombre se lee del padrón, así que quien cambie de apellido no
  deja actividades hablando de quien ya no se llama así.
- ~~En Actas y Servicios el estado sale dos veces.~~ Fuera del subtítulo, que
  es donde sobraba: la pastilla lo dice a dos centímetros. Queda lo que la
  pastilla NO dice —la fecha, y en un acta cuántos acuerdos salieron—.

**Queda el quinto, que no estaba en la lista:** el selector de "Tipo de carta"
ofrecía dos que el web no conocía (`bautismo`, `bienvenida`). **Se añadieron al
web** el 7 de septiembre a petición de Iván (`Tamio-app`, `790a95f`), así que
iOS no cambia. Sin plantilla sembrada: la siembra solo corre en una iglesia sin
ninguna, y el texto de una constancia de bautismo lo escribe la iglesia.

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
- ~~Los cuatro de acabado —"Próximos" en Servicios, los tipos de carta, el
  responsable de una actividad y el estado repetido—.~~ **HECHOS el 7 de
  septiembre**, y dos no eran lo que decían. El detalle, en el §6, punto 4: esa
  es la lista que hay que mirar, esta solo la repetía.

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

1. ~~El mes es invisible en Ingresos.~~ **— HECHO el 7 de septiembre**, y no
   como decía este pendiente. Lo del contador se hizo —el periodo cuenta cuando
   NO es el mes en curso, incluido "todos los meses"—, pero teñir el botón dice
   que hay algo puesto y no QUÉ. Escribir el mes al lado del icono **no cabe**:
   el grupo comparte cápsula con el `+` y el sistema se comió el texto sin
   avisar, medido con la app corriendo. El mes va ahora en el encabezado de cada
   día —"DOMINGO 6 SEP", "LUNES 31 AGO"—, que es donde el ojo ya está y donde
   además se ve la mezcla con "todos los meses" puesto.
2. **El total de Movimientos en iPad** ya solo vive en la hoja de filtros. Allí
   el pie no causaba ninguno de los tres problemas del teléfono.
3. ~~Verificar los recurrentes en aparato.~~ **— PROBADOS por Iván el 7 de
   septiembre y salen bien.** Era el riesgo real que quedaba: código escrito
   entero, que crea movimientos solo, y que nunca había corrido fuera del Mac.
4. **Las dos medidas del cifrado** (§5). Siguen pendientes y piden un iPad; lo
   que ya NO las bloquea es la restauración, que existe desde el 7 de
   septiembre por la tarde.
5. ~~Probar la sincronización con la cuenta real.~~ **— HECHO el 6 y el 7 de
   septiembre**, en las dos direcciones y con las entidades nuevas. Ver §5, "La
   subida SÍ funciona", y el §0.
6. ~~Los servicios: el resto de la ficha se guarda y no se ve.~~ **— HECHO el
   7 de septiembre.** La ficha enseña ya el mensaje, el conteo por grupo, la
   escuela bíblica, las canciones, los visitantes y los eventos especiales. Cada
   tarjeta aparece solo si tiene algo dentro, **y las tres viejas también**:
   ROSTER, ASISTENCIA y ORDEN DEL CULTO salían con el título y el hueco, así que
   un culto recién creado enseñaba tres cajas vacías seguidas y parecía una
   pantalla a medio cargar.
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
9. ~~Reflejar `traslados_salida`.~~ **— HECHO el 7 de septiembre.** Tabla
   local `trasladoSalida` (**v23**), bajada en el motor y pastilla naranja
   junto al estado, en la lista y en la ficha. **Solo BAJA**, como las
   plantillas: el expediente se abre, se aprueba y se firma en el escritorio
   —folio propio, carta enganchada, historial de estados—, y aquí sirve para
   una sola cosa que no se decide en el teléfono.

   La regla de "en curso" es la del web (`memberTieneTrasladoActivo`):
   cualquier estado que no sea `completado` ni `cancelado`. Y la pastilla va
   JUNTO al estado, no en su lugar: la persona sigue activa mientras dura.

   **La v23 se probó sobre la base que ya existía** —la del simulador, con la
   cuenta real y datos de v22—: la migración entró, la tabla se creó y no se
   perdió una fila. `traslados_salida` sigue vacía en Supabase, así que la
   pastilla se vio sembrando una fila LOCAL (esta entidad no sube, así que no
   podía escaparse), y se borró después.

11. ~~El informe General sigue escrito a mano.~~ **— HECHO el 7 de
   septiembre**: se calcula del padrón.

12. ~~El informe de Seguimiento promete tres alertas y enseña "Próximamente".~~
   **— HECHO el 7 de septiembre**: refleja `alertasSeguimiento` del web con sus
   cuatro tipos, y el badge cuenta las de verdad.

13 y 14. **"Próximos" en Servicios incluye el pasado** y **el estado sale dos
   veces en Actas y Servicios**. Siguen abiertos y son dos de los cuatro de
   acabado de Secretaría: están arriba, en "LO SIGUIENTE", punto 4, que es la
   lista que hay que mirar.
10. Observación sin acción: el hub dice "Transacciones · 29 registros" y la
   lista dice "16 movimientos". No es un error —una suma ingresos y gastos, la
   otra solo el tipo activo— pero se leen como el mismo número.

### Lo que dejó abierto la pasada del iPad (§0.0) — cerrado

Los tres se cerraron el mismo día. **El de la tabla del informe lo arregló la
otra sesión** (`de542b1`): las dos lo hicimos a la vez, en el mismo archivo y
casi con el mismo diseño, y el mío se cayó al reposar la rama — es la tercera
vez que pasa en el día. Con dos sesiones sobre la misma rama conviene mirar
`git log` de la otra antes de empezar un punto, no solo al fusionar.

De B5 vale la pena guardar cómo se resolvió:

**B5 no era una decisión, era un recuento.** El pendiente decía que antes de
tocar las píldoras hacía falta decidir un criterio para toda la app, y planteaba
dos posibles. Contarlas lo resolvió sin decidir nada: de las **veintiséis**
píldoras, **veintitrés empiezan en mayúscula** y las tres únicas excepciones son
las de `EstadoRoster`, sin nada que documente por qué y usadas en un solo sitio.
El criterio ya estaba en la app; solo faltaba mirarlo. Cuando un pendiente pida
"decidir un criterio", **contar primero**: puede que el criterio exista y lo que
haya sea una excepción.

---

## 6.b Lo que solo puede hacer Iván · con el aparato o la cuenta en la mano

Lista escrita el **8 de septiembre de 2026** a petición suya. No es trabajo de
código: es todo lo que ninguna sesión puede cerrar desde el Mac porque pide un
iPhone o un iPad de verdad, una cuenta, el panel de Supabase, o que pase el
tiempo. Va aparte del §6 justamente para no mezclarla con lo que sí se programa.

Cada punto dice **qué hacer**, **qué mirar** y **cómo saber que salió bien**.

### A. Entrar con la cuenta y usar la app un rato — LO MÁS IMPORTANTE

Es lo primero de todo, y no por costumbre: el 8 de septiembre se reescribieron
**las once subidas** del motor (§0.-4). Compilan y las 143 pruebas pasan, pero
las pruebas no tocan la red: **el camino por el que sube TODO cambió y nunca ha
hablado con el servidor**.

- **Qué hacer:** entrar con la cuenta real y hacer una de cada: crear un
  movimiento, editar un miembro, cerrar un acta, emitir una carta, pasar lista
  en un culto, hacer un corte.
- **Qué mirar:** Ajustes · Sincronización. Después de cada cosa, **"Sin subir"
  tiene que volver a 0**.
- **Cómo saber que salió mal:** si el estado deja de decir la fecha y pasa a
  decir *"N cambios no pudieron subir: …"*, eso es lo nuevo funcionando —está
  avisando, que antes no lo hacía—. **Apunta el texto entero del error**: ahí
  está el nombre de la tabla y el id, y es todo lo que hace falta para
  arreglarlo.
- **Y lo contrario también importa:** si algo que escribiste en el teléfono
  reaparece con el valor viejo después de sincronizar, es el bug que se
  arregló volviendo por otro sitio. Dilo aunque parezca una tontería.

### B. La clase de protección de los archivos — pide un iPad DE VERDAD

El simulador **no implementa Data Protection**, así que desde el Mac esto no se
puede medir. Es lo que bloquea la decisión del cifrado local
(`docs/CIFRADO-LOCAL.md`).

- **Qué hacer:** abrir la app en el iPad, ir a **Ajustes · Zona de riesgo**.
- **Qué mirar:** el renglón de la protección de archivos.
- **Bien:** dice *"Completa salvo si ya estaba abierto"*.
- **Falta además:** qué protección le queda al respaldo una vez guardado en
  iCloud Drive. Con esas dos medidas ya se puede decidir el cifrado; sin ellas,
  no.

### C. El respaldo con contraseña, en el aparato

Hoy solo está probado con pruebas unitarias, nunca a mano.

- **Qué hacer:** crear un respaldo con contraseña, sacarlo del aparato,
  **borrar todo** desde la Zona de riesgo, y restaurarlo.
- **Qué mirar:** que vuelva el padrón entero, los movimientos y los folios.
- **Bien:** el número de miembros y de movimientos es el mismo que antes de
  borrar. Si algo no vuelve, **anota qué**: no es lo mismo perder las notas de
  seguimiento que perder un corte.

### D. Borrar la cuenta — CON UNA CUENTA DE USAR Y TIRAR

**Este camino no se ha ejecutado nunca.** Es destructivo y en cascada.

- **Qué hacer:** crear una cuenta nueva de prueba, con su iglesia, y probar
  **las dos ramas**:
  1. Iglesia con más miembros → al borrarte, **la iglesia sobrevive**.
  2. Siendo el único miembro → **la iglesia se borra entera**.
- **Nunca con tu cuenta real.** No hay deshacer.

### E. Encender la comprobación de contraseñas filtradas — panel, 30 segundos

Es lo único que queda del endurecimiento previo a publicar, y no es SQL.

- **Dónde:** panel de Supabase → **Authentication › Policies** → *"Leaked
  password protection"*.
- **Qué hace:** contrasta la contraseña contra HaveIBeenPwned.
- **Comprobado el 8-sep: sigue APAGADA.** Para una app que guarda la
  contabilidad de una congregación es gratis y evita el caso más común de
  cuenta comprometida.

### F. La purga — no es trabajo, es esperar

El botón **no aparece** hasta que haya algo borrado de hace más de 30 días. No
hay nada que hacer hasta entonces; solo no darlo por roto cuando no se vea.

### G. Los recurrentes, cada cambio de mes

Ya los probaste el 7 de septiembre y salieron bien. Lo que conviene mirar es el
**primer arranque de un mes nuevo**: es cuando se materializan solos, y si la
app pasó meses cerrada se ponen todos al día de una vez. Que no salgan
duplicados entre el iPhone y el iPad es lo que hay que confirmar.

---

## 7. Cómo se escribe aquí

Los mensajes de commit son **frases que cuentan el problema**, no resúmenes del
cambio: *"El interruptor decía que se repetía y el mes siguiente no aparecía
nada"*. El cuerpo explica el porqué, lo que se descartó y con qué medida se
decidió. Los comentarios del código siguen el mismo criterio: dicen por qué
está así, no qué hace.

Los números se miden, no se estiman. Cuando un comentario dice "medido en
pantalla", es que se midió de verdad.
