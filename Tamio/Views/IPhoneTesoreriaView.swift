import SwiftUI

/// Hub de Tesorería para iPhone, fiel al handoff: KPI de saldo en caja,
/// sección REGISTRO (Movimientos, Aportantes, Depósitos) y ANÁLISIS (Reportes).
struct IPhoneTesoreriaView: View {
    @State private var vm = DashboardViewModel()
    /// Solo para el conteo de cortes pendientes de la fila "Depósitos": decía
    /// "1 corte pendiente · Banorte ••4821" escrito a mano, y al entrar había
    /// tres, repartidos entre dos bancos. La puerta mentía sobre la sala.
    @State private var depositos = DepositosViewModel()

    var body: some View {
        List {
            Section {
                kpiSaldo
            }

            Section(L.t("REGISTRO", "RECORDS")) {
                NavigationLink { MovimientosView(tipo: .ingreso).sinBotonVolver() } label: {
                    HubRow(icono: "arrow.left.arrow.right", color: Color(hex: 0x10B981),
                           titulo: L.t("Movimientos", "Transactions"),
                           subtitulo: subtituloMovimientos)
                }
                NavigationLink { MiembrosView().sinBotonVolver() } label: {
                    HubRow(icono: "person.2.fill", color: Color(hex: 0x0D9488),
                           titulo: L.t("Aportantes", "Contributors"),
                           subtitulo: L.t("Diezmos y ofrendas por persona",
                                          "Tithes & offerings per person"))
                }
                NavigationLink { DepositosView().sinBotonVolver() } label: {
                    HubRow(icono: "building.columns.fill", color: Paleta.aviso,
                           titulo: L.t("Depósitos", "Deposits"),
                           subtitulo: subtituloDepositos,
                           badge: depositos.pendientesCount)
                }
            }

            Section(L.t("ANÁLISIS", "ANALYSIS")) {
                NavigationLink { ReportesView().sinBotonVolver() } label: {
                    HubRow(icono: "chart.bar.fill", color: Color(hex: 0x0EA5E9),
                           titulo: L.t("Reportes", "Reports"),
                           subtitulo: L.t("Documentos del mes · PDF y hoja",
                                          "Monthly docs · PDF & spreadsheet"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .encabezadoNav(L.t("Tesorería", "Treasury"),
                       "\(L.mesEnCurso) · Banorte ••4821")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.cargar() }
        .task { await depositos.cargar() }
    }

    /// Cuántos ingresos siguen sin depositar. Era "14" escrito a mano debajo de
    /// un saldo que ahora se calcula.
    private var pieSaldo: String {
        guard let n = vm.data?.sinDepositarCount else { return "" }
        return L.t("\(n) movimiento\(n == 1 ? "" : "s") sin depositar",
                   "\(n) transaction\(n == 1 ? "" : "s") undeposited")
    }

    private var subtituloMovimientos: String {
        guard let d = vm.data else { return "" }
        return L.t("\(d.movimientosTotal) registros · \(d.sinDepositarCount) sin depositar",
                   "\(d.movimientosTotal) records · \(d.sinDepositarCount) undeposited")
    }

    /// La cuenta solo se nombra si todos los cortes pendientes van a la misma.
    private var subtituloDepositos: String {
        let n = depositos.pendientesCount
        let cortes = L.t("\(n) corte\(n == 1 ? "" : "s") pendiente\(n == 1 ? "" : "s")",
                         "\(n) pending cut\(n == 1 ? "" : "s")")
        guard let cuenta = depositos.cuentaResumen else { return cortes }
        return "\(cortes) · \(cuenta)"
    }

    private var kpiSaldo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.t("SALDO EN CAJA", "CASH ON HAND"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Group {
                if let d = vm.data {
                    AmountText(cents: d.saldoCaja, size: 26)
                } else {
                    Text("—").font(.system(size: 26, weight: .bold)).foregroundStyle(.secondary)
                }
            }
            Text(pieSaldo)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

/// Punto de entrada unificado para Ingresos y Gastos: selector en la barra
/// de navegación que conmuta entre las dos vistas existentes.
