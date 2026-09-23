# Auditoría del Mac contra `handoff7` · 21 de septiembre de 2026

> **Puesta al día el 22 de septiembre de 2026, por la noche.** La pasada del
> 21-sep se quedó vieja el mismo día. Esta vuelve a mirar **cada entrada que
> daba por ausente o distinta**, una por una, contra el código de `TamioMac/` y
> las carpetas compartidas que compila —`Tamio/Models`, `Data`, `ViewModels`,
> `Support`—, en `d0f68d7` más lo que había sin commitear en el árbol esa noche
> (entre otros, `TamioMac/NuevaCarta.swift`).
>
> **Cómo se comprobó.** Cada rótulo se buscó **en las dos lenguas**, porque se
> escriben con `L.t("es", "en")`, y cada hallazgo se leyó en su archivo: que el
> texto esté no basta, tiene que llamarlo alguien. Aparte, una pasada mecánica
> sobre el HTML de `handoff7` (la copia de las 19:11 del 21-sep, la que trae la
> pantalla de acceso): los **149 textos fijos** del marcado y las etiquetas de
> las hojas y las listas de su JavaScript, buscados en todo ese código. De los
> 28 textos del marcado que no aparecen, 12 son datos de su maqueta; el resto
> está abajo, uno por uno. **Nada se da por ausente sin haberlo mirado.** No se
> compiló ni se abrió la app: esto es lectura de código, no pantalla.

Los handoffs 5, 6 y 7 llegaron la misma tarde. El quinto trajo **las hojas
modales** —que los cuatro anteriores no dibujaban—, el sexto **Cartas** y los
campos que faltaban en Actas, y el séptimo cerró la lista de
`LO-QUE-EL-HANDOFF-NO-TRAE.md`: acceso, edición, seguimiento y el Registro.

## Cómo se mide

Se extraen los rótulos visibles de cada bloque de pantalla del HTML del handoff
—quitando los datos de su maqueta: cifras, meses y los nombres de su iglesia
ficticia— y se busca cada uno en todo el código que compila el Mac. Lo que no
aparece es lo que falta. **No prueba que lo que sí aparece esté bien colocado**,
pero encuentra lo ausente sin depender de la vista.

**Y da falsos negativos que hay que cazar a mano**, que es lo que le pasó a la
primera pasada: un rótulo con algo interpolado —"Require \(biometría) to open",
"Unlock with \(biometría)"— no casa con el literal del handoff; uno escrito con
otra palabra —"WHAT WAS STORED" por "WHAT WAS SAVED", ya igualada el 22-sep— tampoco; y uno en otra
caja —la columna "Balance" del resumen por meses, que el handoff pinta en
mayúsculas— se pierde si se busca con mayúsculas. Por eso cada ausencia se mira
en su archivo antes de escribirse aquí.

## Estado

**Las hojas están todas.** Miembro —alta y edición—, pariente, seguimiento,
acta, actividad, carta, culto y asistencia, sobre la forma común `HojaMac`, y la
nota a mano del Registro (`TablaRegistro.swift:181`). Sus rótulos **no son
palabra por palabra los del handoff** —"Ministries they serve in" por
"Ministries served", "Previous church" por "Previous church (if applicable)"—,
pero los campos están; eso no se cuenta como falta.

**Los atajos son los del handoff**: ⌥⌘N contextual y nunca apagado, ⇧⌘M, ⌘K,
⌘1…⌘9 y ⌘0. La carta va con ⇧⌘T (`ComandosTamio.swift:65`) y no con el ⇧⌘L
que el handoff declara dos veces.

**Sin diferencias: Inicio, Membresía, Agenda y Configuración.** Las tres
primeras, vueltas a medir: lo único suyo que no aparece en el código son datos
de la maqueta —"Good morning, Iván", "19 records", "▲ 4.2% vs August"—.
Configuración, **desde el 21-sep por la noche**: la primera pasada la dio por
completa cuando le faltaban siete de sus ocho secciones —seguridad, cerrar
sesión y borrar la cuenta; el logo; la previa del membrete; las firmas; invitar
y sincronizar; el porcentaje de las categorías; y la zona de riesgo entera—.
Comprobadas las ocho en `PantallaConfiguracion.swift`: el candado (:306), cerrar
sesión y borrar la cuenta (:319, :331), el logo (:406), la previa (:589), las
firmas (:630), invitar (:668) y sincronizar (:701), el porcentaje (:480), y el
respaldo, los CSV, compactar, restaurar y borrar este Mac (:821–:865). Lo que
se dejó fuera a propósito, al final de este documento.

Y en Tesorería, las cuatro tablas —Ingresos, Gastos, Aportantes y Depósitos—
coinciden **columna por columna y en el mismo orden**.

### Lo que la primera pasada daba por ausente, mirado otra vez

De sus **21 rótulos, 14 estaban hechos**. La tabla se midió antes de que se
escribieran el panel de la carta y el de Reportes, y además con los tres falsos
negativos de arriba.

| Pantalla | Rótulo del handoff | Hoy | Dónde |
|---|---|---|---|
| **Cartas** | `FOLIO` | ✓ hecho | `PantallaCartas.swift:323`, en la tabla de traslados |
| | `VARIABLES` · `RESOLVED` | ✓ hecho | `:253` · `:264` |
| | "Write a letter from this template" | ✓ hecho | `:276` |
| | "Draft with folio …" | ✓ hecho | `:448`, en `bandaDeBorrador` |
| | "Issue the letter…" | ✓ hecho, **y emite la misma fila** | `:456` |
| | `INTERNAL NOTES` · "Not printed on the letter." | ✓ hecho | `:468` · `:475`, en `notasInternas` |
| | Las tres subpestañas | ✓ hecho | `:26`–`:32` — Emitidas, Plantillas, Traslados |
| **Reportes** | `ON-SCREEN SUMMARY` · "Not included in the PDF" | ✓ hecho | `PantallaReportes.swift:266` · `:271` |
| | `PERIOD DEPOSITS` | ✓ hecho | `:314` |
| | `BALANCE` | ✓ hecho | `:371`, la columna del resumen por meses, en caja normal |
| | `PERIOD BALANCE` | ✗ **falta** | el panel de balance por mes, con sus barras. Iría en `cuerpoMensual`, junto a los dos de categorías (`:305`–`:311`) |
| | "Share" | ✗ **falta** | no hay `ShareLink` ni `NSSharingService` en todo `TamioMac/`. Iría en la cabecera, al lado de "PDF preview" (`:158`) |
| **Por revisar** | "Approve all safe" · "Ask for data" | ✗ **ausentes a propósito** | `PantallaRevisar.swift:119` lo dice: mueven el estado de revisión de un apunte de dinero y no están escritas. Un botón que no hace nada, ahí, promete una decisión que no se toma. |
| **Servicios** | El vacío de visitantes | ✓ hecho | `PantallaServicios.swift:321`, con el "nadie **nuevo**" del handoff |
| | "Service sheet (PDF)" | ✗ **falta** | y no es solo el botón: **no hay PDF de un culto** en ningún sitio, ni en el Mac ni en el iPhone. Iría en la barra, junto a "Tomar asistencia…" (`:75`) |
| **Informes de membresía** | `FOLIO` | ✗ **falta la cabecera** | la tabla del handoff se llama `TRANSFER MOVEMENTS` y tiene cabecera —FOLIO, TYPE, PERSON, CHURCH, DATE, STATUS—. La del Mac (`PantallaInformes.swift:152`) se llama `TRANSFERS`, **pinta el folio pero sin cabecera** y le falta la columna de estado. |
| | `RANGE` | ✗ **falta, y es más que un rótulo** | la primera pasada lo situó mal: no es de la tabla de traslados, es la banda de fechas del periodo "Rango" —RANGE · From · To, *"Each date clamps the other, so the range can never run backwards"*—. El Mac ofrece "Rango" en el selector (`:57`), pero **nadie en el Mac escribe `rangoDesde` ni `rangoHasta`** (`InformesMembresiaViewModel.swift:83`): se queda en "del mes pasado a hoy" y no hay forma de cambiarlo. Iría bajo la cabecera, después del selector (`:67`). |
| **Registro** | `WHAT WAS SAVED` | ✓ hecho | `InspectorTamio.swift:203`. Decía "WHAT WAS STORED"; desde el 22-sep dice "WHAT WAS SAVED", palabra por palabra como el handoff. Solo sale si el apunte trae `datos`. |

### Lo que la primera pasada no llegó a medir

Salió de la pasada mecánica sobre el HTML entero. Nada de esto estaba en la
tabla del 21-sep.

| Pantalla | Qué | Hoy | Dónde |
|---|---|---|---|
| **Acceso** | La pantalla de entrar que dibuja `handoff7` | ✗ **distinta** | `AccesoMac.swift` es una tarjeta sola. Le faltan el panel de marca —*"The church's books, kept straight."* y sus dos frases—, el subtítulo *"With the account your church gave you."*, *"Keep me signed in on this Mac"* y, en la misma pantalla, *"or · Unlock with Touch ID"* con su nota. El lema del Mac es otro (`:54`, *"Your church's treasury"*); el desbloqueo es una pantalla aparte (`:271`) y la nota de la biometría vive solo en Configuración (`PantallaConfiguracion.swift:350`). |
| **Cartas · Traslados** | Columnas DATE y LETTER, el sentido de cada traslado, y la nota *"A transfer without a letter is still open…"* | ✗ **faltan** | `PantallaCartas.swift:321`–`:338` tiene FOLIO, PERSON, CHURCH y STATUS. La fecha existe en la base (`TrasladoSalidaFila.fechaSolicitud`) pero `TrasladoEnLista` (`:46`) no la lleva. |
| **Reportes · mensual** | *"Not added to the balance: they move cash from the box to the bank."*, bajo los depósitos | ✗ **falta** | `PantallaReportes.swift:314`–`:333` |
| **Reportes · anual** | La cuarta cifra, "Deposited · Not part of the balance" | ✗ **falta** | el anual pinta tres (`PantallaReportes.swift:219`–`:225`); el mensual sí pinta cuatro |
| **Ingresos y Gastos** | El pie *"Right-click a row for actions · ⌘R reviews the selected record"* | ✗ **ausente a propósito** | ⌘R es aprobar, que es lo mismo que "Approve all safe": no está escrito. El menú contextual solo trae lo que se puede cumplir hoy (`TablaMovimientos.swift:113`). |

Y cuatro más que **no son deuda**, cada una con su porqué escrito:

- **"PLAN · Subscription"** de Configuración: Tamio es gratis y sin compra
  integrada (§0.-21 de `CONTEXTO.md`). No hay suscripción que renovar.
- **"Repeats"** de la hoja de actividad: la `recurrencia` es un JSON del web
  cuyas claves aquí no se conocen, y escribirlas a ojo repetiría el fallo del
  `estado` traducido (`NuevaActividad.swift:19`).
- **"Nothing to inspect"** en Configuración: el inspector ya no se ofrece donde
  no tiene nada que enseñar (§0.-22).
- **"Tab moves through every field. Nothing here needs the mouse."** se
  reescribió porque no es verdad en un Mac sin la navegación por teclado
  encendida: el tabulador se salta los selectores (`CapturaRapida.swift:193`).

## Lo que el handoff sigue sin tener

En `docs/LO-QUE-EL-HANDOFF-NO-TRAE.md`. Queda una sola cosa viva de esa lista:
**el presupuesto de una actividad**, que el handoff pide y no tiene columna en
`agenda`. Se dejó fuera del formulario —en las dos plataformas— porque un campo
que se teclea y se pierde es peor que no tenerlo.

## Diferencias deliberadas, que no son deuda

- **Cartas y traslados** y **Registro** se rediseñaron para el Mac antes de que
  el handoff los trajera; el Registro es una tabla y no una lista agrupada,
  porque auditar es cruzar y cruzar necesita columnas.
- **Los catálogos son los del web, no los del handoff**: once tipos de acta y
  siete estados, diez tipos de culto, veintiún tipos de actividad. El handoff
  los recorta en su maqueta y recortarlos de verdad escribiría en la columna
  valores que el servidor no reconoce.
- **⇧⌘T para la carta**, por el choque de ⇧⌘L.

## Configuración · lo que se dejó fuera a propósito

Terminada contra `handoff7` el 21-sep. Tres cosas del diseño no entraron, y
ninguna por olvido:

- **"La secretaria puede ver reportes."** No es que falte: **hay que quitarlo
  del diseño**, y lo decidió Iván el 22-sep. La secretaria ya ve Reportes por
  naturaleza del rol —`Permisos.ve(_:)` se lo da siempre, con su porqué al
  lado: necesita las cifras del mes para las actas y para la junta sin poder
  tocar un movimiento— y la propia nota al pie del handoff, *"Reports only —
  she still can't touch a movement"*, describe lo que la app ya hace. El
  diseño dibujó como ajuste algo que es una regla del rol.

  Además no tendría dónde guardarse —`tesoreroVePadron` y
  `tesoreroPuedeEliminar` son las dos columnas que hay— y sería peor que en
  otros casos, porque **es un permiso**: los dos que existen los aplica también
  el servidor, y un interruptor que solo escondiera Reportes en esta app
  prometería una protección falsa; la secretaria seguiría leyendo las cifras
  desde el web. Un control de acceso decorativo es peor que ninguno, porque se
  confía en él.
- **El segundo recuadro "PDF preview"** de Institución. Es la misma previa del
  membrete que ya está arriba en esa pantalla, dibujada dos veces en la maqueta.
- **La apariencia como dos filas con palomita.** Aquí es un selector, porque la
  app tiene tres opciones y el handoff dibuja dos: falta "Automático".

Y una **nota del handoff que se escribió distinta a propósito**: dice que el
respaldo "va cifrado con la clave de la iglesia", y hoy no es verdad — va
cifrado solo si se pide, con la contraseña que elija quien lo hace. Las notas se
copian palabra por palabra cuando explican una regla; esta describe una que la
app no cumple, y copiarla sería prometer un cifrado que no existe.
