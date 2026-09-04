import SwiftUI

/// Raíz de la app. En iPad (regular) es un maestro-detalle con la sidebar de
/// navegación, como el handoff. En iPhone (compacto) se colapsa a una pila con
/// el Dashboard directo — la sidebar del iPad no aplica al teléfono.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// La selección de la sidebar vive en `Navegacion` para que otras
    /// pantallas puedan moverla (el "Ver todos" del Inicio, por ejemplo).
    @Environment(Navegacion.self) private var nav
    // `.automatic`: en landscape se ven sidebar + detalle; en PORTRAIT la
    // sidebar se colapsa a un botón y el detalle ocupa todo el ancho — así el
    // maestro-detalle interno de Movimientos no queda aplastado. Antes estaba
    // en `.all`, que forzaba las tres columnas a la vez en portrait.
    @State private var columnas: NavigationSplitViewVisibility = .automatic

    var body: some View {
        @Bindable var nav = nav
        if sizeClass == .regular {
            NavigationSplitView(columnVisibility: $columnas) {
                Sidebar(seleccion: $nav.seccion)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 250, max: 300)
            } detail: {
                // El área de detalle enruta según la sección elegida en la
                // sidebar. Cada pantalla trae su propio layout (el Dashboard es
                // una sola vista; Ingresos/Gastos son maestro-detalle).
                switch nav.seccion {
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
                        etiquetaSeccion(nav.seccion),
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

    /// Franja de aviso del modo revisión. Un modo que cambia el origen de los
    /// datos y salta la autenticación no puede ser invisible.
    @ViewBuilder
    static var avisoRevision: some View {
        if ModoRevision.sinLogin {
            Text(L.t("MODO REVISIÓN · sin sesión · datos de ejemplo",
                     "REVIEW MODE · no session · sample data"))
                .font(.caption2.weight(.bold))
                // Texto OSCURO, no blanco. Sobre el naranja de aviso el blanco
                // da 3.6:1 en claro y 2.0:1 en oscuro —el modo oscuro aclaró el
                // fondo sin oscurecer el texto—, las dos por debajo del 4.5:1
                // que pide un texto pequeño. El negro da 5.9:1 y 10.3:1, así
                // que sirve para las dos apariencias sin un color nuevo.
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Paleta.aviso)
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
    @Environment(Navegacion.self) private var nav

    var body: some View {
        @Bindable var nav = nav
        // La pestaña se elige por `selection` para que otras pantallas puedan
        // cambiarla, igual que la sidebar del iPad.
        TabView(selection: $nav.pestana) {
            NavigationStack { DashboardView() }
                .tabItem { Label(L.t("Inicio", "Home"), systemImage: "house") }
                .tag(Navegacion.Pestana.inicio)

            NavigationStack { IPhoneTesoreriaView() }
                .tabItem { Label(L.t("Tesorería", "Treasury"), systemImage: "dollarsign.circle") }
                .tag(Navegacion.Pestana.tesoreria)

            NavigationStack { RevisarView() }
                .tabItem { Label(L.t("Por revisar", "To review"), systemImage: "tray") }
                .badge(revisarVM.porRevisarCount)
                .tag(Navegacion.Pestana.revisar)

            NavigationStack { IPhoneSecretariaView() }
                .tabItem { Label(L.t("Secretaría", "Secretary"), systemImage: "person.text.rectangle") }
                .tag(Navegacion.Pestana.secretaria)

            NavigationStack { IPhoneAjustesView() }
                .tabItem { Label(L.t("Ajustes", "Settings"), systemImage: "gearshape") }
                .tag(Navegacion.Pestana.ajustes)
        }
        .tint(Paleta.brand)
        // `.ultraThinMaterial` es el material más transparente del sistema: dejaba
        // leer el contenido por debajo de la barra. `.bar` es el que usa el sistema
        // para tab bars, y `.visible` evita que se retire cuando nada scrollea.
        .toolbarBackground(.bar, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task { await revisarVM.cargar() }
    }
}
