# Verificación de PR 1–8 · Tamio-iOS

Rama: `claude/repo-chat-vs-xcode-g6y9zx` · base `1c0e20e` · cabeza `b1412d6`
69 archivos, +2041 / −767. Nueve commits.

---

## Cómo usar este documento

**Si eres un agente en el Mac:** este es tu encargo. Todo el código de esta rama
se escribió en un contenedor Linux **sin `swift`, sin `xcodebuild` y sin SDK de
iOS**, así que nunca se compiló ni se vio en el simulador. Lo único que se
verificó allí fue balance de delimitadores, comillas pares y que cada símbolo
nuevo esté definido donde se usa.

Tu trabajo, en este orden:

1. Compilar y arreglar lo que no compile (§1). Ahí está el riesgo real.
2. Correr las comprobaciones automáticas (§2). Son grep, segundos.
3. Recorrer el simulador pantalla por pantalla (§3), en **los dos modos** y en
   **los dos idiomas**, en iPhone y en iPad.
4. Revisar los riesgos conocidos (§4): son dudas concretas que quedaron sin
   resolver por no poder ver la app.

Reporta por PR: qué pasó, qué falló y qué arreglaste. Si algo no compila, el
arreglo va **antes** de seguir con lo visual.

**Preparación**

```bash
git checkout claude/repo-chat-vs-xcode-g6y9zx
git pull
xcodegen generate      # imprescindible: hay 19 archivos nuevos
open Tamio.xcodeproj
```

Los 19 nuevos son 16 Color Sets en `Assets.xcassets` y tres archivos de
`Support/`: `Catalogos.swift`, `Espaciado.swift`, `Fechas.swift`.

---

## 1. Compilación

```bash
xcodebuild -project Tamio.xcodeproj -scheme Tamio \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E 'error|warning'
```

Sitios donde un error de compilación es plausible, por orden de sospecha:

| # | Dónde | Qué mirar |
|---|---|---|
| 1.1 | `Espaciado.swift` → `FilaDeLista` | `ViewModifier` que aplica `listRowInsets`/`listRowBackground`/`listRowSeparator`. Esos modificadores son de fila de lista; si Swift se queja del tipo, hay que devolver `some View` explícito o partirlo. |
| 1.2 | `NuevoMovimientoView` y `EditarAsuntoView` → `pickerCategoria` | Rama `if/else` con dos `pickerStyle` distintos bajo `@ViewBuilder`. Un ternario aquí **no** compila (los estilos son tipos distintos); si el `if/else` tampoco, hay que envolver en `AnyView`. |
| 1.3 | `MovimientosView` → `confirmationDialog` | Usa `presenting:` con `Binding(get:set:)` inline. Verifica que la sobrecarga exista tal cual en iOS 17. |
| 1.4 | `AmountText` | `let color = ingreso.map { … } ?? self.color` sombrea la propiedad `color`. Legal, pero si el compilador se queja, renombra la local. |
| 1.5 | `Palette.swift` | `static let donut: [Color] = [brand, morado, cian, naranja]` referencia otros `static let` del mismo `enum` sin cualificar. |
| 1.6 | `Money.swift` | Pasó de `import Foundation` a `import SwiftUI` para poder devolver `Color`. |
| 1.7 | `MembresiaView` | `vm.sincronizarSeleccion(enSeguimiento:)` es `@MainActor` y se llama desde `.onChange`. |
| 1.8 | `Sidebar.swift` | Los badges pasan `Int` donde la tupla declara `Int?`. Depende de promoción implícita a opcional. |
| 1.9 | `RevisarViewModel.editar` | Ganó parámetro `fecha: Date`. Comprueba que el único call site (`RevisarView:46`) case. |

---

## 2. Comprobaciones automáticas

Cada línea debe dar el resultado indicado. Si no, algo se deshizo.

```bash
# PR 1 — 17 Color Sets (16 Tamio* + AccentColor)
ls -d Tamio/Assets.xcassets/*.colorset | wc -l                      # → 17

# PR 1 — el único .opacity() sobre Paleta debe ser la sombra de ServiciosView
grep -rn 'Paleta\.\(brand\|negativo\|aviso\)\.opacity(' Tamio --include=*.swift
# → 1 línea, ServiciosView, .shadow(color: Paleta.brand.opacity(0.35)…)

# PR 1 — ningún Color("Tamio…") sin su colorset, ningún colorset sin usar
# (comparar las dos listas)
grep -rho 'Color("Tamio[A-Za-z0-9]*")' Tamio --include=*.swift | sort -u
ls -d Tamio/Assets.xcassets/Tamio*.colorset | xargs -n1 basename | sed 's/.colorset//' | sort

# PR 2 — el tab bar ya no usa ultraThinMaterial
grep -n 'toolbarBackground' Tamio/Views/RootView.swift               # → .bar y .visible

# PR 2 — 12 colchones inferiores
grep -rc 'colchonInferior()' Tamio/Views/*.swift | grep -v ':0'      # → suma 12

# PR 3 — ningún Locale forzado
grep -rn 'Locale(identifier:' Tamio --include=*.swift                # → 0

# PR 3 — ningún "Diezmo"/"Efectivo" fuera de L.t bajo Data/
grep -rn '"\(Diezmo\|Efectivo\)' Tamio/Data | grep -v 'L\.t('        # → 0

# PR 3 — HubRow con SF Symbol, no iniciales
grep -rc 'HubRow(icono:' Tamio/Views/IPhone*.swift                   # → 4 y 7
grep -rn 'HubRow(iniciales:' Tamio                                   # → 0

# PR 4 — 7 tint(.red) explícitos (6 swipe + AportanteDetalle)
grep -rn 'tint(.red)' Tamio --include=*.swift | wc -l                # → 7

# PR 7 — ninguna lista local de categorías; todo por Catalogos
grep -rn 'listaCategorias\|categoriasIngreso\|categoriasGasto' Tamio/Views  # → 0
grep -rc 'Catalogos\.' Tamio/Views/*.swift | grep -v ':0'            # → 4 y 4

# PR 8 — ningún literal de margen horizontal
grep -rhoE 'padding\(\.horizontal, [0-9]+\)' Tamio --include=*.swift | wc -l  # → 0

# PR 8 — las ocho listas en .plain con filaDeLista
grep -rc 'filaDeLista(' Tamio/Views/*.swift | grep -v ':0'           # → 8 archivos
grep -rn 'listStyle(.insetGrouped)' Tamio --include=*.swift
# → solo IPhoneAjustesView (9), los dos hubs de iPhone, y las dos hojas de
#   filtros (MovimientosView, MembresiaView). Ninguna lista principal.
```

---

## 3. Simulador, pantalla por pantalla

Recorre cada bloque en **claro y oscuro** y en **español e inglés**
(Scheme → Run → Options → App Language). iPhone 16 y iPad Pro 11".

### 3.1 · PR 1 — Color y modo oscuro

- [ ] **Ficha de miembro** → las 8 barras de asistencia se distinguen del fondo,
      y la última (destacada) de las otras siete.
- [ ] **Membresía** → el pill "Miembros" seleccionado se lee más que "Asistencia".
- [ ] **Movimientos** → la fila seleccionada se nota sin ser estridente.
- [ ] **Inicio** → "+4.2%" y "11.0%" se leen con fuerza sobre negro.
- [ ] **Ficha de miembro** → las tarjetas de KPI se distinguen de su fondo. En
      oscuro eran negro sobre negro. Igual en Por revisar, Registro, y las dos
      gráficas del Dashboard.
- [ ] **Categorías** → el morado, el cian y el naranja se leen en oscuro (dona
      del Dashboard, puntos de agenda, KPI de la ficha de miembro).
- [ ] **Tinte global** → `AccentColor` pasó de un gris azulado `#214F66` a verde
      de marca. Comprueba que no aparezca verde donde antes había azul del
      sistema en controles que no se tintan a mano.

### 3.2 · PR 2 — Materiales y botones

- [ ] **Ningún texto de contenido se lee a través del tab bar**, en ninguna
      pantalla ni modo. Era el bug de `ultraThinMaterial`.
- [ ] **Cabecera verde** (iOS 26+ solamente) se distingue del cuerpo en oscuro.
      En iOS 17–25 no hay banda verde: `encabezadoNav` solo pinta bajo
      `if #available(iOS 26)`. No es un fallo.
- [ ] **Ningún grupo de botones tiene dos verdes.** Mira MovimientoDetalle
      (Comprobante / Compartir / Editar), MiembroDetalle, AportanteDetalle,
      ReportesView, CorteDetalle.
- [ ] **⚠ Los secundarios no deben parecer deshabilitados.** Llevan
      `.tint(Color.secondary)`; en oscuro eso puede quedar tan tenue como el
      bug que arregla. Si es el caso, cambia los 9 sitios a `Color.primary`.
- [ ] Ninguna lista termina pegada al tab bar (Inicio, Movimientos, Membresía,
      Por revisar, las cuatro fichas de detalle).

### 3.3 · PR 3 — Idioma y datos

Con el sistema **en inglés**:

- [ ] No aparece ni una palabra en español en Movimientos, Depósitos,
      Aportantes, Reportes ni Por revisar. Ni "Diezmo", ni "Efectivo", ni meses.
- [ ] Las fechas de la semilla salen en inglés: "Mar 14, 2026", no "14 mar 2026".
- [ ] El gráfico de asistencia dice Jan/Feb/Mar/Apr, no Ene/Feb/Mar/Abr.
- [ ] "25 of 27", no "25 de 27".
- [ ] El acta generada (Actas → nueva) sale entera en inglés, fecha incluida.
- [ ] Los avatares de los hubs de Tesorería y Secretaría son símbolos, no "Mo",
      "Ap", "Ag".

Contadores, que ahora deben cuadrar entre pantallas:

- [ ] Inicio dice **8** por revisar · badge del tab **8** · bandeja **8** ·
      sidebar del iPad **8**.
- [ ] Hub de Secretaría: **248** en el directorio, **236** de alta, **12** de
      baja. Membresía encabeza los mismos 248 / 236.
- [ ] Tesorería encabeza el **mes en curso**, no "Agosto 2026", y coincide con
      el que dice Inicio.
- [ ] Ficha de transacción: la fecha del rastro de auditoría es **la misma** que
      la de la cabecera.
- [ ] Sidebar del iPad: Aportantes **11**, Agenda **7**.
- [ ] Ajustes dice "Zona de riesgo / Danger zone", y el icono de Preferencias
      se ve en oscuro.
- [ ] Membresía: Lucía Márquez dice el mismo ministerio en la lista y en la
      ficha. Igual las otras tres filas que decían "damas", "diaconado" y
      "sin ministerio".
- [ ] Membresía → pestaña Seguimiento: la fila resaltada en la lista es la
      persona que muestra el panel. No debían discrepar.

### 3.4 · PR 4 — Swipe y depósito

- [ ] **Movimientos → deslizar una fila**: "Eliminar" sale **rojo** y "Editar"
      verde. Antes los dos verdes.
- [ ] Eliminar **pide confirmación**, con el titular y el monto en el mensaje.
- [ ] Al deslizar **no asoma ningún rectángulo blanco de esquinas rectas** entre
      las tarjetas, y la fila de abajo no queda cortada.
- [ ] La barra verde de la fila seleccionada **no se sale por la esquina**
      redondeada. Mira Gastos, fila "Utilidades · Luz CFE".
- [ ] Igual comprobación de swipe rojo en Actas (mociones, acuerdos, personas)
      y Servicios (canciones, visitantes).
- [ ] **Depósitos → un corte, en iPhone**: "Marcar depositado" está **fijo
      abajo** sobre el tab bar, y "Ficha del banco / Adjuntar ficha" aparece
      **antes** de "Se registrará así" al scrollear. No debe poderse confirmar
      el depósito sin haber visto la opción de adjuntar.
- [ ] En iPad ese corte sigue en dos columnas, con el botón dentro de la tarjeta.
- [ ] La sección dice "Movimientos del corte", no "Movimientos en caja".

### 3.5 · PR 5 — Formularios y listas

- [ ] **Por revisar → Editar** (el ítem duplicado): la hoja se ve como la de
      alta. `Form`, secciones, `Picker` de menú, `DatePicker`. Nada de chips ni
      cajas con borde.
- [ ] Esa hoja **tiene campo de fecha** y abre a **media pantalla**, expandible.
- [ ] **Nuevo ingreso**: el importe sale **enfocado con teclado** al abrir.
- [ ] El subtítulo del importe dice solo "MXN".
- [ ] "Dar constancia anual" arranca **apagado** y está **deshabilitado** hasta
      elegir aportante. Al volver a "Sin asignar" se apaga solo.
- [ ] El texto sobre visitantes está pegado a la fila Aportante, no al toggle.
- [ ] **Gastos**: los montos salen "−$3,410.50" en **rojo**, como en Inicio y
      Por revisar. Ingresos en verde con "+".
- [ ] La fila de movimiento abre con el **símbolo de su categoría** en círculo
      tintado, no con un punto de 8 pt.
- [ ] El pie de la lista ya no repite el subtítulo del header: header = mes,
      pie = conteo + total.
- [ ] **Depósitos → un corte**: las tres cifras están en **una tarjeta de tres
      filas**, con "N de M seleccionados" en la cabecera. El chip "Sin
      depositar" va en su propia línea, no partiendo el título.
- [ ] El selector de cuenta (Banorte ··4821) sale **verde**, no azul.
- [ ] La barra de navegación del detalle del corte va **vacía**.

### 3.6 · PR 6 — Por revisar y filtros

- [ ] **Membresía → Filtros**: solo la opción **seleccionada** lleva palomita
      verde; las etiquetas van en color primario, no todas en verde.
- [ ] Esa hoja se puede **expandir** para ver la sección MINISTERIO completa.
- [ ] **Movimientos → Filtros**: mismo comportamiento en CATEGORÍA.
- [ ] **Por revisar**: "Ver movimientos recurrentes" e "Ir al corte" salen con
      **chevron y tint neutro**, no en verde prominente. "Aprobar",
      "Vincular aportante" y "Restaurar" siguen verdes.
- [ ] El detalle se titula con el **asunto** ("Ofrenda del domingo"), no con el
      estado. La barra va vacía y el estado está en un chip **naranja** en
      formato normal, no rojo en mayúsculas.
- [ ] Las tarjetas ya no repiten el título en el subtítulo (mira "Renta del
      anexo" y "Miércoles 19 de agosto").
- [ ] Los encabezados en inglés no llevan artículo: "ENTRY DETAILS", no
      "THE INCOME".
- [ ] Los montos del detalle de aprobación salen **sin " MXN"**, como los del
      detalle de transacción, y las fechas en el mismo formato en las dos
      pantallas.
- [ ] Los tres asuntos que esperan visto bueno ofrecen **Devolver**, y al usarlo
      sale el aviso "se devolvió al tesorero".

### 3.7 · PR 7 — Categoría y método de pago

- [ ] **Con el sistema en inglés**, abrir a editar un movimiento existente
      (Movimientos → Editar): el Picker de categoría muestra **la categoría del
      movimiento marcada**. Antes salía en blanco porque las opciones estaban
      en español y el valor guardado en inglés. Igual con el método de pago.
- [ ] Un movimiento con categoría libre ("Ofrenda de gratitud") **conserva su
      valor** como opción del Picker y no lo pierde al guardar.
- [ ] Categoría de **gasto** (19 opciones) empuja una pantalla con lista y
      palomitas. Categoría de **ingreso** (6) abre un menú.
- [ ] La hoja de alta y la de edición ofrecen **las mismas** categorías y los
      mismos métodos.
- [ ] Ninguna etiqueta se corta en los chips que quedan (Agenda y Membresía usan
      `FlowLayout` todavía): pruébalos en inglés, en iPhone SE si lo tienes.

### 3.8 · PR 8 — Márgenes

- [ ] En las ocho pantallas de lista (Membresía, Movimientos, Aportantes, Actas,
      Cartas, Servicios, Reportes, Depósitos), **el borde izquierdo de las
      tarjetas de la lista coincide con el de la cabecera y con el del pie**.
      Pon una regla o compara capturas: eran tres márgenes distintos.
- [ ] Ninguna tarjeta queda pegada al borde ni sobrepasa el ancho.
- [ ] Las filas siguen respondiendo a **tap** y a **swipe**.
- [ ] El separador entre filas no reaparece donde no debe.
- [ ] En iPad las ocho columnas se ven como antes.
- [ ] **⚠ El fondo de las listas en iPhone.** Al pasar de `insetGrouped` a
      `plain` con `scrollContentBackground(.hidden)`, el fondo dejó de ser
      `systemGroupedBackground` y ahora muestra el `.regularMaterial` que las
      columnas ya tenían. Eso iguala iPhone con iPad, pero **es un cambio de
      color** y este PR no debía tocar ninguno. Si se ve mal, la corrección es
      una línea por vista: `.background(Color(.systemGroupedBackground))` en la
      lista en vez de heredar el material.

---

## 4. Riesgos conocidos

Dudas que quedaron abiertas por no poder ver la app. Van por probabilidad de
ser un problema real.

1. **Botones secundarios demasiado tenues en oscuro** (PR 2.3). `.bordered` con
   `Color.secondary` da relleno casi invisible sobre negro y texto gris: puede
   preservar el síntoma que arregla. Nueve sitios; `Color.primary` es la
   alternativa. Se implementó lo pedido en el brief.
2. **Colchón + barra fija en Depósitos** (PR 2.4 y 4.4). El `colchonInferior()`
   de PR 2 y el `safeAreaInset` de la barra de depósito se apilan: quedan 12 pt
   de aire entre el contenido y la barra. Si molesta, quita el colchón en esa
   vista.
3. **Fondo de las listas en iPhone** (PR 8). Ver §3.8.
4. **"Ver movimientos recurrentes" e "Ir al corte" siguen resolviendo el
   asunto.** Su `kind` es `.resolver`, así que al pulsarlas el asunto sale de la
   bandeja: no navegan a ningún lado porque los destinos no existen. Llevan
   chevron, que promete navegación. Se prefirió eso a dejarlas inertes y sin
   forma de despachar el asunto. Cuando existan los destinos, cambia el `kind`.
5. **`FlowLayout` reescrito** (PR 7). El diagnóstico original decía que la
   comparación de corte sobrestimaba el ancho en un `spacing`; no es cierto, la
   comparación ya era correcta. El fallo real era que las dos pasadas
   calculaban el corte por separado. Ahora comparten una rutina. Comprueba los
   dos sitios que lo usan: Agenda (chips de tipo) y Membresía (chips de
   ministerio).
6. **Nombres de SF Symbol elegidos a ojo** (PR 3.1 y 5.5). Si alguno no existe
   en iOS 17, sale un cuadro vacío. Verifícalos en el catálogo de SF Symbols o
   con la app corriendo. Son 20 en `Paleta.iconoCategoria`:

   ```
   hands.and.sparkles.fill  gift.fill  globe.americas.fill  calendar
   bolt.fill  wrench.and.screwdriver.fill  sparkles  fork.knife
   shippingbox.fill  car.fill  desktopcomputer  building.2.fill
   person.crop.circle.fill  music.note  heart.fill  hand.raised.fill
   shield.fill  megaphone.fill  chair.fill  circle.fill
   ```

   y 11 nuevos en `HubRow` (los otros seis ya estaban en el repo):

   ```
   person.text.rectangle.fill  chart.pie.fill  calendar  checklist
   doc.text.fill  envelope.fill  bubble.left.and.bubble.right.fill
   arrow.left.arrow.right  person.2.fill  building.columns.fill
   chart.bar.fill
   ```

   `checklist` requiere iOS 16; el resto son de iOS 13–14. El deployment target
   es 17, así que todos deberían estar.
7. **`AccentColor` cambió también en claro** (PR 1). Era `#214F66`, un gris
   azulado que no correspondía al verde con el que la app se tinta en
   `RootView`. Ahora es marca. Si algún control salía azul a propósito, ahí está
   la causa.

---

## 5. Qué no cambiar

- `IPhoneAjustesView`, los dos hubs de iPhone y las dos hojas de filtros se
  quedan en `insetGrouped` a propósito: son pantallas de ajustes sin tarjetas
  propias compitiendo.
- La sombra de `ServiciosView` conserva su `.opacity(0.35)`: ahí el alpha es
  parte del efecto, no un relleno.
- El "Eliminar" de `AportanteDetalle` es `role: .destructive` en un
  `confirmationDialog`: el rojo lo pone el sistema.
- Los nombres propios, folios, horas, montos y correos de la semilla siguen sin
  `L.t` a propósito: no son texto traducible.

---

## 6. Pendiente, no hecho

- Los badges de la sidebar del iPad leen propiedades `static`, que SwiftUI no
  observa: al aprobar un asunto el badge no se refresca hasta que la vista se
  redibuje. La solución es darle a `Sidebar` un `RevisarViewModel` compartido,
  como hace `IPhoneRootView` con el badge del tab. Es cambio de estructura.
- Quedan hex fijos sin variante oscura fuera de `Paleta`: `Miembro.estado.color`,
  los colores de `Secretaria`, los iconos de `ConfiguracionView` y las paletas
  de `IPhoneAjustesView`. PR 1 solo cubrió dona, categoría y agenda.
- Los `.regularMaterial` de las diez columnas de lista no se tocaron. Es un
  rediseño de materiales, no del sistema de color.
