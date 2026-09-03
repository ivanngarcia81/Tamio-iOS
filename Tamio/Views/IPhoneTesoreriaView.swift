import SwiftUI

/// Hub de Tesorería para iPhone, fiel al handoff: KPI de saldo en caja,
/// sección REGISTRO (Movimientos, Aportantes, Depósitos) y ANÁLISIS (Reportes).
struct IPhoneTesoreriaView: View {
    @State private var vm = DashboardViewModel()

    var body: some View {
        List {
            Section {
                kpiSaldo
            }

            Section(L.t("REGISTRO", "RECORDS")) {
                NavigationLink { MovimientosView(tipo: .ingreso) } label: {
                    HubRow(icono: "arrow.left.arrow.right", color: Color(hex: 0x10B981),
                           titulo: L.t("Movimientos", "Transactions"),
                           subtitulo: L.t("132 registros · 14 sin depositar",
                                          "132 records · 14 undeposited"))
                }
                NavigationLink { MiembrosView() } label: {
                    HubRow(icono: "person.2.fill", color: Color(hex: 0x0D9488),
                           titulo: L.t("Aportantes", "Contributors"),
                           subtitulo: L.t("Diezmos y ofrendas por persona",
                                          "Tithes & offerings per person"))
                }
                NavigationLink { DepositosView() } label: {
                    HubRow(icono: "building.columns.fill", color: Paleta.aviso,
                           titulo: L.t("Depósitos", "Deposits"),
                           subtitulo: L.t("1 corte pendiente · Banorte ••4821",
                                          "1 pending cut · Banorte ••4821"),
                           badge: 1)
                }
            }

            Section(L.t("ANÁLISIS", "ANALYSIS")) {
                NavigationLink { ReportesView() } label: {
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
            Text(L.t("14 movimientos sin depositar · corte el domingo",
                     "14 transactions undeposited · closes Sunday"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

/// Punto de entrada unificado para Ingresos y Gastos: selector en la barra
/// de navegación que conmuta entre las dos vistas existentes.
