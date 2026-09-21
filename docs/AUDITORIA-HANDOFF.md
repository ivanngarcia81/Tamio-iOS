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

**Sin diferencias: Inicio, Membresía, Agenda y Configuración.** Y en Tesorería,
las cuatro tablas —Ingresos, Gastos, Aportantes y Depósitos— coinciden **columna
por columna y en el mismo orden**.

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
