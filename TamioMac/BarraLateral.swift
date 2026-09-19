import SwiftUI

/// **La barra lateral de la maqueta.**
///
/// Tres piezas de arriba abajo: la iglesia —que además es el botón de ir a
/// Configuración—, la navegación por grupos, y quién ha entrado.
struct BarraLateral: View {
    @Binding var seleccion: SeccionMac
    @State private var iglesia = ConfiguracionIglesiaViewModel.compartido
    @State private var revisar = RevisarViewModel.compartido
    /// Qué grupos están plegados. Vacío al arrancar: todo abierto.
    @State private var plegados: Set<SeccionMac.Grupo.ID> = []
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?

    var body: some View {
        VStack(spacing: 0) {
            cabeceraIglesia
            lista
            Divider()
            pie
        }
        .task { await revisar.cargar() }
    }

    // MARK: - La iglesia

    private var cabeceraIglesia: some View {
        Button { seleccion = .config } label: {
            HStack(spacing: 10) {
                Text(iglesia.config.iniciales)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Paleta.sobreRelleno)
                    .frame(width: 34, height: 34)
                    .background(Paleta.brand, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(nombreIglesia)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    // El lugar, solo si está puesto. **Una línea que dice "·"
                    // y nada más es peor que no tener línea**: parece que algo
                    // no cargó.
                    if !lugar.isEmpty {
                        Text(lugar)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.t("\(nombreIglesia), ir a Configuración",
                                "\(nombreIglesia), go to Settings"))
    }

    private var nombreIglesia: String {
        let n = iglesia.config.nombre.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? L.t("Tu iglesia", "Your church") : n
    }

    /// "Austin, TX" con lo que haya. Si no hay ciudad ni estado, cadena vacía.
    private var lugar: String {
        [iglesia.config.ciudad, iglesia.config.estado]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    // MARK: - La navegación

    private var lista: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(SeccionMac.Grupo.allCases) { grupo in
                    let secciones = SeccionMac.del(grupo)
                    if !secciones.isEmpty {
                        if let titulo = grupo.titulo {
                            cabeceraGrupo(titulo, grupo: grupo)
                        }
                        if !plegados.contains(grupo.id) {
                            ForEach(secciones) { fila($0) }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    private func cabeceraGrupo(_ titulo: String, grupo: SeccionMac.Grupo) -> some View {
        let plegado = plegados.contains(grupo.id)
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                if plegado { plegados.remove(grupo.id) } else { plegados.insert(grupo.id) }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .heavy))
                    .rotationEffect(.degrees(plegado ? -90 : 0))
                Text(titulo)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.6)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func fila(_ s: SeccionMac) -> some View {
        let activa = seleccion == s
        return Button { seleccion = s } label: {
            HStack(spacing: 10) {
                Image(systemName: s.icono)
                    .font(.system(size: 13))
                    .frame(width: 15)
                Text(s.titulo)
                    .font(.system(size: 13, weight: activa ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if s == .porRevisar, revisar.porRevisarCount > 0 {
                    Text("\(revisar.porRevisarCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Paleta.sobreRelleno)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Paleta.negativo, in: Capsule())
                }
                Text(s.atajoEscrito)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(activa ? Paleta.brand : Color.primary)
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(activa ? Paleta.brandFill : .clear,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // **El atajo cuelga de la fila y no de un menú "Ir".**
        //
        // La maqueta enseña ⌘1…⌘9 escrito al lado de cada rótulo, que es donde
        // alguien los va a buscar. Colgarlo del botón hace las dos cosas a la
        // vez: registra el atajo mientras la ventana está al frente y lo
        // documenta donde se ve.
        .modifier(AtajoSeccion(tecla: s.atajo))
    }

    // MARK: - Quién ha entrado

    private var pie: some View {
        HStack(spacing: 9) {
            Text(sesion?.perfil.iniciales ?? "—")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.quaternary, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(sesion?.perfil.firma ?? L.t("Sin sesión", "Signed out"))
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Text(rolEscrito)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Circle()
                .fill(sesion == nil ? Color.secondary : Paleta.brand)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var rolEscrito: String {
        guard let rol = sesion?.perfil.rol else {
            return L.t("Nadie ha entrado todavía", "Nobody signed in yet")
        }
        switch rol {
        case .administrador: return L.t("Administrador", "Administrator")
        case .tesorero:      return L.t("Tesorero", "Treasurer")
        case .secretaria:    return L.t("Secretaría", "Secretary")
        }
    }
}

/// `keyboardShortcut` no acepta `nil`, y "sin atajo" es justo lo que les pasa
/// a Agenda y Configuración. Un modificador resuelve lo que un `if` dentro del
/// `body` no puede sin cambiar el tipo de la vista.
private struct AtajoSeccion: ViewModifier {
    let tecla: Character?

    func body(content: Content) -> some View {
        if let tecla {
            content.keyboardShortcut(KeyEquivalent(tecla), modifiers: .command)
        } else {
            content
        }
    }
}
