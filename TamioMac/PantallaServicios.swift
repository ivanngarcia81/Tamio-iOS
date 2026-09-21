import SwiftUI
import Charts

/// **Registro de servicios, según el handoff.**
///
/// La primera versión fue una tabla, hecha cuando el handoff no dibujaba esta
/// pantalla. Ahora la dibuja y es maestro-detalle: la lista de cultos a la
/// izquierda en 300 pt, y a la derecha todo lo del culto elegido —los conteos,
/// el roster de los puestos habituales, el orden del culto, los visitantes y
/// el histórico de asistencia—.
///
/// Es mejor forma que la tabla para esto, y se ve el porqué en el contenido:
/// un culto tiene siete puestos, un orden con horas y una lista de visitantes.
/// Nada de eso entra en una fila.
struct PantallaServicios: View {
    let vm: ServiciosViewModel
    @Binding var seleccion: String?

    /// El alta la dispara el ⌥⌘N del menú — ver `EstadoVentana.pidiendoAlta`.
    @Environment(EstadoVentana.self) private var estado
    /// El culto al que se le está tomando la lista. Aparte del alta porque son
    /// dos hojas distintas sobre el mismo culto: una lo crea y la otra lo
    /// rellena con lo que solo se sabe estando allí.
    @State private var tomandoLista: Servicio?

    private var elegido: Servicio? {
        vm.lista.first { $0.id == seleccion } ?? vm.lista.first
    }

    var body: some View {
        // **`HStack` y no `HSplitView`, y es por una medida.**
        //
        // El `HSplitView` de macOS no comprime por debajo del tamaño IDEAL de
        // sus paneles, así que esta pantalla imponía un ancho mínimo de ventana
        // de más de **2000 puntos** —más que la pantalla de Iván— y la ventana
        // se quedaba estancada: no se podía achicar ni ajustar. Medido con
        // `set size` en las quince secciones; las tres que usaban `HSplitView`
        // —Reportes, Cartas y Registro de servicios— eran las únicas que no
        // cedían, contra los 964 de una tabla.
        //
        // Lo que se pierde es arrastrar el divisor. Lo que se gana es que la
        // ventana se pueda usar en media pantalla, que es como se trabaja con
        // dos ventanas al lado.
        HStack(spacing: 0) {
            lista
                .frame(width: 268)
                    Divider()
            detalle
                .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: Binding(
            get: { estado.pidiendoAlta },
            set: { estado.pidiendoAlta = $0 }
        )) {
            NuevoCulto(proximoId: vm.proximoId) { nuevo in
                Task {
                    await vm.agregarServicioEsperando(nuevo)
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
        .sheet(item: $tomandoLista) { culto in
            TomarAsistencia(servicio: culto) { actualizado in
                Task {
                    await vm.guardarServicioEsperando(actualizado)
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
        .toolbar {
            // **"Tomar asistencia" cuelga del culto elegido**, no de la
            // sección: es lo que se le hace a UNO, como el seguimiento de una
            // persona. Por eso no va en el ⌥⌘N, que crea.
            ToolbarItem(placement: .automatic) {
                Button(L.t("Tomar asistencia…", "Take attendance…")) {
                    tomandoLista = elegido
                }
                .disabled(elegido == nil)
            }
        }
    }

    // MARK: - La lista

    private var lista: some View {
        List(vm.lista, selection: $seleccion) { s in
            HStack(spacing: 12) {
                // El bloque de fecha, como en la maqueta: día de la semana
                // arriba y número debajo.
                VStack(spacing: 0) {
                    Text(s.diaSemana)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(s.numDia)
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                }
                .frame(width: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(s.titulo)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(s.fechaLegible)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                pastillaRoster(s.estadoRoster)
            }
            .padding(.vertical, 3)
            .tag(s.id)
        }
    }

    private func pastillaRoster(_ e: EstadoRoster) -> some View {
        Text(e.etiqueta)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(e.estadoVisual.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(e.estadoVisual.color.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - El detalle

    @ViewBuilder
    private var detalle: some View {
        if let s = elegido {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    encabezado(s)
                    conteos(s)
                    HStack(alignment: .top, spacing: 12) {
                        roster(s)
                        orden(s)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        visitantes(s)
                        historico(s)
                    }
                }
                .padding(22)
            }
            .background(Color.suelo)
        } else {
            ContentUnavailableView {
                Label(L.t("Ningún culto elegido", "No service selected"), systemImage: "book")
            } description: {
                Text(L.t("Elige uno de la lista para ver su ficha.",
                         "Pick one from the list to see its details."))
            }
            .background(Color.suelo)
        }
    }

    private func encabezado(_ s: Servicio) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(s.titulo).font(.system(size: 20, weight: .bold))
            Text(s.fechaLegible)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            if !s.tituloMensaje.isEmpty || !s.textoBiblico.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    if !s.tituloMensaje.isEmpty {
                        Text(s.tituloMensaje).font(.system(size: 14, weight: .semibold))
                    }
                    if !s.textoBiblico.isEmpty {
                        Text(s.textoBiblico)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 12)
            }

            HStack(spacing: 18) {
                quien(L.t("Dirige", "Led by"), s.dirige)
                quien(L.t("Predica", "Preacher"), s.predica)
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tarjetaMac(14)
    }

    private func quien(_ rotulo: String, _ nombre: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(rotulo).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(nombre.isEmpty ? "—" : nombre)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(nombre.isEmpty ? .tertiary : .primary)
        }
    }

    /// Los cuatro conteos y, debajo, la proporción contra el padrón.
    private func conteos(_ s: Servicio) -> some View {
        let datos = [
            (L.t("Niños", "Children"), s.ninos),
            (L.t("Jóvenes", "Youth"), s.jovenes),
            (L.t("Adultos", "Adults"), s.adultos),
            (L.t("Total presentes", "Total present"), s.totalAsistencia),
        ]
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ForEach(Array(datos.enumerated()), id: \.offset) { i, d in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(d.0).font(.system(size: 11.5)).foregroundStyle(.secondary)
                        // **Cero no es lo mismo que "no se contó".** Un culto al
                        // que no vino nadie no existe; lo que existe es un culto
                        // cuya asistencia nadie apuntó.
                        Text(s.totalAsistencia == 0 ? "—" : "\(d.1)")
                            .font(.system(size: 21, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(i == 3 ? Paleta.brand : .primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let a = s.contraPadron {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("\(Int(a.pct * 100))%")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Paleta.brand)
                        Spacer(minLength: 6)
                        Text(L.t("\(a.presentes) de \(a.total) en el padrón",
                                 "\(a.presentes) of \(a.total) on the roster"))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule().fill(Paleta.brand)
                                .frame(width: g.size.width * CGFloat(min(1, a.pct)))
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.top, 14)
            }
        }
        .padding(16)
        .tarjetaMac(14)
    }

    private func roster(_ s: Servicio) -> some View {
        panel(L.t("ROSTER", "ROSTER")) {
            if s.puestos.isEmpty {
                nada(L.t("Este culto no tiene puestos definidos.",
                         "This service has no posts defined."))
            } else {
                VStack(spacing: 0) {
                    ForEach(s.puestos) { p in
                        HStack(spacing: 10) {
                            Text(p.etiqueta)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 110, alignment: .leading)
                            // Los huecos se dicen, y en ámbar: es lo que hay
                            // que resolver antes del domingo.
                            Text(p.asignado ? p.nombre : L.t("Asignar encargado", "Assign person"))
                                .font(.system(size: 12.5, weight: p.asignado ? .medium : .regular))
                                .foregroundStyle(p.asignado ? .primary : Color.secondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) { Divider() }
                    }
                }
                .padding(.top, 10)
            }
        }
    }

    private func orden(_ s: Servicio) -> some View {
        panel(L.t("ORDEN DEL CULTO", "ORDER OF SERVICE")) {
            if s.orden.isEmpty {
                nada(L.t("Sin orden anotado.", "No order recorded."))
            } else {
                VStack(spacing: 0) {
                    ForEach(s.orden.sorted { $0.posicion < $1.posicion }) { o in
                        HStack(alignment: .top, spacing: 10) {
                            Text(o.hora.isEmpty ? "—" : o.hora)
                                .font(.system(size: 11.5))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(o.titulo).font(.system(size: 12.5, weight: .medium))
                                if !o.encargado.isEmpty {
                                    Text(o.encargado)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) { Divider() }
                    }
                }
                .padding(.top, 10)
            }
        }
    }

    private func visitantes(_ s: Servicio) -> some View {
        panel(L.t("VISITANTES", "VISITORS")) {
            if s.visitantes.isEmpty {
                // Las palabras del handoff: **"nadie NUEVO"**, que es distinto
                // de "nadie". Un culto sin visitantes anotados no dice que no
                // viniera nadie de fuera: dice que no se apuntó a nadie.
                nada(L.t("No se anotó a nadie nuevo en este culto.",
                         "Nobody new was logged in this service."))
            } else {
                VStack(spacing: 0) {
                    ForEach(s.visitantes) { v in
                        HStack(spacing: 9) {
                            Text(v.nombre).font(.system(size: 12.5, weight: .medium))
                            // Quien viene por primera vez es a quien hay que
                            // llamar esta semana.
                            if v.primeraVisita {
                                Text(L.t("Primera visita", "First visit"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Paleta.brand)
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(Paleta.brandFill,
                                                in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                            Spacer(minLength: 0)
                            if let por = v.invitadoPor, !por.isEmpty {
                                Text(L.t("Invitó \(por)", "Invited by \(por)"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) { Divider() }
                    }
                }
            }
            // **Lo mismo que dice la hoja al anotarlos**, y aquí importa más:
            // quien mira la lista puede creer que esas personas ya están en el
            // padrón, y no lo están.
            Text(L.t("Un visitante sin ficha se guarda con el culto, no en el padrón. Darlo de alta es otro paso.",
                     "A visitor without a file is saved with the service, not in the roster. Adding them to the registry is a separate step."))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
    }

    private func historico(_ s: Servicio) -> some View {
        panel(L.t("HISTÓRICO DE ASISTENCIA", "ATTENDANCE HISTORY")) {
            if s.historial.isEmpty {
                nada(L.t("Todavía no hay con qué comparar.", "Nothing to compare with yet."))
            } else {
                Chart(s.historial) { a in
                    BarMark(x: .value("Fecha", a.fecha),
                            y: .value("Presentes", a.presentes))
                        .foregroundStyle(Paleta.brand)
                        .cornerRadius(3)
                }
                .frame(height: 130)
                .padding(.top, 12)
            }
        }
        .frame(width: 320)
    }

    // MARK: - Piezas

    private func panel<C: View>(_ titulo: String, @ViewBuilder c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titulo)
                .font(.system(size: 11, weight: .bold)).kerning(0.5)
                .foregroundStyle(.secondary)
            c()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tarjetaMac(14)
    }

    private func nada(_ t: String) -> some View {
        Text(t).font(.system(size: 12)).foregroundStyle(.tertiary).padding(.vertical, 18)
    }
}

extension Servicio {
    var totalAsistencia: Int { ninos + jovenes + adultos }

    /// La cuenta de ESTE culto contra el padrón, si se tomó.
    /// Se busca por fecha en el histórico, que es donde vive `presentes/total`.
    var contraPadron: AsistenciaServicio? {
        historial.first { $0.fecha == fecha }
    }
}
