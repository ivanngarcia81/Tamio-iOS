import SwiftUI
import Charts

/// **Membresía, según el handoff definitivo.**
///
/// No es una tabla, y eso fue una corrección: la primera versión de esta
/// pantalla se hizo contra el handoff anterior, donde Membership sí era una
/// tabla de cinco columnas. El diseño la rehizo entera.
///
/// Tres subpestañas —Miembros, Asistencia y Seguimiento— y encima una tira de
/// ocho indicadores que sale de `MembresiaResumen`. La lista son TARJETAS y no
/// filas: cada persona trae iniciales, estado, roster, asistencia y la marca
/// de expediente incompleto, y eso no cabe legible en una fila de tabla.
struct PantallaMembresia: View {
    let vm: MembresiaViewModel
    @Binding var seleccion: String?
    @Binding var sub: SubMembresia

    /// **El testigo del alta no es `@State` de esta vista.** Lo dispara el ⌘N
    /// del menú Archivo, que es una escena hermana de la ventana y no alcanza el
    /// estado privado de una vista — ver `EstadoVentana.pidiendoAlta`.
    @Environment(EstadoVentana.self) private var estado
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?

    /// **Quién puede dar de alta y de baja en el padrón.** El mismo permiso que
    /// esconde el `+` en iOS: un tesorero solo entra si la iglesia le abre el
    /// padrón. Esconde botones; la barrera está en Supabase.
    private var administraPadron: Bool {
        Permisos.vigentes(sesion).administraPadron
    }

    /// La ficha que se está editando. `nil` mientras no se edite ninguna, y es
    /// aparte del alta porque la hoja es la misma pero el caso no: el alta nace
    /// vacía y la edición nace de una ficha que ya existe.
    @State private var aEditar: Miembro?

    /// La persona a la que se le va a registrar una acción de seguimiento.
    /// Aparte de `aEditar` porque son dos hojas distintas sobre la misma
    /// persona: una toca su ficha y la otra su historial pastoral.
    @State private var aSeguir: Miembro?

    /// El alta de un parentesco. Es un `Bool` y no una ficha porque la hoja se
    /// abre también sin nadie elegido: su título lo dice, como en el handoff.
    @State private var emparentando = false

    enum SubMembresia: String, CaseIterable, Identifiable {
        case miembros, asistencia, seguimiento
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .miembros:    return L.t("Miembros", "Members")
            case .asistencia:  return L.t("Asistencia", "Attendance")
            case .seguimiento: return L.t("Seguimiento", "Follow-up")
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                cabecera
                tira
                switch sub {
                case .miembros:    listaDeMiembros
                case .asistencia:  panelAsistencia
                case .seguimiento: panelSeguimiento
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(Color.suelo)
        .sheet(isPresented: Binding(
            get: { estado.pidiendoAlta },
            set: { estado.pidiendoAlta = $0 }
        )) {
            NuevoMiembro(proximoId: vm.proximoId,
                         puedeDarDeBaja: administraPadron) { nuevo in
                Task {
                    // **Guardar y LUEGO sincronizar, en ese orden.** Que salga
                    // hacia el servidor ya es por lo mismo que la captura
                    // rápida, el borrado y el alta de la agenda: en el Mac la
                    // app no se va al fondo, así que la vuelta de "volver al
                    // frente" no llega y la ficha se quedaría en la cola hasta
                    // el próximo arranque.
                    //
                    // Y se ESPERA al guardado porque lanzarlos a la vez es lo
                    // que se hizo primero y se midió roto: la vuelta salía antes
                    // de que la operación estuviera en la cola —`outbox` con
                    // `miembro | crear | intentos = 0`— y la ficha no subía.
                    await vm.agregarMiembroEsperando(nuevo)
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
        .sheet(isPresented: $emparentando) {
            NuevoPariente(anfitrion: vm.items.first { $0.id == seleccion }) { id, pariente in
                Task {
                    await vm.agregarParienteEsperando(miembroId: id, pariente: pariente)
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
        .sheet(item: $aSeguir) { persona in
            SeguimientoMac(miembro: persona) { id, nota in
                Task {
                    await vm.agregarSeguimientoEsperando(miembroId: id, nota: nota)
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
        .sheet(item: $aEditar) { ficha in
            NuevoMiembro(proximoId: ficha.id, miembroExistente: ficha,
                         puedeDarDeBaja: administraPadron) { editada in
                Task {
                    await vm.editarMiembroEsperando(editada)
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
    }

    // MARK: - Cabecera

    /// **Si no cabe en una línea, en dos, y nada se encoge** (handoff 9). A
    /// 900 pt el botón se leía «New me…»: el `HStack` apretaba los botones en
    /// vez de bajarlos. Ahora los botones y la cuenta van a su tamaño natural,
    /// y `ViewThatFits` elige entre la línea y las dos líneas.
    private var cabecera: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                selectorSub
                Spacer(minLength: 0)
                cuenta
                botonesAlta
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    selectorSub
                    Spacer(minLength: 0)
                    cuenta
                }
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    botonesAlta
                }
            }
        }
    }

    private var selectorSub: some View {
        Picker("", selection: $sub) {
            ForEach(SubMembresia.allCases) { Text($0.titulo).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private var cuenta: some View {
        Text(L.t("\(vm.itemsFiltrados.count) de \(vm.items.count) personas",
                 "\(vm.itemsFiltrados.count) of \(vm.items.count) people"))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    // **El botón se queda aunque la orden viva en el menú.** El ⌘N del menú
    // funciona con el foco donde sea, que es para lo que está; pero una
    // pantalla de la que se puede dar de alta tiene que decirlo a la vista,
    // sin que haya que abrir un menú para descubrirlo.
    @ViewBuilder
    private var botonesAlta: some View {
        if administraPadron {
            // **"Añadir pariente" va antes que "Nuevo miembro"**, como en
            // el handoff: es la acción secundaria y queda a su izquierda.
            Button(L.t("Añadir pariente", "Add relative")) { emparentando = true }
                .fixedSize()
            Button { estado.pidiendoAlta = true } label: {
                Label(L.t("Nuevo miembro", "New member"), systemImage: "plus")
            }
            .fixedSize()
        }
    }

    // MARK: - Los ocho indicadores

    /// **Salen de `MembresiaResumen`, que se calcula del padrón.** El propio
    /// modelo lo documenta: "se calcula del padrón, nunca se escribe a mano".
    /// Los tres primeros son estados y se excluyen entre sí; los cinco
    /// restantes son movimientos y señales, y por eso NO suman al total.
    private var tira: some View {
        let r = vm.resumen
        let datos: [(String, Int, Color)] = [
            (L.t("Activos", "Active"), r?.activos ?? 0, Paleta.brand),
            (L.t("Inactivos", "Inactive"), r?.inactivos ?? 0, Paleta.aviso),
            (L.t("Bajas", "Removed"), r?.bajas ?? 0, .secondary),
            (L.t("Nuevos del año", "New this year"), r?.nuevos ?? 0, Paleta.cian),
            (L.t("Recibidos", "Received"), r?.recibidos ?? 0, Paleta.cian),
            (L.t("Trasladados", "Transferred out"), r?.trasladados ?? 0, .secondary),
            (L.t("Con ausencias", "With absences"), r?.ausencias ?? 0, Paleta.aviso),
            (L.t("Expediente incompleto", "Incomplete file"), r?.incompletos ?? 0, Paleta.aviso),
        ]
        // **Ocho en fila si caben enteros; si no, 4 × 2** (handoff 9), con el
        // número y el rótulo en una línea para que ningún rótulo se corte. A
        // 900 pt la fila de ocho cortaba seis («Remo…», «With a…»).
        // `ViewThatFits` mira el ancho natural de la fila —los rótulos
        // enteros— y solo la elige si cabe así.
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 9) {
                ForEach(Array(datos.enumerated()), id: \.offset) { _, d in
                    indicador(d, enLinea: false)
                }
            }
            Grid(horizontalSpacing: 9, verticalSpacing: 9) {
                GridRow {
                    ForEach(Array(datos.prefix(4).enumerated()), id: \.offset) { _, d in
                        indicador(d, enLinea: true)
                    }
                }
                GridRow {
                    ForEach(Array(datos.suffix(4).enumerated()), id: \.offset) { _, d in
                        indicador(d, enLinea: true)
                    }
                }
            }
        }
        .padding(.top, 16)
    }

    private func indicador(_ d: (String, Int, Color), enLinea: Bool) -> some View {
        let numero = Text("\(d.1)")
            .font(.system(size: 20, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(d.2)
        let rotulo = Text(d.0)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        return Group {
            if enLinea {
                HStack(spacing: 9) { numero.fixedSize(); rotulo }
            } else {
                VStack(alignment: .leading, spacing: 2) { numero; rotulo }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .tarjetaMac(11)
    }

    // MARK: - Miembros

    @ViewBuilder
    private var listaDeMiembros: some View {
        if vm.cargado && vm.items.isEmpty {
            padronVacio
        } else {
            VStack(alignment: .leading, spacing: 0) {
                chips.padding(.top, 18)
                LazyVStack(spacing: 7) {
                    ForEach(vm.itemsFiltrados) { tarjeta($0) }
                }
                .padding(.top, 14)
            }
        }
    }

    /// **El padrón vacío ofrece traer la lista** (handoff «Trae tus datos»,
    /// M6). Es donde busca quien se saltó la invitación: la casa fija es
    /// Configuración › Datos, pero aquí es donde se nota que falta la gente.
    /// Los dos botones piden `administraPadron`, como el alta y la importación.
    private var padronVacio: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2")
                .font(.system(size: 19))
                .foregroundStyle(Paleta.brand)
                .frame(width: 44, height: 44)
                .background(Paleta.brandFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(L.t("Aún no hay nadie en el padrón", "No one on the roll yet"))
                .font(.system(size: 17, weight: .bold))
            Text(L.t("Trae tu lista de un Excel o agrega a las personas una por una.",
                     "Bring in your list from Excel or add people one by one."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
            if administraPadron {
                HStack(spacing: 10) {
                    Button(L.t("Importar una lista…", "Import a list…")) {
                        estado.pidiendoImportarAportantes = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Paleta.brand)
                    Button(L.t("Agregar persona", "Add person")) {
                        estado.pidiendoAlta = true
                    }
                }
                .padding(.top, 6)
                Button(L.t("Descargar la plantilla", "Download the template")) {
                    PlantillaImportar.guardar(.personas)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Paleta.enlace)
                .padding(.top, 2)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    /// Los ocho recortes: Todos, los cuatro del registro, Baja, y los dos que
    /// piden acción. **Son los mismos que ya tenía el ViewModel**, no una lista
    /// nueva: `filtroEstado` toma una clave de `EstadoMiembro.claves` y
    /// `filtroAccion` las dos señales.
    private var chips: some View {
        FlowChips {
            chip(L.t("Todos", "All"), activo: vm.filtroEstado == nil && vm.filtroAccion == nil) {
                vm.filtroEstado = nil; vm.filtroAccion = nil
            }
            ForEach(EstadoMiembro.claves, id: \.self) { clave in
                chip(EstadoMiembro.etiqueta(clave: clave),
                     activo: vm.filtroEstado == clave && vm.filtroAccion == nil) {
                    vm.filtroEstado = clave; vm.filtroAccion = nil
                }
            }
            chip(L.t("Con ausencias", "With absences"), activo: vm.filtroAccion == .ausencias) {
                vm.filtroAccion = .ausencias; vm.filtroEstado = nil
            }
            chip(L.t("Expediente incompleto", "Incomplete file"),
                 activo: vm.filtroAccion == .incompletos) {
                vm.filtroAccion = .incompletos; vm.filtroEstado = nil
            }
        }
    }

    private func chip(_ rotulo: String, activo: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Text(rotulo)
                .font(.system(size: 12, weight: activo ? .semibold : .regular))
                .foregroundStyle(activo ? Paleta.brand : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(activo ? Paleta.brandFill : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tarjeta(_ m: Miembro) -> some View {
        let elegido = seleccion == m.id
        return Button { seleccion = m.id } label: {
            HStack(spacing: 13) {
                Text(m.iniciales)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Paleta.brand)
                    .frame(width: 36, height: 36)
                    .background(Paleta.brandFill, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(m.nombre)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    Text(subtituloDe(m))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)

                // **La marca de expediente incompleto, antes que la píldora.**
                // Es lo que hay que ir a arreglar; el estado solo dice dónde
                // está esa persona.
                if !m.expedienteCompleto {
                    Text(L.t("Expediente incompleto", "Incomplete file"))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Text(m.estado.etiqueta)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(m.estado.color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 2)
                    .background(m.estado.color.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(m.cargoLegible)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 92, alignment: .trailing)

                // Sin listas tomadas no es 0 %: es que nadie apuntó.
                Text(m.asistenciaResumen == nil ? "—" : "\(m.asistenciaPct)%")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(m.asistenciaResumen == nil ? Color.secondary : m.tintaDeAsistencia)
                    .frame(width: 48, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(elegido ? Paleta.brandFill : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.quaternary, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // **Doble clic abre la ficha, y el menú contextual lo dice.** En un Mac
        // el doble clic sobre una fila es "ábrela"; dejarlo solo en el menú
        // contextual haría que se descubriera por casualidad. Un clic sigue
        // seleccionando, que es lo que llena el inspector.
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            guard administraPadron else { return }
            seleccion = m.id
            aEditar = m
        })
        .contextMenu {
            Button(L.t("Editar ficha…", "Edit profile…")) {
                seleccion = m.id
                aEditar = m
            }
            .disabled(!administraPadron)
            // **El seguimiento no pide `administraPadron`.** Registrar una
            // llamada o una visita no toca el padrón: lo hace quien acompaña a
            // la persona, que no siempre es quien da de alta y de baja.
            Button(L.t("Registrar seguimiento…", "Log follow-up…")) {
                seleccion = m.id
                aSeguir = m
            }
        }
    }

    private func subtituloDe(_ m: Miembro) -> String {
        let desde = m.fechaIngreso.isEmpty ? "" : Fechas.diaLegible(m.fechaIngreso)
        let ministerio = m.ministerios.isEmpty ? "" : Padron.etiquetas(m.ministerios)
        if desde.isEmpty { return ministerio.isEmpty ? "—" : ministerio }
        let entro = L.t("Ingresó \(desde)", "Joined \(desde)")
        return ministerio.isEmpty ? entro : "\(entro) · \(ministerio.lowercased())"
    }

    // MARK: - Asistencia

    @ViewBuilder
    private var panelAsistencia: some View {
        if let a = vm.asistencia {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    kpi(L.t("Asistencia media", "Average attendance"), "\(a.promedioPct)%", Paleta.brand)
                    kpi(L.t("Servicios del periodo", "Services this period"), "\(a.serviciosPeriodo)", .primary)
                    kpi(L.t("Presentes de media", "Average present"), "\(a.presentesPromedio)", .primary)
                    kpi(L.t("Mejor servicio", "Best service"),
                        a.mejorServicio.isEmpty ? "—" : a.mejorServicio, Paleta.placaMorado)
                }
                HStack(alignment: .top, spacing: 12) {
                    panel(L.t("PRESENTES CONTRA PADRÓN", "PRESENT VS ROSTER")) {
                        if a.meses.isEmpty {
                            sinDatos
                        } else {
                            Chart(a.meses) { m in
                                BarMark(x: .value("Mes", m.mes),
                                        y: .value("Presentes", m.presentes))
                                    .foregroundStyle(Paleta.brand)
                                    .cornerRadius(4)
                            }
                            .frame(height: 150)
                            .padding(.top, 14)
                        }
                    }
                    panel(L.t("MEDIA POR TIPO DE CULTO", "AVERAGE BY SERVICE TYPE")) {
                        if a.porTipo.isEmpty {
                            sinDatos
                        } else {
                            let tope = max(1, a.porTipo.map(\.promedio).max() ?? 1)
                            VStack(spacing: 12) {
                                ForEach(a.porTipo) { t in
                                    VStack(spacing: 5) {
                                        HStack {
                                            Text(t.tipo).font(.system(size: 12))
                                            Spacer(minLength: 6)
                                            Text("\(t.promedio)")
                                                .font(.system(size: 12))
                                                .monospacedDigit()
                                                .foregroundStyle(.secondary)
                                        }
                                        GeometryReader { g in
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(.quaternary)
                                                Capsule().fill(Paleta.brand)
                                                    .frame(width: g.size.width
                                                           * CGFloat(t.promedio) / CGFloat(tope))
                                            }
                                        }
                                        .frame(height: 8)
                                    }
                                }
                            }
                            .padding(.top, 14)
                        }
                    }
                    .frame(width: 300)
                }
            }
            .padding(.top, 18)
        } else {
            sinDatos.padding(.top, 30)
        }
    }

    // MARK: - Seguimiento

    @ViewBuilder
    private var panelSeguimiento: some View {
        let gente = vm.itemsSeguimiento
        if gente.isEmpty {
            Text(L.t("Nadie necesita seguimiento ahora mismo.",
                     "Nobody needs follow-up right now."))
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .padding(.top, 30)
        } else {
            VStack(spacing: 10) {
                ForEach(gente) { m in
                    let porAusencias = m.tieneAusencias
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            Text(porAusencias ? L.t("AUSENCIAS", "ABSENCES")
                                              : L.t("EXPEDIENTE", "FILE"))
                                .font(.system(size: 11, weight: .bold))
                                .kerning(0.5)
                                .foregroundStyle(porAusencias ? Paleta.aviso : Paleta.cian)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background((porAusencias ? Paleta.aviso : Paleta.cian).opacity(0.14),
                                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            Text(m.nombre).font(.system(size: 13.5, weight: .semibold))
                            Spacer(minLength: 0)
                            Text(m.cargoLegible)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.tertiary)
                        }
                        HStack(alignment: .bottom, spacing: 10) {
                            Text(porAusencias
                                 ? L.t("Lleva servicios seguidos sin asistir.",
                                       "Several services in a row without attending.")
                                 : L.t("Faltan datos en su expediente.",
                                       "Their file is missing data."))
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                            // **La lista decía a quién hay que buscar y no dejaba
                            // apuntar que se le buscó.** Era de solo lectura como
                            // el resto del Mac, así que la acción se registraba en
                            // el teléfono o no se registraba.
                            //
                            // Y dice cuántas van: quien abre esta pestaña quiere
                            // saber si alguien ya llamó antes de llamar otra vez.
                            Button {
                                aSeguir = m
                            } label: {
                                if m.seguimientoNotas.isEmpty {
                                    Text(L.t("Registrar acción…", "Log action…"))
                                } else {
                                    Text(L.t("Registrar acción… · \(m.seguimientoNotas.count)",
                                             "Log action… · \(m.seguimientoNotas.count)"))
                                }
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tarjetaMac(13)
                    // Doble clic sobre la tarjeta, por lo mismo que en la lista
                    // de Miembros: en un Mac es "ábrela".
                    .contentShape(Rectangle())
                    .simultaneousGesture(TapGesture(count: 2).onEnded { aSeguir = m })
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.top, 18)
        }
    }

    // MARK: - Piezas

    private func kpi(_ k: String, _ v: String, _ tinta: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(k).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            Text(v)
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tinta)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tarjetaMac(14)
    }

    private func panel<C: View>(_ titulo: String, @ViewBuilder c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titulo)
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(.secondary)
            c()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tarjetaMac(14)
    }

    private var sinDatos: some View {
        Text(L.t("Todavía no se ha tomado lista en ningún servicio.",
                 "Attendance hasn't been taken at any service yet."))
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 26)
    }
}

/// Chips que saltan de renglón cuando no caben. `LazyVGrid` no vale: aquí cada
/// chip mide lo que mide su texto, y en dos idiomas distintos.
///
/// **Saltan de verdad** (24-sep). La versión anterior probaba una fila y, si no
/// cabía, ponía… la misma fila: los chips se apretaban y partían su texto
/// («With / absences»). Ahora cada chip va a su tamaño y el que no cabe baja.
struct FlowChips<C: View>: View {
    @ViewBuilder let contenido: C
    var body: some View {
        Flujo(espacio: 6) { contenido }
    }
}

/// Un layout que coloca a sus hijos en fila, a su tamaño natural, y baja al
/// siguiente renglón el que no cabe. Es layout puro: no mide nada en un
/// estado, así que no puede cambiar la vista a mitad del layout de AppKit.
struct Flujo: Layout {
    var espacio: CGFloat = 6

    private func filas(_ ancho: CGFloat, _ subviews: Subviews) -> [[(Int, CGSize)]] {
        var filas: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let t = v.sizeThatFits(.unspecified)
            if x > 0 && x + t.width > ancho {
                filas.append([]); x = 0
            }
            filas[filas.count - 1].append((i, t))
            x += t.width + espacio
        }
        return filas
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ancho = proposal.width ?? .infinity
        let fs = filas(ancho, subviews)
        let anchos = fs.map { f in f.reduce(0) { $0 + $1.1.width } + espacio * CGFloat(max(0, f.count - 1)) }
        let alto = fs.reduce(0) { $0 + ($1.map(\.1.height).max() ?? 0) } + espacio * CGFloat(max(0, fs.count - 1))
        return CGSize(width: anchos.max() ?? 0, height: alto)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for f in filas(bounds.width, subviews) {
            var x = bounds.minX
            let alto = f.map(\.1.height).max() ?? 0
            for (i, t) in f {
                subviews[i].place(at: CGPoint(x: x, y: y + (alto - t.height) / 2),
                                  proposal: ProposedViewSize(t))
                x += t.width + espacio
            }
            y += alto + espacio
        }
    }
}

// MARK: - Lo que la ficha y la tarjeta necesitan del modelo

extension Miembro {
    /// Los cargos en palabras: lo que el handoff llama "Role".
    ///
    /// **Cargo NO es ministerio.** El cargo es qué eres —diácono, ujier—; el
    /// ministerio es dónde sirves —música, niños—. La primera versión de esta
    /// pantalla leía `ministerios` en la columna que el diseño rotula "Role",
    /// y el propio modelo ya los tenía separados y rotulados "Cargos / Roles".
    var cargoLegible: String {
        cargos.isEmpty ? "—" : Padron.etiquetas(cargos)
    }

    var ministerioLegible: String {
        ministerios.isEmpty ? "—" : Padron.etiquetas(ministerios)
    }

    /// Los tres tramos del handoff: verde desde 85, ámbar desde 65, rojo debajo.
    var tintaDeAsistencia: Color {
        if asistenciaPct >= 85 { return Paleta.brand }
        if asistenciaPct >= 65 { return Paleta.aviso }
        return Paleta.negativo
    }
}
