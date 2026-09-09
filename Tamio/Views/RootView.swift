import SwiftUI
import UIKit

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
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    private var permisos: Permisos {
        Permisos(rol: sesion?.perfil.rol ?? .administrador, iglesia: cfg.config)
    }

    /// La pantalla, o la explicación de por qué no. **Explicación y no pantalla
    /// en blanco**: quien llega aquí no ha hecho nada mal y tiene que saber a
    /// quién pedirle el acceso.
    @ViewBuilder
    private func conPermiso<C: View>(_ area: Permisos.Area,
                                     @ViewBuilder contenido: () -> C) -> some View {
        if permisos.ve(area) {
            contenido()
        } else {
            ContentUnavailableView(
                L.t("No es tu área", "Not your area"),
                systemImage: "lock",
                description: Text(L.t("Tu rol no entra aquí. Pídele al administrador de la iglesia que te abra el acceso en Ajustes.",
                                      "Your role doesn't have access here. Ask the church administrator to grant it in Settings.")))
        }
    }

    var body: some View {
        @Bindable var nav = nav
        if sizeClass == .regular {
            NavigationSplitView(columnVisibility: $columnas) {
                Sidebar(seleccion: $nav.seccion)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 250, max: 300)
                    // `inicio` es el valor por omisión y la secretaria no lo
                    // tiene: sin esto abriría la app en una pantalla cerrada.
                    .task {
                        if !permisos.ve(.inicio), nav.seccion == "inicio" {
                            nav.seccion = permisos.seccionInicial
                        }
                    }
            } detail: {
                // **`NavigationStack` alrededor del detalle, y es lo que hace
                // que se pueda abrir una ficha en una ventana estrecha.**
                //
                // Las doce pantallas de maestro-detalle se parten por ancho: a
                // partir de `Esp.anchoMaestroDetalle` dibujan lista y detalle
                // lado a lado, y por debajo empujan el detalle con
                // `navigationDestination`. Una columna de detalle de un
                // `NavigationSplitView` trae barra de navegación pero **no una
                // pila**, así que ese `navigationDestination` no tenía dónde
                // empujar: tocar una fila la pintaba de verde y no pasaba nada
                // más.
                //
                // Se ve en cuanto la columna baja de 640 pt sin que la app
                // salga de la clase regular: el iPad mini en vertical con la
                // sidebar fijada (744 − 300), la app a la mitad en Split View,
                // o cualquier ventana de Stage Manager. Medido en el mini:
                // Ingresos, Reportes y Depósitos se quedaban sin ficha y sin
                // botón de volver.
                //
                // **Y cada pantalla cierra su ficha al cambiar de sección**
                // (`cierraAlCambiarSeccion`, en `Pieces.swift`). La raíz de
                // esta pila la elige la sidebar: al cambiarla con una ficha
                // empujada, la raíz cambiaba por debajo y la ficha anterior se
                // quedaba encima —se elegía Reportes y se seguía viendo el
                // movimiento—. Ni vaciar un `NavigationPath` ni cambiar el
                // `id` de la pila la sacan: lo que empuja es el
                // `navigationDestination(item:)` de cada pantalla, así que
                // quien la cierra tiene que ser ese mismo `item`.
                detalle
                    // Y al ensanchar, la sección sigue a la pestaña **solo si
                    // se cambió de pestaña mientras la ventana era estrecha**:
                    // quien solo movió el tamaño vuelve donde estaba.
                    .task {
                        if Navegacion.pestana(de: nav.seccion) != nav.pestana {
                            nav.seccion = Navegacion.seccion(de: nav.pestana)
                        }
                    }
            }
        } else {
            IPhoneRootView()
        }
    }

    /// La pantalla que toca según la sección elegida en la sidebar. Cada una
    /// trae su propio layout (el Dashboard es una sola vista; Ingresos/Gastos
    /// son maestro-detalle).
    ///
    /// **Cada sección pregunta por su área.** La sidebar ya no ofrece lo que no
    /// toca, pero `nav.seccion` se recuerda entre arranques y se puede mover
    /// desde otras pantallas: sin esto, quitarle el rol a alguien no le
    /// cerraría la pantalla que dejó abierta.
    private var detalle: some View {
        NavigationStack {
            // El `ZStack` no es decorativo: es el ancla ESTABLE de la que
            // cuelga el vaciador. Colgado del `switch`, cambiaría de identidad
            // con la sección y no se enteraría del cambio, que es justo lo que
            // tiene que ver.
            ZStack { pantallaDeSeccion }
                .background(VaciarPila(seccion: nav.seccion).frame(width: 0, height: 0))
        }
    }

    @ViewBuilder
    private var pantallaDeSeccion: some View {
        switch nav.seccion {
        case "inicio":
            conPermiso(.inicio) { DashboardView() }
        case "ingresos":
            conPermiso(.tesoreria) { MovimientosView(tipo: .ingreso) }
        case "gastos":
            conPermiso(.tesoreria) { MovimientosView(tipo: .gasto) }
        case "reportes":
            conPermiso(.reportes) { ReportesView() }
        case "depositos":
            conPermiso(.tesoreria) { DepositosView() }
        case "miembros":
            conPermiso(.tesoreria) { MiembrosView() }
        case "membresia":
            conPermiso(.padron) { MembresiaView() }
        case "actas":
            conPermiso(.secretaria) { ActasView() }
        case "servicios":
            conPermiso(.secretaria) { ServiciosView() }
        case "cartas":
            conPermiso(.secretaria) { CartasView() }
        case "informes":
            conPermiso(.secretaria) { InformesMembresiaView() }
        case "agenda":
            conPermiso(.secretaria) { AgendaView() }
        case "config":
            ConfiguracionView()
        case "registro":
            conPermiso(.registro) { RegistroView() }
        case "porRevisar":
            conPermiso(.tesoreria) { RevisarView() }
        default:
            ContentUnavailableView(
                etiquetaSeccion(nav.seccion),
                systemImage: "hammer",
                description: Text(L.t("Esta pantalla llega en un próximo slice.",
                                      "This screen is coming in a later slice."))
            )
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

/// **Vacía la pila del detalle cuando la sidebar cambia de sección.**
///
/// La columna de detalle de un `NavigationSplitView` reutiliza UN
/// `UINavigationController`, y lo que se ha empujado en él **sobrevive a que
/// se reconstruya el árbol de SwiftUI**. Medido en el iPad mini, las tres
/// formas de pedirlo desde arriba se quedan cortas: vaciar un
/// `NavigationPath` no saca lo que empujó un `navigationDestination(item:)`,
/// un `id` nuevo en el `NavigationStack` cambia la raíz pero deja la ficha
/// encima, y una pila por sección hace lo mismo. Con las tres, elegir
/// "Reportes" con un movimiento abierto seguía enseñando el movimiento.
///
/// Tampoco vale que cada pantalla ponga su `item` a `nil` al cambiar la
/// sección: para cuando llega ese aviso, la pantalla ya se está desmontando y
/// su `onChange` no corre.
///
/// Así que se saca por donde se metió. Es el mismo trato que `NavHeader` le da
/// al gesto de volver: cuando el comportamiento vive en UIKit, se arregla en
/// UIKit y se deja escrito por qué.
private struct VaciarPila: UIViewControllerRepresentable {
    let seccion: String

    func makeUIViewController(context: Context) -> UIViewController { Vaciador() }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        (vc as? Vaciador)?.alCambiar(a: seccion)
    }

    final class Vaciador: UIViewController {
        private var ultima: String?

        func alCambiar(a seccion: String) {
            defer { ultima = seccion }
            // La primera pasada solo apunta la sección: no hay nada empujado
            // todavía y un `pop` aquí sería trabajo inútil en cada arranque.
            guard let ultima, ultima != seccion else { return }
            // Sin animación: la raíz ya ha cambiado por debajo, así que
            // deslizar la ficha vieja hacia la derecha enseñaría una
            // transición que no es la que ha pasado.
            navigationController?.popToRootViewController(animated: false)
        }
    }
}

/// TabView de cinco pestañas para iPhone. Usa un RevisarViewModel compartido
/// para mantener el badge de "Por revisar" sincronizado con el conteo real.
private struct IPhoneRootView: View {
    @State private var revisarVM = RevisarViewModel.compartido
    @Environment(Navegacion.self) private var nav
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido

    private var permisos: Permisos {
        Permisos(rol: sesion?.perfil.rol ?? .administrador, iglesia: cfg.config)
    }

    var body: some View {
        @Bindable var nav = nav
        // La pestaña se elige por `selection` para que otras pantallas puedan
        // cambiarla, igual que la sidebar del iPad.
        //
        // **Las pestañas dependen del rol.** No se deshabilitan: se quitan. Una
        // pestaña gris que no lleva a ningún sitio le está diciendo a la
        // secretaria que hay una parte de la app que le falta, y eso no es
        // información suya sino ruido.
        TabView(selection: $nav.pestana) {
            if permisos.ve(.inicio) {
            NavigationStack { DashboardView() }
                .tabItem { Label(L.t("Inicio", "Home"), systemImage: "house") }
                .tag(Navegacion.Pestana.inicio)
            }

            if permisos.ve(.tesoreria) {
            NavigationStack { IPhoneTesoreriaView() }
                .tabItem { Label(L.t("Tesorería", "Treasury"), systemImage: "dollarsign.circle") }
                .tag(Navegacion.Pestana.tesoreria)

            NavigationStack { RevisarView() }
                .tabItem { Label(L.t("Por revisar", "To review"), systemImage: "tray") }
                .badge(revisarVM.porRevisarCount)
                .tag(Navegacion.Pestana.revisar)
            } else if permisos.ve(.reportes) {
            // Reportes vive DENTRO del hub de Tesorería, así que sin esa
            // pestaña la secretaria no tendría por dónde llegar. Se le da
            // su propia entrada en vez de dejarle un hub de Tesorería con
            // una sola fila dentro, que se leería como una tesorería
            // recortada en lugar de como lo que es: acceso al reporte.
            NavigationStack { ReportesView() }
                .tabItem { Label(L.t("Reportes", "Reports"), systemImage: "chart.bar") }
                .tag(Navegacion.Pestana.tesoreria)
            }

            if permisos.ve(.secretaria) {
            NavigationStack { IPhoneSecretariaView() }
                .tabItem { Label(L.t("Secretaría", "Secretary"), systemImage: "person.text.rectangle") }
                .tag(Navegacion.Pestana.secretaria)
            }

            NavigationStack { IPhoneAjustesView() }
            .tabItem { Label(L.t("Ajustes", "Settings"), systemImage: "gearshape") }
            .tag(Navegacion.Pestana.ajustes)
        }
        // La pestaña guardada puede ser una que este rol ya no tenga —o que
        // nunca tuvo, porque `inicio` es el valor por omisión—. Sin esto, la
        // secretaria abriría la app en una pestaña que no existe y vería el
        // TabView en blanco.
        // **La pestaña sigue a la sección al caer a compacto.** Ver
        // `Navegacion.pestana(de:)`: estrechar la ventana desde Ingresos
        // aterrizaba en Inicio.
        .task {
            nav.pestana = Navegacion.pestana(de: nav.seccion)
            corregirPestana()
        }
        .onChange(of: permisos.rol) { _, _ in corregirPestana() }
        .tint(Paleta.brand)
        // `.ultraThinMaterial` es el material más transparente del sistema: dejaba
        // leer el contenido por debajo de la barra. `.bar` es el que usa el sistema
        // para tab bars, y `.visible` evita que se retire cuando nada scrollea.
        .toolbarBackground(.bar, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task { await revisarVM.cargar() }
    }

    private func corregirPestana() {
        let permitidas: [Navegacion.Pestana] = {
            var v: [Navegacion.Pestana] = [.ajustes]
            if permisos.ve(.inicio) { v.append(.inicio) }
            if permisos.ve(.tesoreria) { v.append(contentsOf: [.tesoreria, .revisar]) }
            else if permisos.ve(.reportes) { v.append(.tesoreria) }
            if permisos.ve(.secretaria) { v.append(.secretaria) }
            return v
        }()
        guard !permitidas.contains(nav.pestana) else { return }
        nav.pestana = permisos.ve(.inicio) ? .inicio
            : (permisos.ve(.secretaria) ? .secretaria : .ajustes)
    }
}
