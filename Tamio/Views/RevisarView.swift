import SwiftUI

/// Pantalla "Por revisar": bandeja de asuntos que necesitan atención (esperan
/// visto bueno, sin comprobante, duplicados, etc.). Chips de filtro por tipo,
/// lista maestro-detalle, acciones por tipo (Aprobar/Editar/Devolver/…), toast
/// con Deshacer y "Aprobar todo". Fiel al handoff.
struct RevisarView: View {
    @Environment(Navegacion.self) private var nav: Navegacion?
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    @State private var vm = RevisarViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var abierto: Revision?
    @State private var editando: Revision?

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    // Ancha a propósito: las filas llevan sus botones dentro.
                    // Sin material detrás de la columna — ahí no tenía nada que
                    // difuminar y se resolvía como un gris plano; el material
                    // vive donde la lista pasa por debajo. Mismo cambio que ya
                    // se hizo en Ingresos/Gastos, Aportantes y Depósitos.
                    listaColumna
                        .frame(width: Esp.columnaMaestraAncha)
                    Divider()
                    if let a = vm.seleccion { detalle(a) } else { vacio }
                }
            } else {
                listaPhone
                    .background(Color(.systemGroupedBackground))
                    .navigationDestination(item: $abierto) { a in
                        // **El asunto se busca por id, no se usa la copia que
                        // se empujó.** `abierto` guarda el valor que había al
                        // tocar la fila, así que tras corregir el importe la
                        // ficha seguía enseñando la cifra vieja hasta salir y
                        // volver a entrar —medido el 9-sep: la lista decía
                        // −$1.00 y la ficha abierta encima, −$600.00—. La
                        // columna del iPad ya lo hacía bien porque lee
                        // `vm.seleccion`, que es una búsqueda por id.
                        // Barra vacía: el H1 del detalle ya dice el asunto.
                        detalle(vm.todos.first { $0.id == a.id } ?? a)
                            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(L.t("Por revisar", "To review"), subtituloBarra)
        // `.large` solo en iPad, igual que en Depósitos: en el teléfono la raíz
        // no scrollea y el título grande dejaba una franja vacía.
        .navigationBarTitleDisplayMode(sizeClass == .compact ? .inline : .large)
        .toolbar {
            // **Sin cápsula cuando no es un botón.** Con cero aprobables esto
            // es un texto —lo dice `aprobarTodo`—, pero el sistema le pone su
            // cristal igual y "0 of 16 ready" se lee como un control que no
            // responde, que es justo lo que esta pantalla dejó de hacer.
            ToolbarItem(placement: .topBarTrailing) { aprobarTodo }
                .sharedBackgroundVisibility(vm.aprobablesCount == 0 ? .hidden : .automatic)
        }
        .overlay(alignment: .bottom) { toastView }
        .animation(.snappy, value: vm.toast?.id)
        .sheet(item: $editando) { a in
            EditarAsuntoView(r: a) { concepto, importe, categoria, metodo, aportante, fecha in
                Task { await vm.editar(id: a.id, concepto: concepto, importe: importe,
                                       categoria: categoria, metodo: metodo,
                                       aportante: aportante, fecha: fecha) }
            }
        }
        .task { await vm.cargar() }
        .sincronizable { await vm.cargar() }
    }

    /// El subtítulo dice lo que hay, no solo cuántos: "movimientos esperan tu
    /// visto bueno" era falso desde que la bandeja lista siete cosas distintas
    /// y solo una es un visto bueno pendiente.
    private var subtituloBarra: String {
        let n = vm.porRevisarCount
        return L.t("\(n) asunto\(n == 1 ? "" : "s") por revisar",
                   "\(n) item\(n == 1 ? "" : "s") to review")
    }

    // MARK: - Toast

    /// **El aviso de deshacer, legible en los dos temas.**
    ///
    /// El fondo era `Color(.label)` con el texto en `.white`: en claro eso es
    /// negro sobre blanco y se lee, pero `.label` en OSCURO es blanco — y el
    /// texto seguía siendo blanco. El mensaje desaparecía entero y solo quedaba
    /// "Deshacer" flotando en una barra en blanco. Un aviso que dice qué acabas
    /// de hacer, ilegible justo donde se puede deshacer.
    ///
    /// Ahora es material, como el resto de las superficies flotantes de la app,
    /// con el texto en `.primary`: los dos se invierten juntos y no hay tema en
    /// el que coincidan.
    /// **Con cero aprobables no hay botón, hay una frase.**
    ///
    /// Iba siempre en cápsula de glass y se apagaba con `.disabled`. Medido en
    /// pantalla, ese estado da **1.70:1** de contraste —el mínimo para texto
    /// normal es 4.5:1—: la etiqueta se borraba y quedaba una cápsula vacía. No
    /// era el verde de marca: sin `tint` daba exactamente lo mismo. Es
    /// `.disabled` sobre `.glass`, que atenúa la etiqueta contra un material
    /// que ya es casi blanco.
    ///
    /// Y el problema no era solo de contraste. Con cero aprobables ese control
    /// no puede hacer nada: los asuntos de la lista piden vincular aportante o
    /// adjuntar comprobante, uno por uno. Una cápsula que parece botón y no
    /// responde promete algo que no cumple, que es justo lo que esta pantalla
    /// dejó de hacer cuando sus botones dejaron de apagar el aviso sin arreglar
    /// nada.
    ///
    /// Así que con cero se lee como lo que es, información: cuántos de los
    /// pendientes están listos para aprobarse en bloque —ninguno— dicho en
    /// texto legible. En cuanto hay uno, vuelve la cápsula verde y vuelve a ser
    /// una acción. El color va con `.primary` rebajado y no con `.secondary`,
    /// que se queda en 3.29:1: rebajado da 6.3:1 en claro y sube en oscuro,
    /// porque `.primary` ya cambia de lado con la apariencia.
    @ViewBuilder
    private var aprobarTodo: some View {
        if vm.porRevisarCount == 0 {
            // **Con cero pendientes no va nada.** El texto de abajo cuenta
            // cuántos de los pendientes están listos, y con ninguno pendiente
            // decía "0 de 0 listos" — que no informa de nada y además se
            // truncaba a "0 of 0 re…" en el teléfono. Lo que pasa cuando la
            // bandeja está vacía ya lo dice la propia bandeja.
            EmptyView()
        } else if vm.aprobablesCount == 0 {
            Text(L.t("0 de \(vm.porRevisarCount) listos",
                     "0 of \(vm.porRevisarCount) ready"))
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.7))
        } else {
            // El conteo dice cuántos de los pendientes va a tocar: antes decía
            // "Aprobar todo" y aprobaba también el duplicado y el gasto sin
            // comprobante que había en la lista.
            Button { Task { await vm.aprobarTodo() } } label: {
                Text(vm.aprobablesCount == vm.porRevisarCount
                     ? L.t("Aprobar todo", "Approve all")
                     : L.t("Aprobar \(vm.aprobablesCount) de \(vm.porRevisarCount)",
                           "Approve \(vm.aprobablesCount) of \(vm.porRevisarCount)"))
            }
            .buttonStyle(.glass)
            .tint(Paleta.brand)
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let t = vm.toast {
            HStack(spacing: 14) {
                Text(t.mensaje).font(.subheadline).lineLimit(2)
                Spacer(minLength: 8)
                Button(L.t("Deshacer", "Undo")) { Task { await vm.deshacer() } }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Paleta.brand)
            }
            .padding(.horizontal, Esp.tarjeta).padding(.vertical, 12)
            // **Cristal, no material opaco con filete y sombra.** Era
            // `.thickMaterial` + un borde de 0.5 y una sombra, que es la
            // receta de un aviso flotante de iOS 18: tres capas dibujadas para
            // fingir que algo está encima. El cristal ya trae el borde y la
            // profundidad, y además refracta lo que pasa por debajo —que en
            // esta pantalla es la lista que acaba de cambiar—, cosa que el
            // material opaco tapaba.
            //
            // El texto se queda en `.primary`. Medido el 16-sep-2026 sobre la
            // captura, con el aviso encima de la lista: **20.65:1 en claro y
            // 13.57:1 en oscuro**, y el "Deshacer" en verde de marca a 5.20:1
            // y 4.60:1. Los cuatro por encima del 4.5:1 que pide el texto
            // normal.
            .glassEffect(.regular, in: .capsule)
            // Separado del borde: pegado a 16 pt quedaba contra la barra de
            // pestañas, y las dos cápsulas se leían como una sola pieza rota.
            .padding(.horizontal, Esp.pantalla).padding(.bottom, Esp.panel)
            .frame(maxWidth: 520)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: t.id) {
                try? await Task.sleep(nanoseconds: 4_500_000_000)
                if vm.toast?.id == t.id { vm.toast = nil }
            }
        }
    }

    // MARK: - Lista

    /// **La bandeja vacía dice por qué está vacía.** Con cero asuntos las dos
    /// listas dibujaban un `ForEach` sin elementos y la pantalla se quedaba en
    /// blanco: ni un icono ni una línea, indistinguible de una pantalla rota o
    /// de una que no terminó de cargar. Lo vio Iván en su iPhone.
    ///
    /// Son tres casos distintos y se dicen distintos: todavía cargando, no hay
    /// nada —que es una buena noticia y se escribe como tal—, y hay asuntos
    /// pero el filtro los esconde, que se arregla quitando el filtro y por eso
    /// lleva el botón para quitarlo.
    @ViewBuilder
    private var bandejaVacia: some View {
        if vm.cargando && vm.todos.isEmpty {
            ProgressView().controlSize(.large)
        } else if vm.todos.isEmpty {
            ContentUnavailableView(
                L.t("Todo al día", "All caught up"),
                systemImage: "checkmark.circle",
                description: Text(L.t("No hay nada que revisar. Lo que necesite visto bueno, comprobante o una corrección aparecerá aquí.",
                                      "Nothing to review. Anything needing approval, a receipt or a fix will show up here.")))
        } else if vm.visibles.isEmpty {
            ContentUnavailableView {
                Label(L.t("Nada con este filtro", "Nothing with this filter"),
                      systemImage: "line.3.horizontal.decrease")
            } description: {
                Text(L.t("Hay \(vm.totalCount) asuntos, pero ninguno del tipo elegido.",
                         "There are \(vm.totalCount) items, but none of the chosen type."))
            } actions: {
                Button(L.t("Ver todos", "Show all")) { vm.filtro = nil }
                    .buttonStyle(.glass).tint(Paleta.brand)
            }
        }
    }

    // MARK: - Lista iPhone (tarjetas)

    private var listaPhone: some View {
        ScrollView {
            // Misma separación que las demás listas: la de `Esp`.
            LazyVStack(spacing: Esp.hueco) {
                ForEach(vm.visibles) { filaTargeta($0) }
            }
            .padding(.horizontal, Esp.pantalla)
            .padding(.vertical, 8)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .colchonInferior()
        .overlay { bandejaVacia }
    }

    private func filaTargeta(_ a: Revision) -> some View {
        VStack(spacing: 0) {
            Button {
                vm.seleccionId = a.id
                abierto = a
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.concepto)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let imp = a.editImporte {
                            // **El símbolo de la moneda, no un "$" pegado al
                            // signo.** Este es el sexto sitio del "$" a mano y
                            // el que más costó encontrar: iba dentro del mismo
                            // literal que el signo ("−$"), así que no lo cazaba
                            // ningún grep de `"$"` suelto. Es la fila de la
                            // LISTA de la bandeja; la del detalle es la de
                            // abajo, y estaban las dos.
                            Text((a.esGasto ? "−" : "+") + Money.moneda.simbolo + imp)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(a.esGasto ? Paleta.negativo : Paleta.brand)
                                .monospacedDigit()
                        }
                    }
                    Text(a.detalleLista)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(a.tipo.etiquetaCorta)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(a.tipo.color)
                        .padding(.horizontal, Esp.hueco).padding(.vertical, 3)
                        .background(a.tipo.color.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, Esp.tarjeta).padding(.top, 14).padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            HStack(spacing: 8) {
                botonesTargeta(a)
            }
            .padding(.horizontal, Esp.tarjeta).padding(.vertical, 4)
        }
        // Mismo radio que `filaDeLista`: esta pantalla llevaba tarjetas de 16
        // mientras las otras ocho iban a 10, y puestas una al lado de otra se
        // leían como dos componentes distintos.
        // **Sin sombra.** La separación del suelo la da el propio color de la
        // tarjeta contra el fondo agrupado, que es como se separan las otras
        // ocho pantallas; la sombra de 3 pt era el resto de un diseño de
        // tarjetas de web y en oscuro no aporta nada —sombra negra sobre casi
        // negro—. Comprobado en CLARO, que es donde sí se veía y donde podía
        // perderse el borde.
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
    }

    /// **"Restaurar" reactiva a una persona del padrón**, y eso es de
    /// Secretaría: el asunto del aportante archivado que sigue aportando se
    /// queda en la bandeja del tesorero para que se entere, pero sin el
    /// botón. El resto de acciones son de Tesorería y no cambian.
    private func accionesDe(_ a: Revision) -> [AccionRevision] {
        Permisos.vigentes(sesion).administraPadron
            ? a.acciones
            : a.acciones.filter { $0.kind != .restaurar }
    }

    @ViewBuilder
    private func botonesTargeta(_ a: Revision) -> some View {
        let acciones = accionesDe(a)
        if !acciones.isEmpty {
            // **Sin relleno verde.** El botón se pintaba a mano: fondo
            // `Paleta.brand` con el texto en blanco, que es lo que da ~2.4:1 en
            // oscuro y por lo que se quitó del resto de la app. Ahora es glass
            // con el verde de marca, y sigue siendo la acción principal por el
            // peso de la tipografía.
            //
            // **Decía "era además el último sitio donde quedaba", y no lo era:**
            // `filaCompacta` —esta misma fila en la lista del iPad— tenía el
            // mismo relleno pintado a mano y no se vio, porque en el teléfono
            // esa rama no se dibuja. Se arregló con esta misma receta.
            let prim = acciones[0]
            Button { activar(prim, a) } label: {
                Text(prim.label)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .tint(Paleta.brand)
            if acciones.count > 1 {
                let sec = acciones[1]
                Button { activar(sec, a) } label: {
                    Text(sec.label)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .tint(Color.secondary)
            }
        }
    }

    // MARK: - Lista iPad

    private var listaColumna: some View {
        ScrollView {
            // Las filas son tarjetas separadas, como en las otras diez listas
            // desde el 11-sep: pegadas y blancas sobre un suelo blanco, la
            // columna se leía como una hoja en blanco con rayas.
            LazyVStack(spacing: Esp.hueco) {
                ForEach(vm.visibles) { filaCompacta($0) }
                HStack {
                    Text(L.t("\(vm.totalCount) por revisar", "\(vm.totalCount) to review"))
                    Spacer()
                    Text(L.t("\(vm.archivadosCount) archivados", "\(vm.archivadosCount) archived"))
                }
                .font(.caption2).foregroundStyle(.tertiary).padding(Esp.tarjeta)
            }
        }
        .background(Paleta.sueloColumna)
        // El desvanecido de borde: la fila deja de aparecer y desaparecer de
        // golpe al cruzar por detrás de la barra.
        .scrollEdgeEffectStyle(.soft, for: .all)
        .colchonInferior()
        .overlay { bandejaVacia }
    }

    private func filaCompacta(_ a: Revision) -> some View {
        let esSel = a.id == vm.seleccionId
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                vm.seleccionId = a.id
                abierto = a
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.concepto)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let imp = a.editImporte {
                            // `editImporte` viene ya sin símbolo
                            // (`CalculadoraRevisiones` se lo quita), así que
                            // aquí se vuelve a poner: el de la iglesia, no "$".
                            Text((a.esGasto ? "−" : "+") + Money.moneda.simbolo + imp)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(a.esGasto ? Paleta.negativo : Paleta.brand)
                                .monospacedDigit()
                                .layoutPriority(1)
                        }
                    }
                    Text(a.detalleLista)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    // **El color lo dice el tipo, no la pantalla.** Estuvo en
                    // cian informativo con el argumento de que lo que reclama
                    // algo ya lo dicen los badges naranjas de al lado — pero en
                    // esta fila no hay más badges: este es el único, y el mismo
                    // asunto salía azul aquí y naranja al abrirlo. `RevisionTipo`
                    // ya trae su color (naranja lo que espera algo de ti, gris
                    // lo archivado), así que lo usan la lista y el detalle.
                    Pill(texto: a.tipo.etiquetaCorta, color: a.tipo.color)
                }
                .padding(.horizontal, Esp.chip).padding(.top, 14).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // **Cápsulas del sistema, no dibujadas a mano.** Eran botones
            // `.plain` con la cápsula puesta a pulso: relleno `Paleta.brand`
            // con texto blanco la principal —los ~2.4:1 en oscuro que ya se
            // quitaron del resto de la app— y un filete de 1.5 pt la otra. Un
            // borde dibujado y un relleno plano no refractan nada: dentro del
            // cristal se leen como pegatinas de otra app.
            //
            // Misma receta que `botonesTargeta`, que es esta misma fila en el
            // teléfono: `.glass` con el verde de marca para la principal —y el
            // peso de la tipografía, no el relleno, es lo que dice que lo es— y
            // `.glass` destintado a `.secondary` para la otra.
            HStack(spacing: 10) {
                ForEach(accionesDe(a).prefix(2)) { ac in
                    Button { activar(ac, a) } label: {
                        Text(ac.label)
                            .font(.caption.weight(ac.prominente ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .tint(ac.prominente ? Paleta.brand : Color.secondary)
                }
            }
            .padding(.horizontal, Esp.chip).padding(.bottom, 14)
        }
        .background(esSel ? Paleta.brandFill : Paleta.superficieFila,
                    in: RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
        .overlay(alignment: .leading) {
            if esSel { Rectangle().fill(Paleta.brand).frame(width: 3) }
        }
        .clipShape(RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
        .padding(.horizontal, Esp.hueco)
    }

    // MARK: - Detalle

    private func detalle(_ a: Revision) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Un solo chip, y con la categoría concreta del pendiente
                // ("Espera visto bueno", "Duplicado probable"), que es la que
                // era el título hasta ahora. Naranja y en formato normal, como
                // los chips de las listas: el rojo queda para lo que resta
                // dinero o borra.
                Pill(texto: a.tipo.etiqueta, color: a.tipo.color)

                Text(a.concepto).font(.title.weight(.bold))
                Text(a.descripcion).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                acciones(a)

                tarjetaCampos(a.seccionTitulo, a.campos)
                if let sec = a.seccionSecundaria {
                    tarjetaCampos(sec, a.camposSecundarios)
                }
                if let nota = a.notaPie {
                    Text(nota).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Esp.panel)
        }
        .colchonInferior()
        .background(Color(.systemGroupedBackground))
    }

    private func acciones(_ a: Revision) -> some View {
        HStack(spacing: 10) {
            ForEach(accionesDe(a)) { ac in
                if ac.navegacion {
                    // Solo lleva a otro lado: chevron y tint neutro. El verde
                    // queda para lo que resuelve el pendiente.
                    Button { activar(ac, a) } label: {
                        HStack(spacing: 4) {
                            Text(ac.label)
                            Image(systemName: "chevron.right").font(.caption2)
                        }
                    }
                    .buttonStyle(.glass)
                    .tint(Color.secondary)
                } else if ac.prominente {
                    // `.glass` con el verde de marca, no relleno: el texto
                    // blanco sobre `Paleta.brand` da ~2.4:1 en oscuro, que es
                    // por lo que se quitó del resto de la app. Sigue siendo la
                    // acción principal por el peso de la tipografía.
                    Button { activar(ac, a) } label: { Text(ac.label).fontWeight(.semibold) }
                        .buttonStyle(.glass).tint(Paleta.brand)
                } else {
                    Button { activar(ac, a) } label: { Text(ac.label) }
                        .buttonStyle(.glass)
                        .tint(Color.secondary)
                }
            }
            Spacer()
        }
    }

    private func activar(_ ac: AccionRevision, _ a: Revision) {
        switch ac.kind {
        case .editar: editando = a
        case .irAlCorte: irAlCorte(a)
        case .aprobar, .devolver, .restaurar:
            Task { await vm.resolver(a, kind: ac.kind) }
        }
    }

    /// **Lleva al corte concreto**, no a la lista. El id del asunto es
    /// "co-<id del corte>-firma": de ahí sale a cuál abrir.
    private func irAlCorte(_ a: Revision) {
        let partes = a.id.split(separator: "-").map(String.init)
        guard partes.count >= 2, partes[0] == "co" else { return }
        nav?.corteDestacado = partes[1]
        nav?.seccion = "depositos"
        nav?.pestana = .tesoreria
    }

    private func tarjetaCampos(_ titulo: String, _ campos: [CampoRevision]) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 0) {
                TituloSeccion(texto: titulo).padding(.bottom, 8)
                ForEach(Array(campos.enumerated()), id: \.element.id) { i, c in
                    filaCampo(c)
                    if i < campos.count - 1 { Divider() }
                }
            }
        }
    }

    private func filaCampo(_ c: CampoRevision) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(c.label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(c.valor).font(.subheadline.weight(c.resalte == .ninguno ? .regular : .semibold))
                .foregroundStyle(colorResalte(c.resalte)).monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private func colorResalte(_ r: ResalteCampo) -> Color {
        switch r {
        case .ninguno: return .primary
        case .verde: return Paleta.brand
        case .rojo: return Paleta.negativo
        }
    }

    // MARK: - Estado vacío

    private var vacio: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("Elige un asunto", "Pick an item")).font(.title2.weight(.bold))
                    Text(L.t("Toca un asunto de la lista para ver aquí su explicación y resolverlo o devolverlo.",
                             "Tap an item in the list to see its explanation here and resolve or return it."))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    tarjetaConteo(L.t("Asuntos", "Items"), vm.totalCount, Paleta.brand, .primary)
                    tarjetaConteo(L.t("Esperan visto bueno", "Awaiting approval"), vm.esperanVistoBueno, Paleta.aviso, Paleta.aviso)
                    tarjetaConteo(L.t("Piden un arreglo", "Need a fix"), vm.pidenArreglo, Paleta.brand, .primary)
                    tarjetaConteo(L.t("Solo enterarse", "Just be aware"), vm.soloEnterarse, .secondary, .secondary)
                }
                Text(L.t("Un movimiento puede salir dos veces: son dos cosas distintas que revisar.",
                         "One entry can show up twice: they're two different things to review."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(Esp.panel)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func tarjetaConteo(_ label: String, _ n: Int, _ acento: Color, _ colorNum: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text("\(n)").font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(colorNum).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Esp.tarjeta)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 2).fill(acento).frame(height: 3).padding(.horizontal, Esp.chip) }
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.separator.opacity(0.6), lineWidth: 0.5))
    }
}
