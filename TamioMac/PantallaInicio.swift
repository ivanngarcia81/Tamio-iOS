import SwiftUI
import Charts

/// **Inicio, tal como lo dibuja la maqueta.**
///
/// Cuatro tarjetas arriba, la gráfica de ingresos contra gastos y la dona de
/// categorías, y abajo la actividad reciente junto a la semana. Todo sale de
/// `DashboardData`, que ya traía exactamente estas piezas — barras de seis
/// meses, dona de ingresos por categoría, recientes y agenda— porque el
/// Dashboard de iOS pinta lo mismo con otra forma.
struct PantallaInicio: View {
    let vm: DashboardViewModel
    let nombre: String
    /// Para que "Ver todos" y "Abrir bandeja" lleven a algún sitio.
    let ir: (SeccionMac) -> Void

    private var d: DashboardData? { vm.data }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                saludo
                tarjetas
                HStack(alignment: .top, spacing: 14) {
                    grafica.frame(maxWidth: .infinity)
                    dona.frame(width: 300)
                }
                HStack(alignment: .top, spacing: 14) {
                    recientes.frame(maxWidth: .infinity)
                    semana.frame(width: 300)
                }
            }
            .padding(26)
        }
        .task { await vm.cargar() }
    }

    // MARK: - Saludo

    private var saludo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(salutacion)
                .font(.system(size: 26, weight: .bold))
            Text(subtituloDelDia)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    /// **Buenos días, buenas tardes o buenas noches.** La maqueta dice "Good
    /// morning" porque la dibujaron a las 9:41; una app que saluda con "buenos
    /// días" a las once de la noche se nota enseguida que no mira la hora.
    private var salutacion: String {
        let h = Calendar.current.component(.hour, from: Date())
        let saludo: String
        switch h {
        case 0..<12:  saludo = L.t("Buenos días", "Good morning")
        case 12..<19: saludo = L.t("Buenas tardes", "Good afternoon")
        default:      saludo = L.t("Buenas noches", "Good evening")
        }
        let n = nombre.split(separator: " ").first.map(String.init) ?? ""
        return n.isEmpty ? saludo : "\(saludo), \(n)"
    }

    private var subtituloDelDia: String {
        let hoy = Date().formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard let dias = d?.corteDias, dias > 0 else { return hoy }
        return L.t("\(hoy) · el mes cierra en \(dias) días",
                   "\(hoy) · month closes in \(dias) days")
    }

    // MARK: - Las cuatro tarjetas

    private var tarjetas: some View {
        HStack(spacing: 14) {
            TarjetaKPI(rotulo: L.t("Saldo en caja", "Cash on hand"),
                       valor: Money.fmt(d?.saldoCaja ?? 0),
                       delta: d?.deltaSaldo,
                       nota: d.map { L.t("\($0.sinDepositarCount) sin depositar",
                                         "\($0.sinDepositarCount) not deposited") })
            TarjetaKPI(rotulo: L.t("Ingresos del periodo", "Period income"),
                       valor: Money.fmt(d?.ingresos ?? 0),
                       delta: d?.deltaIngresos,
                       nota: d.map { registros($0.registrosIngreso) })
            TarjetaKPI(rotulo: L.t("Gastos del periodo", "Period expenses"),
                       valor: Money.fmt(d?.gastos ?? 0),
                       delta: d?.deltaGastos,
                       deltaAlRevés: true,
                       nota: d.map { registros($0.registrosGasto) })
            TarjetaKPI(rotulo: L.t("Por revisar", "To review"),
                       valor: "\(d?.pendientes ?? 0)",
                       enlace: L.t("Abrir la bandeja →", "Open tray →"),
                       accion: { ir(.porRevisar) })
        }
    }

    private func registros(_ n: Int) -> String {
        n == 1 ? L.t("1 registro", "1 record") : L.t("\(n) registros", "\(n) records")
    }

    // MARK: - Ingresos contra gastos

    private var grafica: some View {
        Tarjeta(titulo: L.t("Ingresos contra gastos", "Income vs expenses"),
                extra: L.t("Últimos 6 meses", "Last 6 months")) {
            if let tramos = d?.tramos, !tramos.isEmpty {
                Chart {
                    ForEach(tramos) { t in
                        BarMark(x: .value("Mes", t.etiqueta),
                                y: .value("Importe", Double(t.ingresos) / 100))
                            .foregroundStyle(Paleta.brand)
                            .position(by: .value("Serie", L.t("Ingresos", "Income")))
                        BarMark(x: .value("Mes", t.etiqueta),
                                y: .value("Importe", Double(t.gastos) / 100))
                            .foregroundStyle(Paleta.brandMuted)
                            .position(by: .value("Serie", L.t("Gastos", "Expenses")))
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 168)
                .padding(.top, 12)
            } else {
                vacio(L.t("Todavía no hay meses que comparar",
                          "No months to compare yet"))
            }
        }
    }

    // MARK: - La dona

    private var dona: some View {
        Tarjeta(titulo: L.t("Ingresos por categoría", "Income by category")) {
            let cats = d?.ingresosPorCategoria ?? []
            if cats.isEmpty {
                vacio(L.t("Sin ingresos en el periodo", "No income this period"))
            } else {
                Chart(cats) { c in
                    SectorMark(angle: .value("Importe", Double(c.monto) / 100),
                               innerRadius: .ratio(0.62), angularInset: 1.5)
                        .foregroundStyle(Paleta.categoria(Catalogos.clave(deEtiqueta: c.nombre),
                                                          nombre: c.nombre))
                        .cornerRadius(3)
                }
                .frame(height: 140)
                .padding(.top, 10)

                VStack(spacing: 7) {
                    ForEach(cats) { c in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Paleta.categoria(Catalogos.clave(deEtiqueta: c.nombre),
                                                       nombre: c.nombre))
                                .frame(width: 9, height: 9)
                            Text(c.nombre).font(.system(size: 12)).lineLimit(1)
                            Spacer(minLength: 6)
                            Text(Money.fmt(c.monto))
                                .font(.system(size: 12))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Reciente y la semana

    private var recientes: some View {
        Tarjeta(titulo: L.t("Actividad reciente", "Recent activity"),
                enlace: L.t("Ver todos", "See all"),
                accion: { ir(.ingresos) }) {
            let tx = d?.recientes ?? []
            if tx.isEmpty {
                vacio(L.t("Todavía no hay movimientos", "No transactions yet"))
            } else {
                VStack(spacing: 0) {
                    ForEach(tx) { t in
                        HStack(spacing: 11) {
                            Text(t.titular.prefix(1).uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Paleta.sobreRelleno)
                                .frame(width: 30, height: 30)
                                .background(Paleta.categoria(Catalogos.clave(deEtiqueta: t.categoria),
                                                             nombre: t.categoria),
                                            in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t.titular)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .lineLimit(1)
                                Text("\(t.categoria) · \(t.metodo)")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            Text(Money.firmado(t.monto, ingreso: t.tipo == .ingreso))
                                .font(.system(size: 13, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Money.color(ingreso: t.tipo == .ingreso))
                        }
                        .padding(.vertical, 9)
                        .overlay(alignment: .top) { Divider() }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var semana: some View {
        Tarjeta(titulo: L.t("Esta semana", "This week"),
                enlace: L.t("Agenda", "Calendar"),
                accion: { ir(.agenda) }) {
            let items = d?.semana ?? []
            if items.isEmpty {
                vacio(L.t("Nada agendado esta semana", "Nothing scheduled this week"))
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { e in
                        HStack(spacing: 11) {
                            VStack(spacing: 0) {
                                Text(e.dia)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(e.num)
                                    .font(.system(size: 15, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .frame(width: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.titulo)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .lineLimit(1)
                                Text(e.subtitulo)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 9)
                        .overlay(alignment: .top) { Divider() }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func vacio(_ texto: String) -> some View {
        Text(texto)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
    }
}

// MARK: - Piezas

/// Una tarjeta de cifra. La variación va con su flecha y su color.
struct TarjetaKPI: View {
    let rotulo: String
    let valor: String
    var delta: Double? = nil
    /// **Para Gastos, subir es malo.** Sin esto la tarjeta pintaría en verde
    /// que este mes se gastó un 12 % más, que es exactamente al revés.
    var deltaAlRevés: Bool = false
    var nota: String? = nil
    var enlace: String? = nil
    var accion: (() -> Void)? = nil

    private var tintaDelta: Color {
        guard let delta else { return .secondary }
        let bueno = deltaAlRevés ? delta < 0 : delta > 0
        return bueno ? Paleta.brand : Paleta.negativo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(rotulo)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
            Text(valor)
                .font(.system(size: 25, weight: .bold))
                .monospacedDigit()
                .padding(.top, 6)
            HStack(spacing: 6) {
                if let nota {
                    Text(nota).foregroundStyle(.secondary)
                }
                // **La variación solo si HAY con qué comparar.** En el primer
                // mes de una iglesia no hay periodo anterior, y un "▲ 0 %"
                // inventado es peor que no decir nada.
                if let delta {
                    Text("\(delta >= 0 ? "▲" : "▼") \(abs(delta * 100), specifier: "%.1f")%")
                        .fontWeight(.semibold)
                        .foregroundStyle(tintaDelta)
                }
            }
            .font(.system(size: 12))
            .padding(.top, 5)

            if let enlace, let accion {
                Button(enlace, action: accion)
                    .buttonStyle(.link)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.top, 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(.background.secondary,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// El contenedor blanco con su título, y opcionalmente un enlace a la derecha.
struct Tarjeta<C: View>: View {
    let titulo: String
    var extra: String? = nil
    var enlace: String? = nil
    var accion: (() -> Void)? = nil
    @ViewBuilder let contenido: () -> C

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo).font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                if let extra {
                    Text(extra).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                if let enlace, let accion {
                    Button(enlace, action: accion)
                        .buttonStyle(.link)
                        .font(.system(size: 12))
                }
            }
            contenido()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
