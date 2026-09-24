# Para el siguiente chat · desde el 23 de septiembre de 2026

Resumen del chat del 22 al 23 de septiembre para seguir en otro. El detalle está en `CONTEXTO.md`
(§0.-22, §0.-23 y §0.-24) y en `docs/ROJAS-SEPTIEMBRE.md`. Esto es solo el mapa.

**Cómo entrar:** «revisa el repo de Tamio-iOS, rama mac-target, lee `docs/SIGUIENTE-CHAT.md` y
sigamos con los tres puntos».

## Dónde está todo

- **Rama de trabajo:** `mac-target`.
- **Commits sin empujar:** `8540113` (el plan con los rótulos del web) y `74ea547` (fuera el
  «Andamiaje»).
- **`main` y `liquid-glass` van por detrás**, en `0fd3b99`. Hay que avanzarlas con avance rápido
  cuando Iván lo diga.
- **Hay otra sesión, «ivangarcia-c3»**, que también trabaja en el repo: la bienvenida del Mac, el
  icono y la doble cápsula de «Approve». Antes de commitear, mira `git status` y no subas lo suyo.

## Qué se hizo en este chat

1. **Las 44 rojas del iPhone:** ninguna era de la app (`ROJAS-SEPTIEMBRE.md`). La suite ya omite en
   cada aparato las pruebas del otro y lleva `-modoRevision` donde toca.
2. **Fallos reales arreglados:**
   - la configuración inicial se relee después de sincronizar;
   - `titular` (de `Movimiento` y de `Tx`) traduce la categoría: no más «diezmo» con la app en inglés;
   - `destinatarioTipo` guarda la clave y no el rótulo;
   - «Guardar» ya no guarda dos veces;
   - en el iPad, la fila de la firma se toca entera y la sección Institución se puede editar;
   - el plan sale con los rótulos del web.
3. **El Prompt 2** (el equipo que construye el Mac): Traslados, Informes con «Rango», firmar actas,
   Reportes con «Compartir», Duplicar ⌘D e Importar aportantes.
4. **Los PDF que faltaban** (`Tamio/Support`): la hoja de culto, el corte de caja y el acta en el
   Mac. Las piezas de papel viven ahora en `PiezasPDF.swift` y compilan en los dos targets. El
   encargo está en `docs/ENCARGO-HOJA-DE-CULTO.md`.
5. **El Mac, recorrido con capturas:**
   - la sombra salía impresa en el PDF de Reportes;
   - las barras de categorías salían mal proporcionadas;
   - había halos en las vistas previas;
   - los anchos de Reportes y Actas estaban mal.
6. **Las suites en el iPhone y el iPad físicos:** las 253 pruebas de unidad pasan en los dos. De
   las rojas de interfaz, las que quedan son del instrumento o de datos. Hay dos falsos positivos
   documentados en §0.-24: `DobleToque` y el candado.

## Los tres puntos para seguir

### 1. Lo que un usuario vería y no debería
- [x] El «Andamiaje» de la barra de estado (`74ea547`).
- [x] **Reportes (~1060 pt) y Configuración (961 pt) en media pantalla:** Iván decidió el 23-sep
  **pedírselo al diseñador**. La petición está en `LO-QUE-EL-HANDOFF-NO-TRAE.md` §6.
- [x] **Informes a media pantalla** (23-sep):
  - Con el inspector cerrado pedía 1090 pt: la cabecera iba en una sola fila y el botón CSV se
    encogía a «…». Ahora la cabecera pasa a dos filas y la ventana baja a **812 pt**. Con el
    inspector abierto, de 1697 a 1419.
  - Los meses del gráfico usan la inicial cuando no caben.
  - Asistencia sin listas tomadas dice «—» y no «0 %» ni «Mejor servicio: 0». Lee las cifras del
    ViewModel, como el iPhone, y las cuatro tarjetas miden lo mismo.
  - El «inspector cortado» que se vio antes era un recorte de la captura, no de la app.
- [x] **La pantalla de acceso del Mac, la del handoff 7** (24-sep). Sin «Mantener la sesión» ni
  «Touch ID»: Iván las dejó fuera, y el porqué está en `LO-QUE-EL-HANDOFF-NO-TRAE.md` §7. En DEBUG se
  ve sin cerrar la sesión con `-mostrarAcceso YES`. De paso, el texto sobre el verde en modo oscuro
  pasó de 2,41:1 a 7,08:1 en las tres pantallas verdes del Mac y en la invitación de iOS.

### 2. Decisiones de Iván que siguen abiertas
- [x] **Los botones que mueven dinero:** Iván decidió el 23-sep poner **solo lo que ya existe**.
  En Por revisar entran Aprobar, «Devolver al tesorero», «Aprobar todo lo seguro» y el aviso con
  Deshacer. En Ingresos y Gastos entra **Aprobar ⌘R**. Se probó de punta a punta y llega a
  Supabase. Quedan fuera «Marcar depositado» y «Pedir datos», que no existen en ninguna
  plataforma, y «Devolver a la bandeja», porque no se sabe si significa devolver o volver a
  pendiente.
- [x] **Inicio con el inspector abierto:** **no** va en 2×2. A media pantalla se usa con el
  inspector cerrado.
- [x] Del zip del diseño:
  - Los seis PDF ya estaban descartados en §0.-24.
  - **El 1b** («Order of service») se solapa entero con `HojaCultoPDF`: no se construye. Como mucho
    sería una variante sin asistencia ni firmas, y eso habría que pedirlo.
  - **«Tamio for Mac»** es un borrador anterior al handoff 7, que lo sustituye: no se construye nada
    de ahí. Sus ajustes nuevos (series de folio, borrar los datos del Mac) no tienen columna.

### 3. Probar de punta a punta lo que escribe (en la iglesia de prueba)
- [x] Firmar un acta desde el Mac: «PRUEBA Acta handoff7» llegó como `aprobada` con sus tres firmas.
- [x] Importar aportantes hasta el final: entraron dos y se omitió la fila sin nombre. Al reimportar
  el mismo archivo, las dos se reconocen como existentes.
- [x] Una nota de Seguimiento llegó a `members.seguimiento_notas`. Si la persona no está en
  `vm.items`, ahora se relee la lista antes de rendirse.
- [x] **Un Mac recién estrenado** (23-sep, con la base apartada y la sesión en el llavero):
  - Sale la bienvenida, baja todo (las mismas filas que la copia, tabla por tabla) y la iglesia
    se relee: «Iglesia de prueba · Saltillo». La ficha del servidor no se tocó (`updated_at`
    anterior a la prueba).
  - **Fallo encontrado y arreglado:** Inicio se quedaba en $0.00 y «No transactions yet» hasta
    cambiar de sección. `cargarTodo()` no releía Inicio, Por revisar, Informes ni Reportes; ahora
    sí. Visto de nuevo con la base vacía: Inicio sale con los datos.
  - Sin probar: entrar desde la pantalla de acceso con otra cuenta, porque pide la contraseña.
- [x] Informes con «Rango»: las altas, los recibidos, los traslados y el seguimiento de nuevos ya
  cuentan por el periodo entero (`PeriodoFechas`, como el `Periodo` del web). **La asistencia
  todavía no**: `asistenciaResumen()` del repositorio no recibe periodo.

## La suite en los aparatos · 23-sep, noche (`cc5dabf` + el código de ese día)

- **iPad, por cable:** unidad 258 de 258. Interfaz: 79 verdes, 98 omitidas (son del teléfono) y 12
  rojas, todas de instrumento o de datos:
  - la ventana que no se estrecha (4);
  - AX1 no se puede poner en el aparato (1);
  - faltan los CSV sin sembrar (3);
  - filas de la maqueta (4).
  Las seis que quedaron sin decidir en septiembre ya pasan.
- **iPhone, por Wi-Fi:** la primera vuelta dio 77 rojas porque **se bloqueó a media corrida**
  («Not authorized for performing UI testing actions»). Con Bloqueo automático en «Nunca», las 71
  repetidas quedaron así:
  - 65 verdes;
  - 4 rojas:
    - `MembresiaTelefono`: de datos, no hay traslado en curso;
    - `Presentaciones…ActasView`: de datos, el acta más reciente se firmó ese día;
    - `TarjetaEsBoton`: falso negativo de `isHittable` en el carrusel; el toque sí abre la carta;
    - `Presentaciones…CorteDetalle`: inestable. Repetida sola, pasa en el iPhone y en el
      simulador.
- **Lección:** por Wi-Fi el iPhone tiene que llevar el Bloqueo automático en «Nunca», o la corrida
  se cae sin decirlo.
- Preferencias de los dos aparatos, idénticas antes y después. Las copias quedaron en el scratchpad
  de la sesión 059c0f73.

## Cuando Iván tenga el iPhone y el iPad en casa
- La suite completa en los dos, cada aparato con su `TMPDIR`: ver §0.-24.
- **Con el iPhone boca abajo** si se prueba el candado, porque Face ID desbloquea la app solo.
- Ver en el aparato los botones de la hoja de culto y del corte, y la página 2 de la hoja: hace
  falta un culto con más de 11 puntos de orden.
- `testEnIPadSigueLaTabla` falla en el simulador y pasaba en el iPad físico.
- Sembrar los CSV en los aparatos para las pruebas de importar.

## Pequeños pendientes
- Quitar `Tamio/Views/Components/LogoMembrete.swift` del `.pbxproj`: quedó vacío.
- El ancla de «Compartir» del Mac está copiada tres veces (Reportes, Actas y Corte). Merece un
  archivo común.
- La vista previa del acta y de la carta en iOS en modo oscuro: sin comprobar.
- Las pruebas que escriben en la iglesia en cada corrida, como `DobleToque`: ¿pasarlas a la
  maqueta?
- Las notas para el revisor de Apple: la cuenta sale como «Courtesy» y debe explicarse con la
  3.1.3(c) (`docs/APP-STORE.md`).

## «Trae tus datos» · 23-sep, noche

El encargo está en `docs/ENCARGO-TRAE-TUS-DATOS.md`, y el handoff llegó como
`Artifact_link_no_accesible-handoff.zip` (`Trae tus datos.dc.html`). Iván eligió **P2a** para el
iPad: dos columnas, como el Mac.

**Hecho en el Mac** (visto con capturas y comprobado en Supabase):
- **La invitación (M1)** después de la bienvenida. Solo sale si la primera bajada terminó bien, el
  padrón está vacío y quien entra tiene `administraPadron`. En DEBUG se abre con
  `-mostrarTraerDatos YES`.
- **La hoja de importar personas (M2 a M4, M8, M9):**
  - el resumen en una franja fija arriba;
  - el filtro por motivo cuando hay más de 10 omitidas;
  - «Hecho» dentro de la misma hoja;
  - una barra de progreso mientras importa;
  - «Nada que importar» cuando no hay filas válidas.
- **El aviso de archivo que no es CSV o está vacío (M7).**
- **Donde vive después:** Archivo › Importar personas… ⇧⌘I, el estado vacío de Membresía (M6) y
  Configuración › Datos.
- **La plantilla** se descarga y se reconoce entera. Tres de sus columnas no eran alias; ahora sí,
  con una prueba nueva.
- **Tres fallos encontrados y arreglados:**
  - Membresía no se enteraba de la importación;
  - un PDF se «leía» como CSV de basura;
  - las columnas de la plantilla que no se reconocían.

**Los aportes, decididos por Iván el 23-sep:** entran como **ingresos ya cerrados**, con un corte
histórico por importación.
- El importador del iPhone **no guardaba nada en la app real**: escribía los aportes en la ficha y
  la base los calcula de los ingresos (`AportanteFila.swift:6`). Ahora
  `MiembrosViewModel.importarAportes`, compartido, crea un ingreso por aporte: aprobado, con
  constancia anual y enlazado por `memberUid`.
- Todos esos ingresos van a un corte «Aportes importados · archivo.csv», ya depositado y sin
  ficha de depósito. Así no suman al efectivo de hoy ni piden depósito. Hay 5 cortes así en
  Supabase, con lo que el web ya lo conoce.
- **Cada aporte toma un folio** del contador del servidor, como cualquier ingreso: la serie de
  recibos avanza tantos como aportes se importan.
- La huella de duplicados compara el concepto por su clave del catálogo («Diezmo» = «diezmo» =
  «Tithe»). Antes, reimportar no reconocía nada.
- En el Mac: la hoja M5 (el total y su reparto por año en la franja, y la cifra en el botón),
  Archivo › Importar aportes…, Configuración › Datos, la tarjeta del «Hecho» de personas y las
  dos plantillas (`guardarAmbas`).
- Comprobado: 3 aportes de prueba llegaron a Supabase dentro del corte depositado; Inicio siguió
  en $600 en caja; reimportar dio «3 ya registrados». 22 pruebas de unidad en verde.

**Datos de prueba que quedaron en la iglesia:**
- las personas «PRUEBA Trae Datos Uno», «Dos», «Tres» y «Cuatro»;
- 3 ingresos, con folios 17, 18 y 19;
- el corte «Imported gifts · aportes-prueba.csv».

**iPhone e iPad, hechos el 23-sep por la noche** (vistos en los simuladores; P2a en el iPad):
- `ImportarAportantesView.swift` tiene ahora la invitación (I1 · P1) y el importador colgado de la
  raíz (`ImportarDatosIOS`, con el testigo `Navegacion.pidiendoImportar`). Tiene también la hoja
  `HojaImportarIOS`:
  - en el iPhone, «Columnas» y «Revisar» con el botón abajo, y el «Hecho» con la tarjeta de aportes
    (I2, I3, I6, I7, I10);
  - en el iPad, las dos columnas (P2a, P3, P4).
- `ImportarAportesView.swift` tiene ahora Ajustes › Datos del iPhone y el padrón vacío (I8).
  Ajustes › Datos del iPad está en `ConfiguracionView` (P5).
- La invitación sale una vez por aparato (`PreferenciasApp.traerDatosOfrecido`), después de la
  primera bajada y de la configuración inicial. En DEBUG se fuerza con `-mostrarTraerDatos YES`.
- Visto: los aportes importados desde el Mac bajaron al iPhone y ahí salen como «ya registrados».
- Pruebas de interfaz `ImportarIPad` e `ImportarTelefono` adaptadas: el iPad ya no tiene
  «Continue».

**Falta:**
- **Una caída del Mac, que no se reproduce:** a las 10:43 del 23-sep, un bucle de restricciones de
  AppKit (`_postWindowNeedsUpdateConstraints`) al cambiar de sección, con la pantalla en 4K.
  Informe: `~/Library/Logs/DiagnosticReports/Tamio-2026-09-23-104349.ips`.
  - Buscada el 24-sep en la versión actual y en la de antes del arreglo de Informes (`694eee8`,
    compilada aparte). En las 15 secciones: estrechando y ensanchando, con el inspector abierto y
    cerrado, con la ventana contra el borde, con clics reales y con el AppleScript de la barra
    lateral. Ninguna se cayó, así que la hipótesis de Informes no se confirmó.
  - Si vuelve a pasar, mirar si la pantalla era la 4K.
- **Sin ver en pantalla:** el padrón vacío (la iglesia tiene padrón) y el aviso de sin conexión
  del «Hecho».
- **El concepto vacío** de un aporte sigue saliendo como «Aporte», que no es categoría del
  catálogo: se decide cuando haya un archivo real.
