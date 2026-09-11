import SwiftUI

/// Un renglón de la sidebar: icono + título, badge opcional (gris para conteos,
/// rojo para lo urgente), y el estado seleccionado en verde Tamio con tinte —
/// el único lugar, junto a las cifras, donde el color aparece.
private struct SidebarRow: View {
    let titulo: String
    let icono: String
    var badge: Int? = nil
    var badgeRojo: Bool = false
    let seleccionado: Bool
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 12) {
                Image(systemName: icono)
                    .font(.system(size: 16))
                    .frame(width: 22)
                    .foregroundStyle(seleccionado ? Paleta.brand : .primary)
                Text(titulo)
                    .font(.subheadline)
                    .foregroundStyle(seleccionado ? Paleta.brand : .primary)
                Spacer(minLength: 6)
                if let badge {
                    Text("\(badge)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(badgeRojo ? .white : .secondary)
                        .padding(.horizontal, badgeRojo ? 7 : 2)
                        .padding(.vertical, badgeRojo ? 2 : 0)
                        .background {
                            if badgeRojo { Capsule().fill(Paleta.badge) }
                        }
                }
            }
            .padding(.horizontal, Esp.pantalla)
            .padding(.vertical, 9)
            // **44 pt es el mínimo tocable de iOS, no un token de Tamio**, y
            // por eso va escrito aquí y no en `Esp`. Con `.subheadline` y 9 pt
            // arriba y abajo estas filas medían **36-37 pt**: ocho por debajo
            // del mínimo, y son las trece con las que se navega la app entera.
            // Medido con el tamaño de letra de fábrica; en AX1 ya lo pasaban
            // solas, así que el problema solo existía abajo de la escala.
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous)
                    .fill(seleccionado ? Paleta.brandFill : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // La sección abierta se distingue por el verde y por el fondo
        // tintado, y ninguna de las dos cosas llega a VoiceOver: sin esto,
        // las trece filas de la sidebar se leen iguales y no hay forma de
        // saber en cuál estás. Medido: `isSelected` daba `false` también en
        // la que estaba abierta.
        .accessibilityAddTraits(seleccionado ? .isSelected : [])
    }
}

private struct SidebarSectionTitle: View {
    let texto: String
    var body: some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, Esp.pantalla)
            .padding(.top, 14)
            .padding(.bottom, 2)
    }
}

/// La barra lateral de navegación del iPad, fiel al handoff: cabecera de la
/// iglesia, buscador, y las áreas de Tesorería y Secretaría con sus badges.
struct Sidebar: View {
    @Binding var seleccion: String
    /// El membrete sale de Ajustes, no de esta vista. El nombre iba escrito a
    /// mano aquí y en otros nueve sitios, con DOS valores distintos —"Iglesia
    /// Getsemaní" y "Iglesia Nueva Vida"—, así que los documentos y la sidebar
    /// nombraban iglesias diferentes.
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    /// El mismo ViewModel que el badge del tab del iPhone: el conteo de la
    /// bandeja se calcula UNA vez y lo leen todos.
    @State private var revisarVM = RevisarViewModel.compartido
    /// **Los otros dos badges también se CARGAN.** Iban como
    /// `MockMiembrosRepository.activosCount` y `MockAgendaRepository.pendientesCount`,
    /// leídos de la maqueta directamente y saltándose las fábricas, así que con
    /// la cuenta real la sidebar seguía anunciando los aportantes y los
    /// compromisos de la iglesia inventada. Es el mismo arreglo que ya tiene el
    /// hub del iPhone (`IPhoneSecretariaView`).
    ///
    /// `nil` mientras cargan, y entonces el badge no sale: un hueco se entiende,
    /// un número que no es de esta iglesia no.
    @State private var aportantesActivos: Int?
    @State private var agenda: ResumenAgenda?
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    private let motor = MotorSincronizacion.compartido
    private var iglesia: ConfiguracionIglesia { cfg.config }
    private var permisos: Permisos {
        Permisos(rol: sesion?.perfil.rol ?? .administrador, iglesia: iglesia)
    }

    var body: some View {
        VStack(spacing: 0) {
            cabeceraIglesia
            buscador

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Inicio va con Tesorería: enseña el saldo en caja, los
                    // ingresos y los gastos. No es una portada neutra.
                    if permisos.ve(.inicio) {
                        SidebarRow(titulo: L.t("Inicio", "Home"), icono: "house",
                                   seleccionado: seleccion == "inicio") { seleccion = "inicio" }
                    }

                    // Un título de sección sobre una lista vacía es un hueco
                    // que da a entender que algo no cargó.
                    if !tesoreria.isEmpty {
                        SidebarSectionTitle(texto: L.t("TESORERÍA", "TREASURY"))
                        grupo(tesoreria)
                    }

                    if !secretaria.isEmpty {
                        SidebarSectionTitle(texto: L.t("SECRETARÍA", "SECRETARY"))
                        grupo(secretaria)
                    }
                }
                .padding(.horizontal, Esp.hueco)
            }

            Divider()
            piePagina
        }
        .background(.clear)
        .task { await cfg.cargar() }
        .task { await revisarVM.cargar() }
        .task {
            aportantesActivos = (try? await repositorioMiembros().lista(filtro: .activos))?.count
            agenda = await repositorioAgenda().resumen()
        }
    }

    private func grupo(_ items: [(String, String, String, Int?, Bool)]) -> some View {
        ForEach(items, id: \.0) { item in
            SidebarRow(titulo: item.1, icono: item.2, badge: item.3, badgeRojo: item.4,
                       seleccionado: seleccion == item.0) { seleccion = item.0 }
        }
    }

    // Los badges salen de los mismos repositorios que alimentan cada
    // pantalla. Antes eran tres números escritos a mano —248, 10 y 4—
    // que no coincidían con lo que la pantalla acababa mostrando.
    // id, título, icono, badge, badgeRojo
    /// **Tesorería según el rol.** A la secretaria le queda solo Reportes: es
    /// lo que necesita para las actas y para la junta, sin poder tocar un
    /// movimiento. El grupo se queda con su título porque Reportes ES de
    /// Tesorería; esconderlo bajo "Secretaría" la haría dudar de qué cifras
    /// está mirando.
    private var tesoreria: [(String, String, String, Int?, Bool)] {
        guard permisos.ve(.tesoreria) else {
            let soloReportes: [(String, String, String, Int?, Bool)] =
                [("reportes", L.t("Reportes", "Reports"), "chart.bar", nil, false)]
            return permisos.ve(.reportes) ? soloReportes : []
        }
        return [
            ("ingresos", L.t("Ingresos", "Income"), "arrow.down", nil, false),
            ("gastos", L.t("Gastos", "Expenses"), "arrow.up", nil, false),
            ("miembros", L.t("Aportantes", "Contributors"), "person.2",
             aportantesActivos, false),
            ("reportes", L.t("Reportes", "Reports"), "chart.bar", nil, false),
            ("depositos", L.t("Depósitos", "Deposits"), "building.columns", nil, false),
            ("porRevisar", L.t("Por revisar", "To review"), "tray",
             revisarVM.porRevisarCount, true),
        ]
    }

    private var secretaria: [(String, String, String, Int?, Bool)] {
        // Membresía solo si esta persona ve el padrón: al tesorero se le abre
        // desde Ajustes → Acceso y áreas, y es la ÚNICA parte de Secretaría a
        // la que puede llegar. El resto del área no es suya.
        let padron: [(String, String, String, Int?, Bool)] = permisos.vePadron
            ? [("membresia", L.t("Membresía", "Membership"), "person.text.rectangle", nil, false)]
            : []
        guard permisos.ve(.secretaria) else { return padron }
        return padron + [
            ("actas", L.t("Actas", "Minutes"), "doc.text", nil, false),
            ("servicios", L.t("Registro de servicios", "Service log"), "book", nil, false),
            ("cartas", L.t("Cartas y traslados", "Letters & transfers"), "envelope", nil, false),
            ("informes", L.t("Informes de membresía", "Membership reports"), "doc.plaintext", nil, false),
            ("agenda", L.t("Agenda", "Calendar"), "calendar",
             agenda?.pendientes, false),
        ]
    }

    /// **El galón prometía una pantalla y no llevaba a ninguna.** Esta cabecera
    /// dibujaba un `chevron.right` a la derecha —el signo con el que toda la
    /// app anuncia "aquí se entra"— dentro de un `HStack` sin `Button` ni
    /// `onTapGesture`: el único elemento de la sidebar que se ofrece y no
    /// responde. Es el mismo criterio que ya dejó escrito `RevisarView`, que
    /// una cápsula que parece botón y no responde promete algo que no cumple.
    ///
    /// Se le pone destino en vez de quitarle el galón porque el galón no
    /// estaba ahí por error: el nombre de la iglesia es lo que se va a tocar
    /// para cambiarlo, y eso vive en Ajustes.
    ///
    /// **Entra por la sección que abra Ajustes por omisión, que hoy es
    /// "Cuenta" y no "Iglesia".** Aterrizar directamente en la iglesia pide
    /// una pseudo-sección en `RootView.pantallaDeSeccion` o un estado estático
    /// de una sola vez, y las dos cosas tienen más efectos de lado que el
    /// punto que ganan. Queda como decisión aparte.
    private var cabeceraIglesia: some View {
        Button { seleccion = "config" } label: {
            HStack(spacing: 10) {
                Text(iglesia.iniciales)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Paleta.brand, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(iglesia.nombre).font(.subheadline.weight(.semibold)).lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(iglesia.ubicacionLegible).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Esp.pantalla)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.t("\(iglesia.nombre), ir a Configuración",
                                "\(iglesia.nombre), go to Settings"))
    }

    /// **El rótulo "⌘K" se quitó el 10-sep-2026: prometía un atajo que no
    /// existe.** En toda la app había CERO `keyboardShortcut`, así que en un
    /// iPad con teclado el rótulo se desmentía al primer intento. Se quita en
    /// vez de conectarlo porque no hay nada a lo que conectarlo: este buscador
    /// es un `HStack`, no un `Button`, y no abre nada.
    ///
    /// **Queda abierto, y es decisión de Iván:** una barra de búsqueda que no
    /// busca sigue siendo una promesa. O se le pone detrás una búsqueda de
    /// verdad —y entonces el atajo vuelve, ya con algo que hacer— o se quita
    /// la barra entera.
    private var buscador: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.subheadline).foregroundStyle(.secondary)
            Text(L.t("Buscar en Tamio", "Search Tamio")).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, Esp.chip)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, Esp.pantalla)
        .padding(.bottom, 8)
    }

    private var piePagina: some View {
        VStack(alignment: .leading, spacing: 2) {
            SidebarRow(titulo: L.t("Registro", "Log"), icono: "list.bullet.rectangle",
                       seleccionado: seleccion == "registro") { seleccion = "registro" }
            SidebarRow(titulo: L.t("Configuración", "Settings"), icono: "gearshape",
                       seleccionado: seleccion == "config") { seleccion = "config" }

            // Quien ha entrado, del perfil de la sesión, y el estado real de
            // la sincronización. Decía "Iván García · Administrador · al día
            // 9:38" con las 9:38 escritas a mano, y el punto verde no se
            // apagaba aunque la sincronización estuviera fallando.
            let p = sesion?.perfil ?? SesionSupabase.Perfil()
            HStack(spacing: 10) {
                Text(p.iniciales)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.tertiarySystemFill), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.nombre.isEmpty ? L.t("Tu cuenta", "Your account") : p.nombre)
                        .font(.subheadline.weight(.medium)).lineLimit(1)
                    Text("\(AjustesRol.legible(p.rol)) · \(motor.estadoLegible)")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Circle().fill(motor.haFallado ? Paleta.negativo : Paleta.brand)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, Esp.pantalla)
            .padding(.top, 6)
        }
        .padding(.horizontal, Esp.hueco)
        .padding(.vertical, 8)
    }
}
