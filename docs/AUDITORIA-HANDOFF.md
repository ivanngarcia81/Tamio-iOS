# Auditoría del Mac contra `handoff7` · 21 de septiembre de 2026

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

## Estado

**Las hojas están todas.** Miembro —alta y edición—, pariente, seguimiento,
acta, actividad, carta, culto y asistencia, sobre la forma común `HojaMac`.

**Los atajos son los del handoff**: ⌥⌘N contextual y nunca apagado, ⇧⌘M, ⌘K,
⌘1…⌘9 y ⌘0. La carta va con ⇧⌘T y no con el ⇧⌘L que el handoff declara dos
veces.

**Sin diferencias: Inicio, Membresía y Agenda.** Y en Tesorería, las cuatro
tablas —Ingresos, Gastos, Aportantes y Depósitos— coinciden **columna por
columna y en el mismo orden**.

> **Esta pasada se quedó vieja el mismo día que se escribió, y en dos sitios.**
>
> Decía también "sin diferencias: … Configuración", y era falso: a esa pantalla
> le faltaban siete de sus ocho secciones —seguridad, cerrar sesión y borrar la
> cuenta; el logo; la previa del membrete; las firmas; invitar y sincronizar; el
> porcentaje de las categorías; y la zona de riesgo entera, que era una nota
> diciendo que no estaba enchufada—. Se terminaron el 21-sep por la noche.
>
> Y la tabla de abajo se midió **antes** de que se escribieran el panel de la
> carta y el de Reportes, así que cuenta como ausentes rótulos que ya estaban en
> el código —"Issue the letter", "INTERNAL NOTES", "VARIABLES", "RESOLVED"—.
> Estaban escritos y **no se dibujaban**, que es otro fallo y no el que la tabla
> dice: `bandaDeBorrador` y `notasInternas` existían en `PantallaCartas` y no los
> llamaba nadie.
>
> **Volver a medirlo pide más cuidado del que parece.** Buscar el literal del
> handoff en el código da falsos positivos en cuanto el rótulo no es un literal:
> "Require Touch ID to open" se escribe con el nombre de la biometría
> interpolado, y "USD — US dollar" lo compone `Catalogos`. Una pasada nueva
> tiene que resolver eso antes de publicar una cifra.

### Lo que falta, medido

| Pantalla | Rótulos | Qué son |
|---|---|---|
| **Cartas** | 8 | El panel de detalle: `FOLIO`, `RESOLVED`, `VARIABLES`, `INTERNAL NOTES`, "Issue the letter", "Draft with folio", "Not printed on the letter.", "Write a letter from this template". La hoja de redactar ya está; falta el papel de la derecha y las tres subpestañas. |
| **Reportes** | 6 | `BALANCE`, `PERIOD BALANCE`, `PERIOD DEPOSITS`, `ON-SCREEN SUMMARY`, "Share", "Not included in the PDF". |
| **Por revisar** | 2 | "Approve all safe" y "Ask for data". **Ausentes a propósito**: mueven el estado de revisión de un apunte de dinero y no están escritas. Un botón que no hace nada, ahí, promete una decisión que no se toma. |
| **Servicios** | 2 | "Service sheet (PDF)" y el vacío de visitantes. |
| **Informes de membresía** | 2 | `FOLIO` y `RANGE`, de la tabla de traslados. |
| **Registro** | 1 | `WHAT WAS SAVED`, la cabecera del panel de detalle. |

Antes de esta pasada eran 27. Se cerraron: la cabecera de Actas —"REUNIONES DE
ESTE AÑO" con su ⇧⌘M—, el vacío del Registro y su pie *"el registro guarda
copias, no referencias"*, y el título de la hoja de edición de una ficha.

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

- **"La secretaria puede ver reportes."** El handoff lo dibuja como interruptor
  y **no hay columna** donde guardarlo: `tesoreroVePadron` y
  `tesoreroPuedeEliminar` existen, este no. Es el mismo criterio que dejó fuera
  el presupuesto de una actividad — un interruptor que se pierde al guardar es
  peor que no tenerlo. Entra cuando el web tenga la columna.
- **El segundo recuadro "PDF preview"** de Institución. Es la misma previa del
  membrete que ya está arriba en esa pantalla, dibujada dos veces en la maqueta.
- **La apariencia como dos filas con palomita.** Aquí es un selector, porque la
  app tiene tres opciones y el handoff dibuja dos: falta "Automático".

Y una **nota del handoff que se escribió distinta a propósito**: dice que el
respaldo "va cifrado con la clave de la iglesia", y hoy no es verdad — va
cifrado solo si se pide, con la contraseña que elija quien lo hace. Las notas se
copian palabra por palabra cuando explican una regla; esta describe una que la
app no cumple, y copiarla sería prometer un cifrado que no existe.
