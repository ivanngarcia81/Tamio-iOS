import SwiftUI

/// Raíz de la app. En iPad (regular) es un maestro-detalle con la sidebar de
/// navegación, como el handoff. En iPhone (compacto) se colapsa a una pila con
/// el Dashboard directo — la sidebar del iPad no aplica al teléfono.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var seleccion = "inicio"
    // `.automatic`: en landscape se ven sidebar + detalle; en PORTRAIT la
    // sidebar se colapsa a un botón y el detalle ocupa todo el ancho — así el
    // maestro-detalle interno de Movimientos no queda aplastado. Antes estaba
    // en `.all`, que forzaba las tres columnas a la vez en portrait.
    @State private var columnas: NavigationSplitViewVisibility = .automatic

    var body: some View {
        if sizeClass == .regular {
            NavigationSplitView(columnVisibility: $columnas) {
                Sidebar(seleccion: $seleccion)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 250, max: 300)
            } detail: {
                // El área de detalle enruta según la sección elegida en la
                // sidebar. Cada pantalla trae su propio layout (el Dashboard es
                // una sola vista; Ingresos/Gastos son maestro-detalle).
                switch seleccion {
                case "inicio":
                    DashboardView()
                case "ingresos":
                    MovimientosView(tipo: .ingreso)
                case "gastos":
                    MovimientosView(tipo: .gasto)
                case "reportes":
                    ReportesView()
                case "depositos":
                    DepositosView()
                case "miembros":
                    MiembrosView()
                case "membresia":
                    MembresiaView()
                case "actas":
                    ActasView()
                case "servicios":
                    ServiciosView()
                case "cartas":
                    CartasView()
                case "informes":
                    InformesMembresiaView()
                case "agenda":
                    AgendaView()
                case "config":
                    ConfiguracionView()
                case "registro":
                    RegistroView()
                case "porRevisar":
                    RevisarView()
                default:
                    ContentUnavailableView(
                        etiquetaSeccion(seleccion),
                        systemImage: "hammer",
                        description: Text(L.t("Esta pantalla llega en un próximo slice.",
                                              "This screen is coming in a later slice."))
                    )
                }
            }
        } else {
            IPhoneRootView()
        }
    }

    /// Nombre legible de una sección aún no construida, para el placeholder.
    private func etiquetaSeccion(_ id: String) -> String {
        switch id {
        case "miembros": return L.t("Miembros", "Members")
        case "reportes": return L.t("Reportes", "Reports")
        case "depositos": return L.t("Depósitos", "Deposits")
        case "porRevisar": return L.t("Por revisar", "To review")
        case "membresia": return L.t("Membresía", "Membership")
        case "actas": return L.t("Actas", "Minutes")
        case "servicios": return L.t("Registro de servicios", "Service log")
        case "cartas": return L.t("Cartas y traslados", "Letters & transfers")
        case "informes": return L.t("Informes de membresía", "Membership reports")
        case "agenda": return L.t("Agenda", "Calendar")
        case "mensajes": return L.t("Mensajes", "Messages")
        case "config": return L.t("Configuración", "Settings")
        default: return "Tamio"
        }
    }
}

/// TabView de cinco pestañas para iPhone. Usa un RevisarViewModel compartido
/// para mantener el badge de "Por revisar" sincronizado con el conteo real.
private struct IPhoneRootView: View {
    @State private var revisarVM = RevisarViewModel()

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label(L.t("Inicio", "Home"), systemImage: "house") }

            NavigationStack { IPhoneTesoreriaView() }
                .tabItem { Label(L.t("Tesorería", "Treasury"), systemImage: "dollarsign.circle") }

            NavigationStack { RevisarView() }
                .tabItem { Label(L.t("Por revisar", "To review"), systemImage: "tray") }
                .badge(revisarVM.porRevisarCount)

            NavigationStack { IPhoneSecretariaView() }
                .tabItem { Label(L.t("Secretaría", "Secretary"), systemImage: "person.text.rectangle") }

            NavigationStack { IPhoneAjustesView() }
                .tabItem { Label(L.t("Ajustes", "Settings"), systemImage: "gearshape") }
        }
        .tint(Paleta.brand)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .task { await revisarVM.cargar() }
    }
}
