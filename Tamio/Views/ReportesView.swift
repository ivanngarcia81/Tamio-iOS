import SwiftUI
import Charts

/// Pantalla Reportes: lista de tipos de reporte + vista previa.
///
/// **En el teléfono la pantalla no existía.** El maestro-detalle se resolvía
/// solo por ancho: en iPad pintaba la columna y el reporte, y en iPhone
/// únicamente la lista, cuyas filas usaban `onTapGesture` para mover una
/// selección que allí no se veía. Tocar "Estado financiero" pintaba la fila de
/// verde y nada más: no había forma de llegar al reporte, ni al PDF, ni a
/// compartirlo. Ahora la rama compacta empuja el detalle, como Ingresos y
/// Depósitos, y los controles del reporte suben a la barra.
struct ReportesView: View {
    @State private var vm = ReportesViewModel()
    @State private var mostrarPDF = false
    /// El reporte abierto en el teléfono (empujado en la pila).
    @State private var abierto: ReporteTipo?
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// `Paleta.sobre` no lo puede leer solo: ver su comentario.
    @Environment(\.colorScheme) private var esquema

    /// Ver `MovimientosView`: la barra es de la pantalla entera, así que subir
    /// los controles solo tiene sentido cuando la pantalla ES el reporte.
    private var compacto: Bool { sizeClass == .compact }

    /// **Teléfono de verdad, no solo ancho compacto.** Las tarjetas son un
    /// rediseño de iPhone; el iPad se queda con su lista y su columna, también
    /// en Slide Over, donde el `sizeClass` es compacto pero la pantalla sigue
    /// siendo la del iPad. Mismo criterio que en `CartasView`.
    private var esTelefono: Bool {
        sizeClass == .compact && UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        pantalla
            .encabezadoNav(L.t("Reportes", "Reports"), L.t("Listos para imprimir o compartir", "Ready to print or share"))
            .navigationBarTitleDisplayMode(.large)
            .task { await vm.cargar() }
    }

    @ViewBuilder
    private var pantalla: some View {
        if esTelefono {
            tarjetasReportes
                .navigationDestination(item: $abierto) { t in
                    detalleCompacto(t)
                }
        } else {
            columnas
        }
    }

    private var columnas: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    listaColumna(empuja: false).frame(width: Esp.columnaMaestra)
                    Divider()
                    preview
                }
            } else {
                // **Quien decide si la fila empuja es el ANCHO, no la clase de
                // tamaño.** Iba por `compacto`, así que en un iPad con la
                // columna estrecha —el mini en vertical con la sidebar, la app
                // a la mitad— la fila movía la selección de un panel que no se
                // dibuja: se pintaba de verde y no llevaba a ninguna parte. Es
                // la misma pregunta que ya responde este `GeometryReader`.
                listaColumna(empuja: true)
                    .navigationDestination(item: $abierto) { t in
                        detalleCompacto(t)
                    }
            }
        }
    }

    // MARK: - Tarjetas (teléfono)

    /// **Dos tarjetas, no un carrusel.** Cartas tiene dieciséis plantillas y
    /// por eso allí se arrastra; aquí los reportes son DOS. Un carrusel con dos
    /// tarjetas promete una colección que no existe: esconde la mitad de la
    /// pantalla para que la busques, y sus flechas y sus puntos ocupan sitio
    /// para decir "hay dos". Se ven las dos a la vez, que es lo que el carrusel
    /// haría si cupiera.
    ///
    /// Si algún día son cinco o más, el carrusel de `CartasView` se copia tal
    /// cual: la tarjeta es la misma pieza.
    private var tarjetasReportes: some View {
        VStack(spacing: 16) {
            // Centradas, que es lo que hace el carrusel de Cartas: al dejar de
            // estirarse el par necesita decidir dónde se apoya, y pegarlas
            // arriba deja todo el hueco de una vez al fondo.
            Spacer(minLength: 12)
            ForEach(vm.tipos) { t in
                tarjetaReporte(t)
            }
            Spacer(minLength: 12)
        }
        .padding(.horizontal, Esp.pantalla)
        .padding(.vertical, Esp.pantalla)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        // **La hoja de PDF necesita su propio `sheet` aquí.** Los que ya
        // existen cuelgan de `estadoFinanciero` y `reporteAnual`, o sea del
        // reporte ya abierto: desde las tarjetas no hay ninguno montado, y
        // encender `mostrarPDF` desde el menú no habría hecho nada.
        .sheet(isPresented: $mostrarPDF) {
            if vm.seleccionId == "anual", let a = vm.anual {
                ReporteAnualPDFSheet(a: a)
            } else if let e = vm.estado {
                ReportePDFSheet(e: e)
            }
        }
    }

    private func tarjetaReporte(_ t: ReporteTipo) -> some View {
        let tono = color(de: t)
        // **Sin botón dentro.** "Ver reporte" hacía exactamente lo mismo que
        // tocar la tarjeta, y no nombraba nada que el título no dijera ya: la
        // tarjeta se llama "Reporte anual" y tocarla lleva al reporte anual.
        // Un botón dentro de una tarjeta que ya es tocable se gana el sitio
        // cuando hace algo DISTINTO —"Redactar" en Cartas sí, porque dice el
        // verbo que la tarjeta no dice—, y además esa misma orden ya está en
        // el menú de mantener pulsado: estaba tres veces en la misma tarjeta.
        // **Un `Button` de verdad.** Traía el botón rehecho a mano, como la
        // tarjeta de Cartas: `contentShape` + `onTapGesture` para el toque, y
        // `accessibilityAddTraits(.isButton)` + `accessibilityAction` para que
        // VoiceOver la diera por activable.
        //
        // **Pero no comparte el hundido, y eso importa.** Aquí la pulsación
        // larga la tiene el `contextMenu` —que enseña la previa del PDF—, y el
        // menú trae su propia vibración y su propia animación de levantar la
        // tarjeta. Por eso este botón va con `.tarjeta(hunde: false)`: necesita
        // la semántica, no el efecto. Un `.plain` tampoco valdría, porque pinta
        // su propio apagado al apretar.
        // **La tarjeta ES el color, y el contenido va encima.** Es el patrón de
        // los widgets de color de iOS —el de Música— que trajo Iván, en vez del
        // de los grises de Claude y Grok: aquel es un racimo de tres controles
        // y estas tarjetas tienen una acción, y además perdería el color por
        // tipo, que aquí significa algo.
        //
        // **La tinta no se elige, se calcula.** `Paleta.sobre` la saca de la
        // luminancia del fondo, igual que en las placas de icono. Aquí los dos
        // tonos dan blanco —medido: 6.28:1 el verde de la casa y 5.70:1 el
        // morado, contra la meta de 5— pero escribir `.white` a mano sería
        // atarlo a que los reportes sigan siendo estos dos: de los siete tonos
        // de Cartas, CUATRO piden tinta negra.
        //
        // **Y el relleno es plano, sin degradado.** Un velo blanco encima
        // aclara el fondo y tira abajo el contraste que se acaba de medir, y un
        // velo negro rompe los tonos claros. Lo medido es el color liso; que
        // sea eso lo que se pinta.
        let tinta = Paleta.sobre(tono, esquema)
        return Button { abrir(t) } label: {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: icono(de: t))
                    .font(.system(size: 26))
                    .frame(width: 60, height: 60)
                    .background(tinta.opacity(0.18),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.titulo)
                        .font(.title3.weight(.bold))
                        .lineLimit(2).minimumScaleFactor(0.8)
                    Text(t.subtitulo)
                        .font(.subheadline).opacity(0.85)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            // **Nada de `Spacer` aquí.** Un `Spacer` es voraz: con él la
            // tarjeta se comía todo el alto que el padre le ofreciera y
            // quedaba medio vacía en el centro, aunque el suelo fuera 170.
            // Medido en el simulador, no leído: con `Spacer` la tarjeta salía
            // de 470 pt para 180 de contenido.
            botonPrevia(t, tono: tono, tinta: tinta)
        }
        // A la izquierda y no centrado: con una cápsula de acción abajo, el
        // texto centrado sobre un botón alineado deja la tarjeta descuadrada
        // —es lo mismo que ya se anotó en la tarjeta de Cartas, al revés—.
        .foregroundStyle(tinta)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        // **Alto por contenido, no repartido.** Antes llevaban
        // `maxHeight: .infinity` y se estiraban a todo el alto de la pantalla:
        // con el contenido arriba y la cápsula abajo quedaba media tarjeta
        // vacía en medio. El suelo se queda para que con el texto grande de
        // Accesibilidad no se aplaste.
        .frame(minHeight: 170)
        .background(tono, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        // **Dos sombras, y medidas contra el widget.** La de antes —una sola,
        // 10 % a radio 15— oscurecía el fondo un 16.9 % justo bajo el borde;
        // en la galería de widgets que trajo Iván la misma medida da 47.1 % y
        // tarda unos 60 pt en volver al fondo. Por eso la tarjeta parecía
        // pegada al fondo y el widget levantado. La corta define el borde y la
        // larga hace la profundidad; una sola no da las dos cosas.
        .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
        .shadow(color: .black.opacity(0.20), radius: 26, y: 14)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        // **Mantener pulsado enseña la hoja del PDF.** Aquí sí gana a abrir
        // directamente —que es lo que hace la tarjeta de Cartas—: el reporte
        // se imprime y se comparte, así que ojear la hoja antes de entrar es
        // la pregunta que uno trae. Una plantilla de carta, en cambio, se
        // rellena; verla en pequeño no adelanta nada.
        //
        // El `contextMenu` se queda con la pulsación larga, así que NO puede
        // convivir con un `onLongPressGesture` propio. También trae su propia
        // vibración y su propia animación de levantar la tarjeta, que es por
        // lo que aquí no hay `sensoryFeedback` ni `scaleEffect` a mano.
        .contextMenu {
            Button { abrir(t) } label: {
                Label(L.t("Ver reporte", "View report"),
                      systemImage: "chart.bar.doc.horizontal")
            }
            Button { vm.seleccionId = t.id; mostrarPDF = true } label: {
                Label(L.t("Vista previa PDF", "PDF preview"),
                      systemImage: "doc.richtext")
            }
            .disabled(!hayHoja(t))
        } preview: {
            hojaPrevia(t)
        }
        // **La tarjeta entera se lee de una pieza.** Lo que ya no hace falta es
        // decir que es un botón ni darle una acción a mano: lo es de verdad
        // desde que el envoltorio es un `Button`.
        }
        .buttonStyle(.tarjeta(hunde: false))
        .accessibilityElement(children: .combine)
    }

    /// Si hay cifras con las que dibujar la hoja. **La ventana se abre igual
    /// cuando no las hay** —el sistema no deja negarse a enseñarla—, así que en
    /// vez de una ventana en blanco dice por qué está vacía, que es lo mismo
    /// que hace el reporte al abrirse.
    /// **La cápsula de acción del estilo de widget** —el "Play" del de Música—.
    ///
    /// Hace algo DISTINTO de tocar la tarjeta, que es la condición que este
    /// mismo archivo le puso en su día a "Ver reporte" antes de quitarlo por
    /// repetirse: la tarjeta abre el reporte y la cápsula enseña la hoja del
    /// PDF. Y de paso saca a la luz lo que hasta ahora solo salía manteniendo
    /// pulsado, que no se descubre solo.
    ///
    /// **Rellena de `tinta`, con el rótulo en `tono`; no translúcida.** Una
    /// cápsula de `tinta.opacity(0.2)` sobre el color aclara el fondo y hunde
    /// el contraste del rótulo por debajo del mínimo. Así se queda en la misma
    /// cifra ya medida de la tarjeta. Es además la píldora blanca con texto
    /// verde que ya usa la pantalla de acceso.
    private func botonPrevia(_ t: ReporteTipo, tono: Color, tinta: Color) -> some View {
        Button { vm.seleccionId = t.id; mostrarPDF = true } label: {
            Label(L.t("Vista previa PDF", "PDF preview"), systemImage: "doc.richtext")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tono)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(tinta, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!hayHoja(t))
        .opacity(hayHoja(t) ? 1 : 0.45)
        .accessibilityLabel(L.t("Vista previa PDF de \(t.titulo)",
                                "PDF preview of \(t.titulo)"))
    }

    private func hayHoja(_ t: ReporteTipo) -> Bool {
        t.id == "anual" ? vm.anual != nil : vm.estado != nil
    }

    /// La hoja del PDF encogida al ancho del teléfono, que es exactamente lo
    /// que enseña "Vista previa PDF". No se dibuja un reporte aparte para la
    /// ventana: es la misma pieza (`ReporteHojaPDF` dentro de
    /// `HojaCartaEscalada`) que usa la hoja de verdad.
    @ViewBuilder
    private func hojaPrevia(_ t: ReporteTipo) -> some View {
        if t.id == "anual", let a = vm.anual {
            HojaCartaEscalada { ReporteAnualHojaPDF(a: a) }
                .frame(width: 320)
        } else if t.id != "anual", let e = vm.estado {
            HojaCartaEscalada { ReporteHojaPDF(e: e) }
                .frame(width: 320)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 34)).foregroundStyle(.tertiary)
                Text(vm.cargando
                     ? L.t("Preparando el reporte…", "Preparing the report…")
                     : L.t("Todavía no hay cifras para esta hoja",
                           "No figures for this sheet yet"))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(width: 320)
        }
    }

    private func abrir(_ t: ReporteTipo) {
        vm.seleccionId = t.id
        abierto = t
    }

    /// Color e icono por reporte. **Los dos símbolos ya se usan en el
    /// proyecto**, que es como se comprueba que existen: aquí ya hubo un
    /// `doc.badge.checkmark` inventado que salía en blanco.
    ///
    /// Los acentos son los de la paleta de categorías, como en las tarjetas de
    /// Cartas. Lo que no se reconozca cae en el verde de marca y el icono de
    /// estado, que es el reporte por omisión del view model.
    private func color(de t: ReporteTipo) -> Color {
        t.id == "anual" ? Paleta.morado : Paleta.brand
    }

    private func icono(de t: ReporteTipo) -> String {
        t.id == "anual" ? "calendar" : "chart.bar.doc.horizontal"
    }

    // MARK: - Lista de reportes

    private func listaColumna(empuja: Bool) -> some View {
        List {
            Section {
                ForEach(vm.tipos) { t in
                    filaReporte(t, empuja: empuja)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.seleccionId = t.id
                            if empuja { abierto = t }
                        }
                }
            } header: {
                // Sin `.foregroundStyle(.secondary)`, por lo mismo que en
                // Ingresos: doblar el secundario deja el rótulo en 1.78:1.
                Text(L.t("Tesorería", "Treasury"))
                    .font(.caption.weight(.semibold))
                    .textCase(nil)
            }
        }
        // Las dos ramas en `.plain`: el margen lo pone `filaDeLista`.
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Paleta.sueloLista(columna: !compacto))
    }

    private func filaReporte(_ t: ReporteTipo, empuja: Bool) -> some View {
        // En iPad la fila marca la selección de la columna; en el teléfono
        // lleva a otra pantalla, y eso se dice con un chevrón. Pintarla de
        // verde allí sería anunciar una selección que no se queda a la vista.
        let sel = !empuja && t.id == vm.seleccionId
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.titulo).font(.subheadline.weight(.semibold))
                    .foregroundStyle(sel ? Paleta.brand : .primary)
                Text(t.subtitulo).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if empuja {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        // La selección persistente es idioma de iPad, donde la lista y el
        // detalle conviven. En el teléfono la fila NAVEGA, y al volver se
        // quedaba pintada como si siguiera abierta —y en la bitácora de cultos
        // encima prometía algo que el menú "Acciones" niega a propósito: sus
        // tres acciones se apagan porque no hay culto delante—. Misma línea que
        // ya llevan Ingresos y Aportantes.
        .filaDeLista(seleccionada: sel, columna: !compacto)
    }

    // MARK: - Detalle en el teléfono

    /// **La barra va sin título.** Con el nombre del reporte puesto ahí, el
    /// sistema no encontraba sitio para la segunda cápsula y se llevaba la
    /// categoría al menú "···" — un filtro escondido detrás de tres puntos no
    /// dice qué se está viendo, que es justo para lo que está arriba. El
    /// nombre pasa a encabezar el contenido, como en el detalle de un
    /// movimiento.
    private func detalleCompacto(_ t: ReporteTipo) -> some View {
        contenido(t, titulo: t.titulo, empujado: true)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barraCompacta }
    }

    /// **Todo arriba: el filtro y las dos acciones.** Estaban repartidos entre
    /// la barra (el periodo) y una barra inferior propia (PDF y compartir), con
    /// el saldo repetido en una cápsula que ya daba el chip "Saldo final".
    ///
    /// **El mes y la categoría comparten un único menú.** Con las dos cápsulas
    /// más las dos acciones no cabe nada, y son la misma pregunta —qué recorte
    /// del dato estoy viendo—, así que salen del mismo sitio en dos secciones.
    /// La etiqueta dice el mes, y añade la categoría solo cuando hay una
    /// puesta: un chip que dijera siempre "Todas las categorías" gastaría el
    /// ancho en decir que no filtra.
    ///
    /// Compartir y PDF van en un `ToolbarItemGroup`, que **funde las dos
    /// cápsulas en una**: las dos sacan el reporte de la pantalla.
    @ToolbarContentBuilder
    private var barraCompacta: some ToolbarContent {
        // El anual se filtra por AÑO y no admite categoría: enseñar ahí un
        // filtro que no hace nada es peor que no enseñarlo.
        if vm.esAnual {
            if vm.anual != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    menuAnio { chipFiltro(vm.anioSel) }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    accionCompartir(vm.resumenAnual)
                    accionPDF
                }
            }
        } else if vm.estado != nil {
            ToolbarItem(placement: .topBarTrailing) {
                menuFiltros { chipFiltro(etiquetaFiltro) }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                accionCompartir(vm.resumenTexto)
                accionPDF
            }
        }
    }

    /// Mes y categoría en un solo menú, en dos secciones.
    private func menuFiltros<E: View>(@ViewBuilder etiqueta: () -> E) -> some View {
        Menu {
            Section(L.t("Periodo", "Period")) {
                ForEach(vm.periodos) { p in
                    Button { Task { await vm.seleccionarPeriodo(p.clave) } } label: {
                        if p.clave == vm.periodoSel { Label(p.etiqueta, systemImage: "checkmark") }
                        else { Text(p.etiqueta) }
                    }
                }
            }
            Section(L.t("Categoría", "Category")) {
                Button { Task { await vm.seleccionarCategoria(nil) } } label: {
                    if vm.categoriaSel == nil { Label(L.t("Todas", "All"), systemImage: "checkmark") }
                    else { Text(L.t("Todas", "All")) }
                }
                ForEach(vm.categorias, id: \.self) { c in
                    Button { Task { await vm.seleccionarCategoria(c) } } label: {
                        if c == vm.categoriaSel { Label(c, systemImage: "checkmark") } else { Text(c) }
                    }
                }
            }
        } label: { etiqueta() }
    }

    private var etiquetaFiltro: String {
        guard let c = vm.categoriaSel else { return vm.periodoEtiqueta }
        return "\(vm.periodoEtiqueta) · \(c)"
    }

    private func accionCompartir(_ texto: String) -> some View {
        ShareLink(item: texto) {
            Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
        }
        // Sin `.buttonStyle(.glass)`: vive en el `toolbar`, donde la cápsula la
        // pone el sistema. Ver `chipFiltro`.
        .tint(Color.secondary)
    }

    private var accionPDF: some View {
        Button { mostrarPDF = true } label: {
            Label(L.t("Vista previa PDF", "PDF preview"), systemImage: "doc.text")
        }
        // Solo el icono: con la palabra al lado del mes y del compartir se sale
        // por el borde —se leía "F"—. Aquí no hace falta, al contrario que en
        // "Editar": estas dos son acciones hermanas, y el verde ya distingue
        // cuál es la principal.
        .labelStyle(.iconOnly)
        .tint(Paleta.brand)
    }

    /// Año: el filtro del reporte anual.
    private func menuAnio<E: View>(@ViewBuilder etiqueta: () -> E) -> some View {
        Menu {
            ForEach(vm.anios, id: \.self) { a in
                Button { Task { await vm.seleccionarAnio(a) } } label: {
                    if a == vm.anioSel { Label(a, systemImage: "checkmark") } else { Text(a) }
                }
            }
        } label: { etiqueta() }
    }

    // MARK: - Vista previa

    /// La columna derecha del iPad: el reporte que marque la selección.
    @ViewBuilder
    private var preview: some View {
        if let t = vm.seleccion { contenido(t) } else { EmptyView() }
    }

    @ViewBuilder
    private func contenido(_ t: ReporteTipo, titulo: String? = nil,
                           empujado: Bool = false) -> some View {
        if vm.sinDatos {
            // No es que el reporte esté vacío: es que no hay movimientos
            // aprobados con los que hacerlo.
            ContentUnavailableView(
                L.t("Todavía no hay nada que reportar", "Nothing to report yet"),
                systemImage: "chart.bar.doc.horizontal",
                description: Text(L.t("Los reportes salen de los movimientos aprobados. Captura ingresos y gastos, o dales el visto bueno en Por revisar.",
                                      "Reports are built from approved transactions. Record income and expenses, or approve them in To review.")))
        } else if t.id == "estado", let e = vm.estado {
            estadoFinanciero(e, titulo: titulo, empujado: empujado)
        } else if t.id == "anual", let a = vm.anual {
            reporteAnual(a, titulo: titulo, empujado: empujado)
        } else if vm.cargando {
            // **Aquí ponía "Próximamente · Este reporte llega en un próximo
            // slice".** Los tipos de reporte son dos, "estado" y "anual", y los
            // dos están hechos: a esta rama solo se llega mientras las cifras
            // se cargan, o cuando el año elegido no tiene ninguna. O sea que la
            // pantalla anunciaba una función que no falta, durante el segundo
            // en que lo único que pasaba era que estaba trabajando.
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let cuando = t.id == "anual" ? vm.anioSel : vm.periodoEtiqueta
            ContentUnavailableView(
                L.t("Sin datos para \(cuando)", "No data for \(cuando)"),
                systemImage: "chart.bar.doc.horizontal",
                description: Text(L.t("Elige otro periodo en el selector de arriba.",
                                      "Pick another period in the selector above.")))
        }
    }

    private func estadoFinanciero(_ e: EstadoFinanciero, titulo: String? = nil,
                                  empujado: Bool = false) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let titulo {
                    Text(titulo).font(.title2.weight(.bold))
                }
                // **La tira de filtros solo cuando el reporte NO está
                // empujado.** En la columna de detalle del iPad se queda aquí:
                // la barra es de la pantalla entera y allí compartiría sitio
                // con la sidebar. Cuando el reporte se empuja —el teléfono, y
                // también un iPad con la columna estrecha— la pantalla ES el
                // reporte y sus controles suben a la barra, así que dibujar
                // también la tira los pone dos veces, y la segunda con "PDF
                // preview" partido en tres renglones.
                if !empujado { barraFiltros }
                HStack {
                    TituloSeccion(texto: L.t("RESUMEN EN PANTALLA", "ON-SCREEN SUMMARY"))
                    Spacer()
                    Text(L.t("No se incluye en el PDF", "Not included in the PDF")).font(.caption).foregroundStyle(.tertiary)
                }
                chips(e)
                if e.pendientes > 0 { avisoPendientes(e) }
                tarjetas(e)
                tablaMensual(e)
            }
            .padding(compacto ? Esp.pantalla : Esp.panel)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
        .sheet(isPresented: $mostrarPDF) { ReportePDFSheet(e: e) }
    }

    /// **Lo que el reporte deja fuera, dicho en el reporte.** Solo cuentan los
    /// movimientos aprobados; sin este aviso, la diferencia contra la pantalla
    /// de Ingresos —que sí enseña los pendientes— parece un error de la app.
    private func avisoPendientes(_ e: EstadoFinanciero) -> some View {
        HStack(spacing: Esp.hueco) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Paleta.Estado.pendiente.color)
            Text(e.pendientes == 1
                 ? L.t("1 movimiento de este mes espera visto bueno y no está en estas cifras.",
                       "1 transaction this month is awaiting approval and isn't in these figures.")
                 : L.t("\(e.pendientes) movimientos de este mes esperan visto bueno y no están en estas cifras.",
                       "\(e.pendientes) transactions this month are awaiting approval and aren't in these figures."))
                .font(.footnote)
            Spacer()
        }
        .padding(Esp.chip)
        .background(Paleta.avisoFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// **Una fila si cabe, dos si no.** En la columna del iPad grande los
    /// cuatro controles caben de sobra; en una columna estrecha —el mini, la
    /// app a la mitad, el 13" en vertical— no, y el sistema no los baja solos:
    /// apretaba las cápsulas hasta partir "PDF preview" en dos renglones y
    /// recortar el mes a "Septembe…". Bajar las acciones a su propia fila deja
    /// las cuatro etiquetas enteras.
    private var barraFiltros: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                filtrosDelEstado
                Spacer()
                accionesDelEstado
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) { filtrosDelEstado; Spacer() }
                HStack(spacing: 10) { Spacer(); accionesDelEstado }
            }
        }
    }

    @ViewBuilder
    private var filtrosDelEstado: some View {
        // El cristal se pone aquí, no en el chip: en la barra lo pone el
        // sistema y ponerlo dos veces es lo que se veía como cápsula doble.
        menuPeriodo { chipFiltro(vm.periodoEtiqueta) }.buttonStyle(.glass)
        menuCategoria { chipFiltro(vm.categoriaEtiqueta) }.buttonStyle(.glass)
    }

    @ViewBuilder
    private var accionesDelEstado: some View {
        ShareLink(item: vm.resumenTexto) {
            Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.glass)
        .tint(Color.secondary)
        Button { mostrarPDF = true } label: {
            Label(L.t("Vista previa PDF", "PDF preview"), systemImage: "doc.text").fontWeight(.semibold)
        }
        .buttonStyle(.glass).tint(Paleta.brand)
    }

    /// Periodo: elige el mes; recarga las cifras de ese mes.
    private func menuPeriodo<E: View>(@ViewBuilder etiqueta: () -> E) -> some View {
        Menu {
            ForEach(vm.periodos) { p in
                Button { Task { await vm.seleccionarPeriodo(p.clave) } } label: {
                    if p.clave == vm.periodoSel { Label(p.etiqueta, systemImage: "checkmark") }
                    else { Text(p.etiqueta) }
                }
            }
        } label: { etiqueta() }
    }

    /// Categoría: acota la dona y el ingreso a una categoría (o todas).
    private func menuCategoria<E: View>(@ViewBuilder etiqueta: () -> E) -> some View {
        Menu {
            Button { Task { await vm.seleccionarCategoria(nil) } } label: {
                if vm.categoriaSel == nil { Label(L.t("Todas las categorías", "All categories"), systemImage: "checkmark") }
                else { Text(L.t("Todas las categorías", "All categories")) }
            }
            Divider()
            ForEach(vm.categorias, id: \.self) { c in
                Button { Task { await vm.seleccionarCategoria(c) } } label: {
                    if c == vm.categoriaSel { Label(c, systemImage: "checkmark") } else { Text(c) }
                }
            }
        } label: { etiqueta() }
    }

    /// **Solo el contenido: la cápsula la pone quien lo usa.**
    ///
    /// Se pintaba su propia cápsula con `Color(.tertiarySystemFill)`, opaca. En
    /// la BARRA eso era doblemente malo: el sistema ya pone una cápsula de
    /// cristal a un `Menu` de `toolbar`, así que salía un pastilla gris DENTRO
    /// de ella —lo vio Iván en el reporte anual y en el estado financiero— y
    /// además un relleno opaco dentro del cristal es justo lo que la regla
    /// prohíbe, porque no deja nada que refractar.
    ///
    /// En el cuerpo sí hace falta una cápsula, pero de cristal: se la pone el
    /// sitio de uso con `.buttonStyle(.glass)`, como con los demás controles
    /// que viven en los dos lados.
    private func chipFiltro(_ t: String) -> some View {
        HStack(spacing: 4) {
            Text(t).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.subheadline)
    }

    // MARK: - Chips KPI

    private func chips(_ e: EstadoFinanciero) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { chipsLista(e) }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { chipsLista(e) }
        }
    }

    /// **El cuarto chip es el saldo final, no el balance del mes pasado.** Era
    /// "Mes anterior", que repetía una cifra que la tabla ya da y dejaba fuera
    /// la única que responde "¿cuánto tiene la iglesia?".
    @ViewBuilder
    private func chipsLista(_ e: EstadoFinanciero) -> some View {
        chipKPI(L.t("Ingresos del mes", "Income this month"), e.ingresosMes, Paleta.brand,
                delta: e.deltaIngresos, invert: false, sufijo: L.t("vs mes anterior", "vs last month"))
        chipKPI(L.t("Gastos del mes", "Expenses this month"), e.gastosMes, Paleta.negativo,
                delta: e.deltaGastos, invert: true, sufijo: L.t("vs mes anterior", "vs last month"))
        chipKPI(L.t("Balance neto", "Net balance"), e.balanceNeto, Paleta.brand,
                delta: e.deltaBalance, invert: false, sufijo: L.t("vs mes anterior", "vs last month"))
        // El saldo final no compara con nada: su renglón es una leyenda que se
        // sostiene sola, y por eso va en `nota` y no en `sufijo`.
        chipKPI(L.t("Saldo final", "Ending balance"), e.saldoFinal, Paleta.morado,
                delta: nil, invert: false, sufijo: "",
                nota: L.t("con el saldo anterior", "including previous balance"))
    }

    /// **`sufijo` acompaña a la variación; `nota` se sostiene sola.** Eran el
    /// mismo parámetro, así que cuando no había con qué comparar —el mes
    /// anterior a cero, que es el primer mes de cualquier iglesia— el chip
    /// enseñaba "vs mes anterior" a secas, sin flecha y sin porcentaje: una
    /// preposición colgando debajo de una cifra.
    ///
    /// Sin variación el renglón se queda vacío pero **sigue ocupando su alto**,
    /// como el hueco de la etiqueta en las filas de Ingresos: si desapareciera,
    /// los cuatro chips de la rejilla dejarían de medir lo mismo y el que sí
    /// compara quedaría más alto que sus vecinos.
    private func chipKPI(_ titulo: String, _ monto: Centavos, _ color: Color,
                         delta: Double?, invert: Bool, sufijo: String,
                         nota: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            AmountText(cents: monto, size: 22)
            Group {
                if let delta {
                    DeltaBadge(pct: delta, sufijo: sufijo, invert: invert)
                } else if let nota {
                    Text(nota).foregroundStyle(.secondary)
                } else {
                    Text(" ").hidden()
                }
            }
            .font(.caption).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Esp.tarjeta)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 2).fill(color).frame(height: 3).padding(.horizontal, Esp.chip) }
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(.separator), lineWidth: 0.75))
    }

    // MARK: - Tarjetas

    private func tarjetas(_ e: EstadoFinanciero) -> some View {
        // Rejilla adaptable: cada tarjeta mínimo 260pt de ancho → 3 en 12.9",
        // 2 o 1 en 11". Evita que la dona y su leyenda queden aplastadas.
        //
        // **`alignment: .top`, o la fila se descuadra.** Sin él la rejilla
        // centra cada celda en el alto de su fila, y como las tarjetas no
        // miden lo mismo —"Saldo del periodo" 513 pt contra los 497 de la
        // dona— la de al lado empezaba ocho píxeles más abajo. Se ve como un
        // escalón entre dos tarjetas que deberían arrancar a la misma altura.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16, alignment: .top)],
                  spacing: 16) {
            tarjetaSaldo(e)
            CategoryDonutChart(categorias: e.composicion, mesCorto: e.composicionMesCorto)
            tarjetaGastos(e)
            if !e.depositos.isEmpty { tarjetaDepositos(e) }
        }
    }

    private func tarjetaSaldo(_ e: EstadoFinanciero) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 8) {
                TituloSeccion(texto: L.t("SALDO DEL PERIODO", "PERIOD BALANCE"))
                AmountText(cents: e.balanceNeto, size: 26)
                Chart(e.saldoSerie) { m in
                    BarMark(x: .value("Mes", m.mes), y: .value("Saldo", m.monto))
                        .foregroundStyle(m.mes == e.saldoSerie.last?.mes ? Paleta.brand : Paleta.brandMuted)
                        .cornerRadius(3)
                }
                .chartYAxis(.hidden).frame(height: 70)
            }
        }
    }

    /// **Gastos por categoría, con el porcentaje medido contra el INGRESO.**
    /// Sustituye a "gasto contra presupuesto", que enseñaba cuatro porcentajes
    /// fijos de un presupuesto que en Tamio no existe. El % contra el ingreso
    /// es el de la app web, y es el que informa: "mantenimiento fue el 12% de
    /// lo que entró" dice algo; "% de lo que gastamos" no dice nada nuevo.
    private func tarjetaGastos(_ e: EstadoFinanciero) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                TituloSeccion(texto: L.t("GASTOS POR CATEGORÍA", "EXPENSES BY CATEGORY"))
                AmountText(cents: e.gastoTotal, size: 26)
                if e.gastosPorCategoria.isEmpty {
                    Text(L.t("Sin gastos en el periodo", "No expenses this period"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(e.gastosPorCategoria) { g in
                    HStack {
                        Text(g.nombre).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text(Money.fmt(g.monto)).font(.subheadline).monospacedDigit()
                        Text(porcentaje(g.monto, de: e.ingresosMes))
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
    }

    /// Los depósitos del periodo. Van con su aclaración: son traspasos de caja
    /// a banco, no ingresos, así que su total puede superar lo ingresado en el
    /// mes sin que eso sea un descuadre.
    private func tarjetaDepositos(_ e: EstadoFinanciero) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                TituloSeccion(texto: L.t("DEPÓSITOS DEL PERIODO", "PERIOD DEPOSITS"))
                AmountText(cents: e.depositosTotal, size: 26)
                ForEach(e.depositos) { d in
                    HStack {
                        Text(d.cuenta).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text(Money.fmt(d.monto)).font(.subheadline).monospacedDigit()
                    }
                }
                Text(L.t("No suman al saldo: mueven efectivo de la caja al banco.",
                         "Not added to the balance: they move cash from the box to the bank."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func porcentaje(_ parte: Centavos, de total: Centavos) -> String {
        guard total > 0 else { return "—" }
        return "\(Int((Double(parte) / Double(total) * 100).rounded()))%"
    }

    // MARK: - Reporte anual

    private func reporteAnual(_ a: ReporteAnual, titulo: String? = nil,
                              empujado: Bool = false) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let titulo { Text(titulo).font(.title2.weight(.bold)) }
                if !empujado { barraFiltrosAnual(a) }
                HStack {
                    TituloSeccion(texto: L.t("RESUMEN EN PANTALLA", "ON-SCREEN SUMMARY"))
                    Spacer()
                    Text(L.t("No se incluye en el PDF", "Not included in the PDF"))
                        .font(.caption).foregroundStyle(.tertiary)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { chipsAnual(a) }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { chipsAnual(a) }
                }
                if a.pendientes > 0 { avisoPendientesAnual(a) }
                // Ver `tarjetas`: `.top` para que las dos empiecen igual.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16, alignment: .top)],
                          spacing: 16) {
                    tablaCategorias(L.t("INGRESOS POR CATEGORÍA", "INCOME BY CATEGORY"),
                                    a.ingresosPorCategoria, total: a.totalIngresos)
                    // El % del gasto va contra el total de GASTOS y no contra
                    // el ingreso, al revés que en el mensual: aquí la pregunta
                    // es en qué se repartió el gasto del año. Es la regla de la
                    // app web.
                    tablaCategorias(L.t("GASTOS POR CATEGORÍA", "EXPENSES BY CATEGORY"),
                                    a.gastosPorCategoria, total: a.totalGastos)
                }
                tablaAnual(a)
            }
            .padding(compacto ? Esp.pantalla : Esp.panel)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
        .sheet(isPresented: $mostrarPDF) { ReporteAnualPDFSheet(a: a) }
    }

    /// Ver `barraFiltros`: una fila si cabe, dos si no.
    private func barraFiltrosAnual(_ a: ReporteAnual) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                menuAnio { chipFiltro(vm.anioSel) }.buttonStyle(.glass)
                Spacer()
                accionesDelAnual
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) { menuAnio { chipFiltro(vm.anioSel) }.buttonStyle(.glass); Spacer() }
                HStack(spacing: 10) { Spacer(); accionesDelAnual }
            }
        }
    }

    @ViewBuilder
    private var accionesDelAnual: some View {
        ShareLink(item: vm.resumenAnual) {
            Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.glass).tint(Color.secondary)
        Button { mostrarPDF = true } label: {
            Label(L.t("Vista previa PDF", "PDF preview"), systemImage: "doc.text").fontWeight(.semibold)
        }
        .buttonStyle(.glass).tint(Paleta.brand)
    }

    @ViewBuilder
    private func chipsAnual(_ a: ReporteAnual) -> some View {
        // Los cuatro del anual no comparan con nada: sus renglones son
        // leyendas que se sostienen solas, así que van en `nota`.
        chipKPI(L.t("Ingresos del año", "Income for the year"), a.totalIngresos, Paleta.brand,
                delta: nil, invert: false, sufijo: "",
                nota: L.t("\(a.meses.count) meses con movimientos",
                          "\(a.meses.count) months with activity"))
        chipKPI(L.t("Gastos del año", "Expenses for the year"), a.totalGastos, Paleta.negativo,
                delta: nil, invert: false, sufijo: "",
                nota: L.t("Todo el año", "Whole year"))
        chipKPI(L.t("Balance del año", "Year balance"), a.balance, Paleta.brand,
                delta: nil, invert: false, sufijo: "",
                nota: L.t("Ingresos menos gastos", "Income less expenses"))
        chipKPI(L.t("Depositado", "Deposited"), a.depositosTotal, Paleta.morado,
                delta: nil, invert: false, sufijo: "",
                nota: L.t("No suma al balance", "Not part of the balance"))
    }

    private func avisoPendientesAnual(_ a: ReporteAnual) -> some View {
        HStack(spacing: Esp.hueco) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Paleta.Estado.pendiente.color)
            Text(a.pendientes == 1
                 ? L.t("1 movimiento del año espera visto bueno y no está en estas cifras.",
                       "1 transaction this year is awaiting approval and isn't in these figures.")
                 : L.t("\(a.pendientes) movimientos del año esperan visto bueno y no están en estas cifras.",
                       "\(a.pendientes) transactions this year are awaiting approval and aren't in these figures."))
                .font(.footnote)
            Spacer()
        }
        .padding(Esp.chip)
        .background(Paleta.avisoFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tablaCategorias(_ titulo: String, _ filas: [CategoriaMonto], total: Centavos) -> some View {
        // Aquí las filas SON el total —ingresos contra el ingreso del año,
        // gastos contra el gasto del año— así que el porcentaje se reparte y
        // la columna suma 100. No es el caso de `tarjetaGastos`, que mide el
        // gasto del mes contra el ingreso del mes a propósito.
        let repartidos = Money.reparto(filas.map(\.monto), total: total)
        return Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                TituloSeccion(texto: titulo)
                AmountText(cents: total, size: 26)
                if filas.isEmpty {
                    Text(L.t("Sin movimientos en el año", "No activity this year"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(Array(filas.enumerated()), id: \.element.id) { i, c in
                    HStack {
                        Text(c.nombre).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text(Money.fmt(c.monto)).font(.subheadline).monospacedDigit()
                        Text(total > 0 ? "\(repartidos[i])%" : "—")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func tablaAnual(_ a: ReporteAnual) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TituloSeccion(texto: L.t("RESUMEN POR MES", "SUMMARY BY MONTH"))
            Tarjeta {
                // Misma regla que la tabla del estado financiero: la elige el
                // ancho. Aquí sin variación que ceder, así que lo que cede es
                // el ancho de las cifras. Sin esto, en una columna estrecha el
                // nombre del mes se quedaba sin sitio y salía en vertical, una
                // letra por renglón: "M / O / N / T / H".
                ViewThatFits(in: .horizontal) {
                    filasAnual(a, ancho: 112, pequena: false)
                    filasAnual(a, ancho: 74, pequena: true)
                }
            }
        }
    }

    private func filasAnual(_ a: ReporteAnual, ancho: CGFloat, pequena: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(L.t("MES", "MONTH")).frame(maxWidth: .infinity, alignment: .leading)
                Text(L.t("INGRESOS", "INCOME")).frame(width: ancho, alignment: .trailing)
                Text(L.t("GASTOS", "EXPENSES")).frame(width: ancho, alignment: .trailing)
                Text(L.t("BALANCE", "BALANCE")).frame(width: ancho, alignment: .trailing)
            }
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.vertical, 8)
            Divider()
            ForEach(a.meses) { f in
                HStack(spacing: 6) {
                    Text(f.mes).lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Money.fmt(f.ingresos)).foregroundStyle(Paleta.brand).celdaDinero(ancho)
                    Text(Money.fmt(f.gastos)).foregroundStyle(Paleta.negativo).celdaDinero(ancho)
                    Text(Money.fmt(f.balance)).fontWeight(.semibold).celdaDinero(ancho)
                }
                .font(pequena ? .caption : .subheadline).monospacedDigit()
                .padding(.vertical, 9)
                Divider()
            }
            // El total del año cierra la tabla: es la fila por la que
            // existe el documento.
            HStack(spacing: 6) {
                Text(L.t("Total \(a.anio)", "Total \(a.anio)")).fontWeight(.semibold)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Money.fmt(a.totalIngresos)).foregroundStyle(Paleta.brand).celdaDinero(ancho)
                Text(Money.fmt(a.totalGastos)).foregroundStyle(Paleta.negativo).celdaDinero(ancho)
                Text(Money.fmt(a.balance)).fontWeight(.semibold).celdaDinero(ancho)
            }
            .font(pequena ? .caption.weight(.semibold) : .subheadline.weight(.semibold)).monospacedDigit()
            .padding(.vertical, 9)
            .background(Paleta.brandFill)
        }
    }

    // MARK: - Tabla mensual

    private func tablaMensual(_ e: EstadoFinanciero) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TituloSeccion(texto: L.t("RESUMEN MENSUAL", "MONTHLY SUMMARY"))
            Tarjeta {
                // **La tabla se elige por lo que CABE, no por la clase de
                // tamaño.** Con `compacto` mandaba, un iPad con la columna
                // estrecha —el mini, la app a la mitad, el 13" en vertical con
                // la sidebar— pedía las cinco columnas anchas: 560 pt mínimos
                // en 453, así que la tabla se salía por la derecha, sin scroll
                // y arrastrando con ella al resto del reporte.
                //
                // Las tres versiones son las mismas columnas cediendo por
                // orden de lo que menos se echa de menos: primero la variación
                // —es lo único que se deduce mirando dos filas—, y después el
                // ancho de las cifras con la letra pequeña.
                ViewThatFits(in: .horizontal) {
                    filasMensual(e, ancho: 112, variacion: true, pequena: false)
                    filasMensual(e, ancho: 112, variacion: false, pequena: false)
                    filasMensual(e, ancho: 74, variacion: false, pequena: true)
                }
            }
        }
    }

    private func filasMensual(_ e: EstadoFinanciero, ancho: CGFloat,
                              variacion: Bool, pequena: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(L.t("MES", "MONTH")).frame(maxWidth: .infinity, alignment: .leading)
                Text(L.t("INGRESOS", "INCOME")).frame(width: ancho, alignment: .trailing)
                Text(L.t("GASTOS", "EXPENSES")).frame(width: ancho, alignment: .trailing)
                Text(L.t("BALANCE", "BALANCE")).frame(width: ancho, alignment: .trailing)
                if variacion { Text("").frame(width: anchoVariacion, alignment: .trailing) }
            }
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.vertical, 8)
            Divider()
            ForEach(e.mensual) { f in
                // El mes destacado es el que se está viendo, no el
                // último de la tabla: con el filtro puesto en junio, la
                // fila resaltada tiene que ser junio.
                let esActual = f.clave == e.periodo.clave
                HStack(spacing: 6) {
                    Text(f.mes).fontWeight(esActual ? .semibold : .regular)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Money.fmt(f.ingresos)).foregroundStyle(Paleta.brand).celdaDinero(ancho)
                    Text(Money.fmt(f.gastos)).foregroundStyle(Paleta.negativo).celdaDinero(ancho)
                    Text(Money.fmt(f.balance)).fontWeight(.semibold).celdaDinero(ancho)
                    if variacion {
                        Group { if let d = f.delta { DeltaBadge(pct: d).fixedSize() } else { Text("") } }
                            .frame(width: anchoVariacion, alignment: .trailing)
                    }
                }
                .font(pequena ? .caption : .subheadline).monospacedDigit()
                .padding(.vertical, 9)
                .background(esActual ? Paleta.brandFill : .clear)
                if f.id != e.mensual.last?.id { Divider() }
            }
        }
    }

    /// **112 pt es una medida, no un gusto.** `$9,999,999.99` —el importe más
    /// largo que la tabla puede tener que escribir— mide 110.2 pt a
    /// `.subheadline` en seminegrita, que es como va la columna de balance.
    /// Con 92 agosto salía partido en dos renglones: `$2,640,685.` sobre `50`.
    /// Los 74 de la versión estrecha van con la letra pequeña, y es lo que
    /// caben las cuatro columnas en el ancho del teléfono.
    ///
    /// Quién usa cuál lo decide el `ViewThatFits` de cada tabla, no la clase de
    /// tamaño: la misma pantalla se dibuja en la columna de un iPad y a
    /// pantalla completa en un teléfono.

    /// La columna de variación. "▲3459.4%" mide 75.2 pt a `.subheadline`, y
    /// con los 52 anteriores se rompía en tres líneas.
    private let anchoVariacion: CGFloat = 80
}

private extension View {
    /// Una celda de dinero de las tablas de resumen: ancho fijo, alineada a la
    /// derecha y **en una sola línea**.
    ///
    /// Solo el nombre del mes llevaba `lineLimit`, así que las cuatro celdas de
    /// dinero se partían en dos renglones en cuanto el importe pasaba del
    /// millón: agosto salía como `$2,640,685.` sobre `50`. El ancho da de sobra
    /// para el importe más largo posible; el `minimumScaleFactor` es el seguro
    /// por si alguien sube el tamaño de letra del sistema.
    func celdaDinero(_ ancho: CGFloat) -> some View {
        lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: ancho, alignment: .trailing)
    }
}
