import SwiftUI

/// **Informes de membresía, rediseñada para el Mac.**
///
/// El mismo patrón que Cartas y que Reportes en la maqueta: los informes a la
/// izquierda, el papel a la derecha. Y por el mismo motivo — un informe existe
/// para salir impreso o en PDF, así que la pantalla tiene que enseñar la hoja,
/// no una versión de la hoja adaptada a la pantalla.
///
/// En el iPad los cuatro informes son pestañas y la hoja ocupa todo: elegir
/// otro es perder de vista el que estabas leyendo. Aquí la lista se queda
/// puesta y solo cambia el papel.
struct PantallaInformes: View {
    let vm: InformesMembresiaViewModel

    private let informes: [(String, String)] = [
        (L.t("General", "General"),
         L.t("Distribuciones, altas y traslados", "Distributions, additions & transfers")),
        (L.t("Miembros", "Members"),
         L.t("El padrón del periodo", "The roster for the period")),
        (L.t("Asistencia", "Attendance"),
         L.t("Servicios y promedio congregacional", "Services and congregational average")),
        (L.t("Seguimiento", "Follow-up"),
         L.t("Alertas pastorales sin revisar", "Unreviewed pastoral alerts")),
    ]

    var body: some View {
        HSplitView {
            lista
                .frame(minWidth: 220, idealWidth: 276, maxWidth: 340)
            ScrollView {
                hoja.padding(28)
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fondoAgrupado)
        }
        .task { await vm.cargarPadron() }
    }

    // MARK: - Los cuatro

    private var lista: some View {
        List(selection: Binding(
            get: { vm.informeSeleccionado },
            set: { vm.informeSeleccionado = $0 ?? 0 }
        )) {
            Section(L.t("INFORMES", "REPORTS")) {
                ForEach(Array(informes.enumerated()), id: \.offset) { i, inf in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(inf.0).font(.system(size: 12.5, weight: .semibold))
                            Spacer(minLength: 0)
                            // **El número de alertas va en su fila**, que es
                            // donde significa algo: "Seguimiento (4)" dice que
                            // hay cuatro personas esperando una llamada.
                            if i == 3, vm.alertas.count > 0 {
                                Text("\(vm.alertas.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Paleta.aviso)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Paleta.aviso.opacity(0.16), in: Capsule())
                            }
                        }
                        Text(inf.1)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                    .tag(i)
                }
            }
        }
    }

    // MARK: - El papel

    @ViewBuilder
    private var hoja: some View {
        HojaInforme(titulo: informes[min(vm.informeSeleccionado, 3)].0,
                    periodo: vm.resumen.periodo) {
            switch vm.informeSeleccionado {
            case 1:  cuerpoMiembros
            case 2:  cuerpoAsistencia
            case 3:  cuerpoSeguimiento
            default: cuerpoGeneral
            }
        }
    }

    // MARK: General

    @ViewBuilder
    private var cuerpoGeneral: some View {
        let r = vm.resumen
        TresCifras(valores: [
            (L.t("Miembros", "Members"), "\(r.totalMiembros)"),
            (L.t("Expediente completo", "Complete record"), "\(r.expedienteCompleto)"),
            (L.t("Incompleto", "Incomplete"), "\(r.expedienteIncompleto)"),
        ])

        if !r.porEstado.isEmpty {
            BloqueInforme(L.t("Por estado", "By status")) {
                ForEach(Array(r.porEstado.enumerated()), id: \.offset) { _, par in
                    RenglonInforme(par.0, "\(par.1)", total: r.totalMiembros)
                }
            }
        }

        if !r.porMinisterio.isEmpty {
            BloqueInforme(L.t("Por ministerio", "By ministry")) {
                ForEach(Array(r.porMinisterio.enumerated()), id: \.offset) { _, par in
                    RenglonInforme(par.0, "\(par.1)", total: r.totalMiembros)
                }
            }
        }

        if !r.traslados.isEmpty {
            // **`ForEach` directo y sin `enumerated()`.** `MovimientoTraslado`
            // ya es `Identifiable`, y envolverlo en `Array(...)` hacía que el
            // compilador tropezara con el `Array.init` que añade GRDB: el
            // error hablaba de `Cursor`, que no tiene nada que ver con esta
            // pantalla. Cuando un tipo ya se identifica solo, pedirle el
            // índice sobra.
            BloqueInforme(L.t("Traslados", "Transfers")) {
                ForEach(r.traslados) { t in
                    RenglonInforme("\(t.persona) · \(t.iglesia)", t.tipoTraslado)
                }
            }
        }
    }

    // MARK: Miembros

    @ViewBuilder
    private var cuerpoMiembros: some View {
        // Los ocho recortes del padrón, con su cuenta. Los que no tienen a
        // nadie no se imprimen: un renglón en cero no informa de nada.
        BloqueInforme(L.t("El padrón, por recorte", "The roster, by slice")) {
            ForEach(TarjetaPadron.allCases) { t in
                let n = vm.cuenta(t)
                if n > 0 {
                    RenglonInforme(t.etiqueta, "\(n)", total: vm.cuenta(.todos))
                }
            }
        }
    }

    // MARK: Asistencia

    @ViewBuilder
    private var cuerpoAsistencia: some View {
        if let a = vm.asistencia {
            TresCifras(valores: [
                (L.t("Servicios", "Services"), "\(a.serviciosPeriodo)"),
                (L.t("Promedio", "Average"), "\(a.presentesPromedio)"),
                (L.t("Asistencia", "Attendance"), "\(a.promedioPct)%"),
            ])

            // **El aviso que evita que el informe parezca roto.** Hubo cultos,
            // pero si en ninguno se tomó lista cada miembro sale en "—" y esto
            // se lee como un fallo en vez de como "falta tomar lista".
            if vm.sinListasTomadas {
                Text(L.t("Hubo servicios en el periodo, pero no se tomó lista en ninguno.",
                         "There were services in this period, but attendance was never taken."))
                    .font(.system(size: 11))
                    .foregroundStyle(Paleta.aviso)
                    .padding(.top, 14)
            }

            if !a.mejorServicio.isEmpty {
                BloqueInforme(L.t("Mejor servicio", "Best attended")) {
                    RenglonInforme(a.mejorServicio, "")
                }
            }
        } else {
            Text(L.t("Todavía no hay datos de asistencia en el periodo.",
                     "No attendance data for this period yet."))
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                .padding(.top, 20)
        }
    }

    // MARK: Seguimiento

    @ViewBuilder
    private var cuerpoSeguimiento: some View {
        if vm.alertas.isEmpty {
            Text(L.t("Nadie necesita seguimiento ahora mismo.",
                     "Nobody needs follow-up right now."))
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                .padding(.top, 20)
        } else {
            BloqueInforme(L.t("Personas por acompañar", "People to follow up with")) {
                ForEach(vm.alertas) { a in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(a.miembro.nombre)
                                .font(.system(size: 12, weight: .semibold))
                            Spacer(minLength: 0)
                            Text(a.tipo.etiqueta)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Paleta.aviso)
                        }
                        Text(a.detalle)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                    }
                    .padding(.vertical, 5)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color(white: 0.94)).frame(height: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Las piezas del papel

/// La hoja, con el membrete de la iglesia. **Blanca también en modo oscuro**:
/// es una previsualización del papel, y el papel es blanco.
struct HojaInforme<C: View>: View {
    let titulo: String
    let periodo: String
    @ViewBuilder let cuerpo: () -> C
    @State private var iglesia = ConfiguracionIglesiaViewModel.compartido

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Text(iglesia.config.iniciales)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Paleta.brand,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(iglesia.config.nombre.isEmpty
                         ? L.t("Tu iglesia", "Your church") : iglesia.config.nombre)
                        .font(.system(size: 16, weight: .bold))
                    Text(L.t("Informe de membresía", "Membership report"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                }
                Spacer(minLength: 0)
                Text(Date().formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
            }
            .padding(.bottom, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Paleta.brand).frame(height: 2)
            }

            Text(titulo)
                .font(.system(size: 19, weight: .bold))
                .padding(.top, 26)
            if !periodo.isEmpty {
                Text(periodo)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                    .padding(.top, 2)
            }

            cuerpo()
            Spacer(minLength: 30)
        }
        .padding(.horizontal, 52)
        .padding(.vertical, 48)
        .frame(width: 612, alignment: .leading)
        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.12))
        .background(.white)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }
}

/// Las tres cifras de cabecera, como las del estado financiero de la maqueta.
struct TresCifras: View {
    let valores: [(String, String)]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(valores.enumerated()), id: \.offset) { _, v in
                VStack(alignment: .leading, spacing: 3) {
                    Text(v.0)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                    Text(v.1)
                        .font(.system(size: 17, weight: .bold))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(white: 0.96),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .padding(.top, 22)
    }
}

struct BloqueInforme<C: View>: View {
    let titulo: String
    @ViewBuilder let contenido: () -> C
    init(_ titulo: String, @ViewBuilder contenido: @escaping () -> C) {
        self.titulo = titulo
        self.contenido = contenido
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titulo)
                .font(.system(size: 12.5, weight: .bold))
                .padding(.top, 26)
                .padding(.bottom, 4)
            contenido()
        }
    }
}

/// Un renglón del informe. Con `total`, pinta además la proporción — que es lo
/// que convierte "18" en información: 18 de 40 no es lo mismo que 18 de 400.
struct RenglonInforme: View {
    let rotulo: String
    let valor: String
    var total: Int? = nil

    init(_ rotulo: String, _ valor: String, total: Int? = nil) {
        self.rotulo = rotulo
        self.valor = valor
        self.total = total
    }

    private var fraccion: Double {
        guard let total, total > 0, let n = Double(valor) else { return 0 }
        return min(1, n / Double(total))
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(rotulo).font(.system(size: 12))
            Spacer(minLength: 8)
            if total != nil, fraccion > 0 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(white: 0.92))
                        Capsule().fill(Paleta.brand)
                            .frame(width: g.size.width * fraccion)
                    }
                }
                .frame(width: 110, height: 5)
            }
            Text(valor)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(white: 0.94)).frame(height: 1)
        }
    }
}
