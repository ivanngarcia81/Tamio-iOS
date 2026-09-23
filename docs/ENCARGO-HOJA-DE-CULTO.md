# Hoja de culto (PDF) · encargo de diseño

Escrito el 22-sep-2026 para pedírselo al diseño. No existe en ninguna
plataforma —ni Mac, ni iPhone, ni el web—; el handoff solo dibuja el botón
(`AUDITORIA-HANDOFF.md`, Servicios). Los campos salen de `Servicio`
(`Tamio/Models/Secretaria.swift`) y los tipos de culto de
`ServiciosRepository.swift` (`Cultos`).

## Qué es

Un documento de una o dos páginas que resume **un culto concreto**: quién
dirigió y predicó, el mensaje, el orden del culto, quién sirvió en cada puesto,
la asistencia y los visitantes. Se genera desde la ficha del culto en
**Secretaría › Servicios**. Es para un culto lo que el acta es para una
reunión: el papel que se archiva o se le entrega al pastor.

## Dónde vive el botón

- **Mac:** en la barra de la pantalla Servicios, junto a «Tomar asistencia…».
  El handoff ya lo dibuja como **«Service sheet (PDF)» / «Hoja de culto (PDF)»**.
- **iPhone / iPad:** hoy no hay botón. Si va, en la ficha del culto, al lado de
  donde el acta tiene «Vista previa PDF».
- Al pulsarlo: **vista previa** con **Compartir** y **Guardar/Imprimir**, igual
  que el acta y el estado financiero.

## Formato fijo

- **Carta, 612 × 792 pt, vertical** (`PDFExport.anchoCarta`).
- **Bilingüe**: cada rótulo en español e inglés; sale en el idioma de la app.
- **Membrete** arriba como el acta y las cartas: logo centrado sobre el nombre
  si lo hay, dirección y contacto de Ajustes. **Pie institucional** abajo.
- **Sin logo tiene que verse bien**, sin hueco reservado.
- Aguanta **blanco y negro**: nada puede depender del color.

## Los datos que existen (no hay más)

| Bloque | Campo | Notas |
|---|---|---|
| Encabezado | Tipo de culto | Culto dominical, Reunión de oración, Estudio bíblico, Jóvenes, Damas, Caballeros, Vigilia, Evangelístico, Especial, Otro |
| | Fecha | Solo día, sin hora |
| Quién | Dirige · Predica | Texto libre, pueden estar vacíos |
| El mensaje | Título · Texto bíblico · Resumen | El resumen puede ser largo |
| Escuela dominical | Tema · Maestro | |
| Orden del culto | hora · título · encargado | Ordenada; de 0 a ~15 puntos |
| Puestos | puesto · persona | Predicación, Alabanza, Ujieres, Ofrenda, Sonido, Niños, Oración y los que agregue la iglesia; puede haber **sin asignar** |
| Participaciones | lista de nombres | |
| Asistencia | Niños · Jóvenes · Adultos | Tres números; el total se calcula |
| Visitantes | nombre, teléfono, correo, invitado por, **primera visita**, notas | De 0 a ~30 |
| Eventos | texto libre | Anuncios o sucesos del culto |

## Lo que el diseño tiene que resolver

1. **Casi todo es opcional.** ¿Un bloque vacío desaparece entero? Nunca un
   título con nada debajo ni «—» por todas partes.
2. **Largo variable.** Si pasa de una página, ¿qué se repite arriba de la segunda?
3. **Datos personales de los visitantes** en papel: ¿teléfono y correo sí o no?
4. **Puestos sin asignar:** ¿hueco para rellenar a mano u omitidos?
5. **Asistencia:** fila de cifras grandes o línea discreta; una gráfica sobra.
6. **Jerarquía:** qué culto, quién predicó y sobre qué, cuánta gente vino — en
   dos segundos.
7. **¿Firma?** No hay columna. Si va una «Revisado por», es una línea en blanco
   para firmar a mano, no un campo.

## Lo que NO puede llevar

- **Dinero**: las ofrendas viven en Tesorería; esta hoja es de Secretaría.
- **Campos que no están en la tabla**: si hace falta uno, se pide aparte.

## Lo que se pidió de vuelta

- Dominical **lleno** (6 visitantes, 12 puntos de orden) y oración **mínima**
  (tipo, fecha, dirige, asistencia).
- Variante **sin logo**.
- Botón y vista previa en el Mac, y en el iPhone si va.
- Rótulos en español e inglés.
- Respuestas a los puntos 3, 4 y 7.

## Para cuando llegue

El generador tiene que vivir en una carpeta que compilen **los dos** targets
(`Tamio/Support`), no en `Tamio/Views`: el Mac no compila esa carpeta, que es
lo mismo que hoy bloquea el PDF del acta en el Mac (`CONTEXTO §0.-23`).
