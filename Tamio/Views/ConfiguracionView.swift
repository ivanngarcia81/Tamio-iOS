import SwiftUI

// MARK: - Secciones

private enum SeccionConfig: String, CaseIterable, Identifiable {
    case cuenta, iglesia, institucion, tesorero, acceso, categorias, preferencias, zona
    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .cuenta:       return L.t("Cuenta", "Account")
        case .iglesia:      return L.t("Iglesia", "Church")
        case .institucion:  return L.t("Institución", "Institution")
        case .tesorero:     return L.t("Tesorero y pastor", "Treasurer & pastor")
        case .acceso:       return L.t("Acceso y áreas", "Access & areas")
        case .categorias:   return L.t("Categorías", "Categories")
        case .preferencias: return L.t("Preferencias", "Preferences")
        case .zona:         return L.t("Zona sensible", "Danger zone")
        }
    }

    var icono: String {
        switch self {
        case .cuenta:       return "person"
        case .iglesia:      return "house"
        case .institucion:  return "doc.text"
        case .tesorero:     return "waveform.path.ecg"
        case .acceso:       return "key"
        case .categorias:   return "tag"
        case .preferencias: return "textformat.size"
        case .zona:         return "exclamationmark.triangle"
        }
    }

    var tileColor: Color {
        switch self {
        case .cuenta:       return Color(hex: 0x8E8E93)
        case .iglesia:      return Color(hex: 0x34C759)
        case .institucion:  return Color(hex: 0x5E5CE6)
        case .tesorero:     return Color(hex: 0x2AB2C9)
        case .acceso:       return Color(hex: 0x0A84FF)
        case .categorias:   return Color(hex: 0xFF9500)
        case .preferencias: return Color(hex: 0x8E8E93)
        case .zona:         return Color(hex: 0xFF3B30)
        }
    }

    var heroDesc: String {
        switch self {
        case .cuenta:
            return L.t("Tu sesión, la versión de Tamio y el estado de sincronización de este aparato.",
                        "Your session, Tamio version, and sync status of this device.")
        case .iglesia:
            return L.t("Nombre, ubicación, logo y datos fiscales de la iglesia. Se usan en cartas, reportes y PDFs.",
                        "Church name, location, logo, and tax data used in letters, reports, and PDFs.")
        case .institucion:
            return L.t("El membrete institucional: dirección, contacto y firmas que encabezan los documentos impresos.",
                        "Institutional letterhead: address, contact, and signatures at the top of printed documents.")
        case .tesorero:
            return L.t("Datos y firmas del tesorero y del pastor, que aparecen al pie de los reportes y las cartas.",
                        "Treasurer and pastor data and signatures, shown at the bottom of reports and letters.")
        case .acceso:
            return L.t("Quién entra a Tesorería y quién a Secretaría, invitaciones, permisos del rol, sincronización y plan.",
                        "Who accesses Treasury and Secretary areas, invitations, role permissions, sync, and plan.")
        case .categorias:
            return L.t("Las categorías de ingresos y gastos que aparecen en formularios, filtros, reportes y PDFs.",
                        "Income and expense categories shown in forms, filters, reports, and PDFs.")
        case .preferencias:
            return L.t("Apariencia, color de acento, idioma, tamaño de texto y sonidos de la aplicación.",
                        "Appearance, accent color, language, text size, and app sounds.")
        case .zona:
            return L.t("Respaldos, restauración, mantenimiento y borrado de datos. Los cambios aquí no se pueden deshacer.",
                        "Backups, restore, maintenance, and data deletion. Changes here cannot be undone.")
        }
    }
}

// MARK: - Helpers de layout

private struct GrupoConf<C: View>: View {
    var titulo: String = ""
    var nota: String? = nil
    @ViewBuilder let contenido: C

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !titulo.isEmpty {
                Text(titulo)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
            }
            VStack(spacing: 0) {
                contenido
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            if let nota {
                Text(nota)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
    }
}

private struct HeroCard: View {
    let seccion: SeccionConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(seccion.tileColor)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: seccion.icono)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 8) {
                Text(seccion.titulo)
                    .font(.system(size: 26, weight: .bold))
                Text(seccion.heroDesc)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}

// Fila label / valor estática
private struct FilaConf: View {
    let label: String
    var valor: String? = nil
    var valorColor: Color = .secondary
    var chevron: Bool = false
    var accion: (() -> Void)? = nil

    var body: some View {
        Group {
            if let accion {
                Button(action: accion) { fila }
                    .buttonStyle(.plain)
            } else {
                fila
            }
        }
    }

    private var fila: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15.5))
                .foregroundStyle(Color(.label))
            Spacer()
            if let v = valor {
                Text(v).font(.system(size: 15.5)).foregroundStyle(valorColor)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 50)
        .padding(.horizontal, 18)
        .contentShape(Rectangle())
    }
}

// Fila de texto editable
private struct FilaEditable: View {
    let label: String
    @Binding var texto: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15.5))
                .foregroundStyle(.secondary)
                .layoutPriority(1)
            TextField("", text: $texto)
                .font(.system(size: 15.5))
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 50)
        .padding(.horizontal, 18)
    }
}

// MARK: - Raíz

struct ConfiguracionView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var seccion: SeccionConfig = .cuenta

    var body: some View {
        Group {
            if hSizeClass == .regular {
                HStack(spacing: 0) {
                    settingsSidebar
                        .frame(width: 296)
                        .background(Color(.systemBackground))
                    Divider()
                    detalleContenido
                }
            } else {
                listaCompacta
                    .encabezadoNav(L.t("Configuración", "Settings"),
                                   L.t("Iglesia, accesos y respaldos", "Church, access & backups"))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Sidebar de ajustes

    private var settingsSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L.t("Configuración", "Settings"))
                    .font(.system(size: 27, weight: .bold))
                    .tracking(-0.6)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Cuenta
                    Button { seccion = .cuenta } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(hex: 0x8E8E93))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "person")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white)
                                )
                            Text(L.t("Cuenta", "Account"))
                                .font(.system(size: 16))
                                .foregroundStyle(seccion == .cuenta ? Paleta.brand : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(seccion == .cuenta ? Paleta.brand.opacity(0.12) : Color(.systemFill))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 20)

                    grupoSidebar(titulo: L.t("IGLESIA", "CHURCH"),
                                 items: [.iglesia, .institucion, .tesorero, .acceso])
                        .padding(.bottom, 20)

                    grupoSidebar(titulo: L.t("GENERAL", "GENERAL"),
                                 items: [.categorias, .preferencias])
                }
                .padding(.bottom, 12)
            }

            Divider()

            // Zona sensible
            Button { seccion = .zona } label: {
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: 0xFF3B30))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                        )
                    Text(L.t("Zona sensible", "Danger zone"))
                        .font(.system(size: 15.5, weight: seccion == .zona ? .semibold : .medium))
                        .foregroundStyle(seccion == .zona ? Color(hex: 0xFF3B30) : .primary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(seccion == .zona ? Color(hex: 0xFF3B30).opacity(0.10) : .clear)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func grupoSidebar(titulo: String, items: [SeccionConfig]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo)
                .font(.system(size: 11.5, weight: .bold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 22)
                .padding(.bottom, 1)
            ForEach(items) { s in
                Button { seccion = s } label: {
                    HStack(spacing: 11) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(s.tileColor)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: s.icono)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)
                            )
                        Text(s.titulo)
                            .font(.system(size: 15.5, weight: seccion == s ? .semibold : .medium))
                            .foregroundStyle(seccion == s ? Paleta.brand : .primary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(seccion == s ? Paleta.brand.opacity(0.12) : .clear)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
            }
        }
    }

    // MARK: Detalle

    @ViewBuilder
    private var detalleContenido: some View {
        switch seccion {
        case .cuenta:       SeccionCuenta()
        case .iglesia:      SeccionIglesia()
        case .institucion:  SeccionInstitucion()
        case .tesorero:     SeccionTesorero()
        case .acceso:       SeccionAcceso()
        case .categorias:   SeccionCategorias()
        case .preferencias: SeccionPreferencias()
        case .zona:         SeccionZona()
        }
    }

    // Lista compacta iPhone (diseño propio pendiente)
    private var listaCompacta: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(SeccionConfig.allCases) { s in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(s.tileColor)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: s.icono)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            )
                        Text(s.titulo).font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Cuenta

private struct SeccionCuenta: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .cuenta)

                // Perfil
                GrupoConf {
                    Button { } label: {
                        HStack(spacing: 16) {
                            Text("IG")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Paleta.brand)
                                .frame(width: 66, height: 66)
                                .background(Paleta.brand.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Ivan Garcia")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text("ig07644@gmail.com")
                                    .font(.system(size: 14.5))
                                    .foregroundStyle(.secondary)
                                Text(L.t("Administrador · Tesorería y Secretaría",
                                         "Administrator · Treasury & Secretary"))
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(18)
                    }
                    .buttonStyle(.plain)
                }

                // Sync
                GrupoConf {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 17))
                            .foregroundStyle(Paleta.brand)
                        Text(L.t("Sincronizado", "Synced"))
                            .font(.system(size: 14.5))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 50)
                    .padding(.horizontal, 18)
                }

                // Aplicación
                GrupoConf(titulo: L.t("APLICACIÓN", "APPLICATION")) {
                    FilaConf(label: L.t("Versión", "Version"), valor: "1.3.5")
                    Divider()
                    FilaConf(label: L.t("Ayuda", "Help"), chevron: true, accion: {})
                    Divider()
                    FilaConf(label: L.t("Acerca de", "About"), chevron: true, accion: {})
                }

                // Cerrar sesión
                VStack(alignment: .leading, spacing: 8) {
                    Button { } label: {
                        Text(L.t("Cerrar sesión", "Sign out"))
                            .font(.system(size: 16.5))
                            .foregroundStyle(Paleta.negativo)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 54)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    Text(L.t("Cerrar sesión no borra nada del aparato: al volver a entrar, todo sigue donde estaba.",
                             "Signing out doesn't delete anything from the device."))
                        .font(.system(size: 12.5))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Iglesia

private struct SeccionIglesia: View {
    @State private var nombre = "Iglesia Getsemaní"
    @State private var ciudad = "Monterrey"
    @State private var estado = "Nuevo León"
    @State private var pais = "México"
    @State private var cp = "64500"
    @State private var einFiscal = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .iglesia)

                // Logo
                GrupoConf {
                    Button { } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L.t("Logo", "Logo"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(L.t("Sale en cartas y reportes", "Used in letters and reports"))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(L.t("Añadir", "Add"))
                                .font(.system(size: 15.5, weight: .medium))
                                .foregroundStyle(Paleta.brand)
                            Text("IG")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .background(Paleta.brand,
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Image(systemName: "chevron.right")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 64)
                        .padding(.horizontal, 18)
                    }
                    .buttonStyle(.plain)
                }

                // Información
                GrupoConf(titulo: L.t("INFORMACIÓN DE LA IGLESIA", "CHURCH INFORMATION")) {
                    FilaEditable(label: L.t("Nombre de la iglesia", "Church name"), texto: $nombre)
                    Divider()
                    FilaEditable(label: L.t("Ciudad (opcional)", "City (optional)"), texto: $ciudad)
                    Divider()
                    FilaEditable(label: L.t("Estado/Provincia (opcional)", "State/Province (optional)"), texto: $estado)
                    Divider()
                    FilaEditable(label: L.t("País (opcional)", "Country (optional)"), texto: $pais)
                    Divider()
                    FilaEditable(label: L.t("Código postal (opcional)", "ZIP (optional)"), texto: $cp)
                }

                // Fiscal
                GrupoConf(titulo: L.t("FISCAL Y CONTABLE", "FISCAL & ACCOUNTING")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L.t("EIN / identificación fiscal", "EIN / Tax ID"))
                            .font(.system(size: 13.5))
                            .foregroundStyle(.secondary)
                        TextField(L.t("p. ej. 12-3456789", "e.g. 12-3456789"), text: $einFiscal)
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    Divider()
                    FilaConf(label: L.t("Moneda", "Currency"),
                             valor: L.t("MXN — Peso mexicano", "MXN — Mexican peso"),
                             chevron: true, accion: {})
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Institución

private let membreteItems: [(String, String)] = [
    (L.t("Dirección de la iglesia", "Church address"),
     L.t("p. ej. Av. Constitución 1420, Col. Centro", "e.g. 1420 Constitution Ave.")),
    (L.t("Estado / provincia", "State / province"),
     L.t("p. ej. Nuevo León", "e.g. New Jersey")),
    (L.t("Teléfono", "Phone"),
     L.t("p. ej. 81 8340 1122", "e.g. 555-123-4567")),
    (L.t("Correo institucional", "Institutional email"),
     "p. ej. contacto@iglesia.org"),
    (L.t("Pie institucional (opcional)", "Footer (optional)"),
     L.t("p. ej. lema o registro legal", "e.g. motto or legal registration")),
    (L.t("Nombre de la secretaria", "Secretary name"),
     L.t("p. ej. Lucía Márquez Peña", "e.g. Jane Smith")),
    (L.t("Cargo", "Title"),
     L.t("p. ej. Secretaria", "e.g. Secretary")),
]

private struct SeccionInstitucion: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .institucion)

                // Preview membrete
                GrupoConf {
                    VStack(spacing: 14) {
                        Text(L.t("Iglesia Getsemaní", "Getsemani Church"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Paleta.brand)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Divider()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                Text(L.t("Así se ve el membrete de los PDF con lo que hay escrito abajo.",
                         "This is how the PDF letterhead looks with what's written below."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.top, -16)

                // Datos
                GrupoConf(titulo: L.t("DATOS DEL MEMBRETE", "LETTERHEAD DATA"),
                          nota: L.t("Lo que quede vacío no se imprime: el membrete se cierra sin dejar renglones en blanco.",
                                    "Empty fields won't print — the letterhead closes without blank lines.")) {
                    ForEach(Array(membreteItems.enumerated()), id: \.offset) { idx, item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.0)
                                .font(.system(size: 13.5))
                                .foregroundStyle(.secondary)
                            Text(item.1)
                                .font(.system(size: 16))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        if idx < membreteItems.count - 1 { Divider() }
                    }
                }

                // Vista previa PDF
                GrupoConf {
                    HStack(spacing: 13) {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(.black)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("Vista previa del PDF", "PDF preview"))
                                .font(.system(size: 16.5, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(L.t("Así se verá el encabezado de tus reportes",
                                     "This is how your report headers will look"))
                                .font(.system(size: 13.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .frame(minHeight: 64)
                    .padding(.horizontal, 20)
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Tesorero

private struct SeccionTesorero: View {
    private struct Persona {
        let titulo: String; let ejemplo: String; let cargo: String; let firma: String
    }
    private let personas = [
        Persona(titulo: L.t("INFORMACIÓN DEL TESORERO", "TREASURER INFORMATION"),
                ejemplo: L.t("p. ej. Juan Pérez", "e.g. Juan Pérez"),
                cargo: L.t("Tesorero", "Treasurer"),
                firma: L.t("Firma del tesorero", "Treasurer signature")),
        Persona(titulo: L.t("INFORMACIÓN DEL PASTOR", "PASTOR INFORMATION"),
                ejemplo: L.t("p. ej. Carlos Ramírez", "e.g. Carlos Ramírez"),
                cargo: L.t("Pastor", "Pastor"),
                firma: L.t("Firma del pastor", "Pastor signature")),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .tesorero)

                ForEach(Array(personas.enumerated()), id: \.offset) { _, p in
                    GrupoConf(titulo: p.titulo,
                              nota: L.t("Solo se aceptan imágenes PNG, idealmente con fondo transparente.",
                                        "Only PNG images accepted, ideally with transparent background.")) {
                        FilaConf(label: L.t("Nombre completo", "Full name"), valor: p.ejemplo, valorColor: Color(.tertiaryLabel))
                        Divider()
                        FilaConf(label: L.t("Cargo", "Title"), valor: p.cargo)
                        Divider()
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L.t("Correo electrónico (opcional)", "Email (optional)"))
                                .font(.system(size: 13.5)).foregroundStyle(.secondary)
                            Text("correo@ejemplo.com")
                                .font(.system(size: 16)).foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18).padding(.vertical, 11)
                        Divider()
                        FilaConf(label: L.t("Teléfono (opcional)", "Phone (optional)"),
                                 valor: L.t("Número de teléfono", "Phone number"),
                                 valorColor: Color(.tertiaryLabel))
                        Divider()
                        // Firma
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.firma).font(.system(size: 15.5))
                                Text(L.t("Sin cargar", "Not uploaded"))
                                    .font(.system(size: 13)).foregroundStyle(Paleta.aviso)
                            }
                            Spacer()
                            Button { } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.system(size: 14))
                                    Text(L.t("Añadir", "Add"))
                                        .font(.system(size: 15))
                                }
                                .foregroundStyle(Paleta.aviso)
                                .padding(.horizontal, 20).padding(.vertical, 10)
                                .background(Paleta.aviso.opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Paleta.aviso.opacity(0.45),
                                                style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                                )
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 64)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Acceso

private struct SeccionAcceso: View {
    @State private var estadoSync = L.t("Sincronizado", "Synced")
    @State private var subidos = 0
    @State private var bajados = 0
    @State private var padronVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .acceso)

                // Personas
                GrupoConf(titulo: L.t("PERSONAS", "PEOPLE"),
                          nota: L.t("Toca una persona para cambiar su rol. El rol decide en qué áreas entra.",
                                    "Tap a person to change their role. The role determines which areas they can access.")) {
                    Button { } label: {
                        HStack(spacing: 12) {
                            Text("+")
                                .font(.system(size: 17)).foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Paleta.brand, in: Circle())
                            Text(L.t("Añadir persona", "Add person"))
                                .font(.system(size: 16)).foregroundStyle(.primary)
                            Spacer()
                        }
                        .frame(minHeight: 54).padding(.horizontal, 18)
                    }
                    .buttonStyle(.plain)
                }

                // Invitar
                GrupoConf(titulo: L.t("INVITAR A ALGUIEN", "INVITE SOMEONE"),
                          nota: L.t("Verá Tesorería: ingresos, gastos, depósitos y reportes.",
                                    "Will see Treasury: income, expenses, deposits, and reports.")) {
                    FilaConf(label: L.t("Correo electrónico", "Email"),
                             valor: "tesorero@iglesia.org")
                    Divider()
                    FilaConf(label: L.t("Nombre", "Name"),
                             valor: L.t("Opcional", "Optional"), valorColor: Color(.tertiaryLabel))
                    Divider()
                    FilaConf(label: L.t("Rol", "Role"),
                             valor: L.t("Tesorero", "Treasurer"), chevron: true, accion: {})
                    Divider()
                    Button { } label: {
                        Text(L.t("Enviar invitación", "Send invitation"))
                            .font(.system(size: 16)).foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity).frame(minHeight: 52)
                    }
                    .buttonStyle(.plain)
                }

                // Sincronización
                GrupoConf(titulo: L.t("SINCRONIZACIÓN (BETA)", "SYNC (BETA)"),
                          nota: L.t("Se sincroniza sola: al abrir, al guardar y al reconectar. Piloto: solo la lista de miembros. Requiere sesión e internet.",
                                    "Syncs automatically: on open, save, and reconnect. Pilot: member list only. Requires login and internet.")) {
                    FilaConf(label: L.t("Estado", "Status"), valor: estadoSync)
                    Divider()
                    FilaConf(label: L.t("Último cambio", "Last change"),
                             valor: "\(subidos) \(L.t("subidos", "uploaded")) · \(bajados) \(L.t("bajados", "downloaded"))",
                             valorColor: .secondary)
                    Divider()
                    Button {
                        subidos += 3; bajados += 1
                    } label: {
                        Text(L.t("Sincronizar ahora", "Sync now"))
                            .font(.system(size: 16)).foregroundStyle(Paleta.brand)
                            .frame(maxWidth: .infinity).frame(minHeight: 52)
                    }
                    .buttonStyle(.plain)
                }

                // Plan
                GrupoConf(titulo: L.t("TU PLAN", "YOUR PLAN"),
                          nota: L.t("El plan lo administra el servidor; aquí solo se consulta. Para cambios, contacta a soporte.",
                                    "The plan is managed server-side; read-only here. For changes, contact support.")) {
                    FilaConf(label: L.t("Plan", "Plan"), valor: L.t("Completo", "Full"))
                    Divider()
                    FilaConf(label: L.t("Suscripción", "Subscription"), valor: L.t("Cortesía", "Courtesy"))
                }

                // Permisos
                GrupoConf(titulo: L.t("PERMISOS DEL ROL TESORERÍA", "TREASURY ROLE PERMISSIONS")) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.t("Ver el padrón de Secretaría", "View Secretary roster"))
                                .font(.system(size: 16))
                            Text(L.t("Le abre Membresía cuando entra con rol Tesorería.",
                                     "Opens Membership when accessing with Treasury role."))
                                .font(.system(size: 13)).foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle("", isOn: $padronVisible).labelsHidden().tint(Paleta.brand)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 14)
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Categorías

private struct SeccionCategorias: View {
    private struct Cat: Identifiable {
        let id: Int; let nombre: String; let color: Color; let movs: Int
    }
    @State private var tab = "ingresos"

    private let catIng: [Cat] = [
        Cat(id: 1, nombre: L.t("Ofrenda", "Offering"),  color: Color(hex: 0x1A7F37), movs: 4),
        Cat(id: 2, nombre: L.t("Diezmo", "Tithe"),      color: Color(hex: 0x7C3AED), movs: 9),
        Cat(id: 3, nombre: L.t("Donación", "Donation"), color: Color(hex: 0x0E6BA8), movs: 3),
        Cat(id: 4, nombre: L.t("Otros", "Other"),       color: Color(hex: 0x4B5563), movs: 0),
    ]
    private let catGas: [Cat] = [
        Cat(id: 5, nombre: L.t("Compensación", "Compensation"), color: Color(hex: 0xA3123A), movs: 0),
        Cat(id: 6, nombre: L.t("Suministros", "Supplies"),      color: Color(hex: 0x1D4ED8), movs: 0),
        Cat(id: 7, nombre: L.t("Varios", "Misc"),               color: Color(hex: 0x0E8BA8), movs: 0),
        Cat(id: 8, nombre: L.t("Limpieza", "Cleaning"),         color: Color(hex: 0x0F766E), movs: 0),
        Cat(id: 9, nombre: L.t("Utilidades", "Utilities"),      color: Color(hex: 0xA44A00), movs: 1),
        Cat(id: 10, nombre: L.t("Mantenimiento", "Maintenance"),color: Color(hex: 0x5B21EC), movs: 0),
        Cat(id: 11, nombre: L.t("Alimentos", "Food"),           color: Color(hex: 0xA03412), movs: 3),
        Cat(id: 12, nombre: L.t("Misiones", "Missions"),        color: Color(hex: 0x0369A1), movs: 0),
    ]

    private var cats: [Cat] { tab == "ingresos" ? catIng : catGas }
    private var tituloTab: String {
        tab == "ingresos" ? L.t("Ingresos", "Income") : L.t("Gastos", "Expenses")
    }
    private var labelNueva: String {
        tab == "ingresos"
            ? L.t("Nueva categoría de ingreso", "New income category")
            : L.t("Nueva categoría de egreso", "New expense category")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .categorias)

                // Segmented
                HStack(spacing: 3) {
                    ForEach(["ingresos", "gastos"], id: \.self) { t in
                        let sel = tab == t
                        Button { tab = t } label: {
                            Text(t == "ingresos" ? L.t("Ingresos", "Income") : L.t("Gastos", "Expenses"))
                                .font(.system(size: 15, weight: sel ? .semibold : .medium))
                                .foregroundStyle(sel ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(sel ? Color(.secondarySystemGroupedBackground) : .clear)
                                        .shadow(color: sel ? .black.opacity(0.12) : .clear, radius: 2, y: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Lista
                GrupoConf(titulo: tituloTab,
                          nota: L.t("Las categorías integradas no se pueden eliminar. Las personalizadas aparecen en formularios, filtros y PDFs igual que las demás.",
                                    "Built-in categories can't be deleted. Custom ones appear in forms, filters, and PDFs just like the rest.")) {
                    ForEach(Array(cats.enumerated()), id: \.element.id) { idx, c in
                        HStack(spacing: 13) {
                            Circle().fill(c.color).frame(width: 12, height: 12)
                            Text(c.nombre).font(.system(size: 16)).lineLimit(1)
                            Spacer()
                            Text(L.t("\(c.movs) movimientos", "\(c.movs) transactions"))
                                .font(.system(size: 15)).foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 50)
                        .padding(.horizontal, 18)
                        if idx < cats.count - 1 { Divider() }
                    }
                    Divider()
                    Button { } label: {
                        HStack(spacing: 12) {
                            Text("+").font(.system(size: 16)).foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Paleta.brand, in: Circle())
                            Text(labelNueva).font(.system(size: 16)).foregroundStyle(.primary)
                            Spacer()
                        }
                        .frame(minHeight: 52).padding(.horizontal, 18)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Preferencias

private struct SeccionPreferencias: View {
    @State private var temaIdx = 0
    @State private var acentoIdx = 1
    @State private var nivelTexto: Double = 2
    @State private var sonido = true

    private let temas = [L.t("Claro", "Light"), L.t("Oscuro", "Dark"), L.t("Automático", "Automatic")]
    private let acentos: [Color] = [
        Color(hex: 0x111111), Color(hex: 0x047857), Color(hex: 0x1D4ED8),
        Color(hex: 0x7C3AED), Color(hex: 0xB45309),
    ]
    private let nivelLabel = [
        L.t("Pequeño", "Small"), L.t("Mediano", "Medium"), L.t("Normal", "Normal"),
        L.t("Grande", "Large"), L.t("Muy grande", "Extra large"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .preferencias)

                // Apariencia
                GrupoConf(titulo: L.t("APARIENCIA", "APPEARANCE"),
                          nota: L.t("\"Automático\" sigue el modo del sistema. El acento tiñe botones y enlaces; el verde Tamio no cambia, es la marca.",
                                    "\"Automatic\" follows the system mode. The accent tints buttons and links; Tamio green doesn't change, it's the brand.")) {
                    ForEach(Array(temas.enumerated()), id: \.offset) { idx, label in
                        Button { temaIdx = idx } label: {
                            HStack {
                                Text(label).font(.system(size: 16)).foregroundStyle(.primary)
                                Spacer()
                                if idx == temaIdx {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Paleta.brand)
                                }
                            }
                            .frame(minHeight: 52).padding(.horizontal, 18)
                        }
                        .buttonStyle(.plain)
                        if idx < temas.count - 1 { Divider() }
                    }
                    Divider()
                    HStack(spacing: 14) {
                        Text(L.t("Color de acento", "Accent color")).font(.system(size: 16))
                        Spacer()
                        HStack(spacing: 10) {
                            ForEach(Array(acentos.enumerated()), id: \.offset) { idx, c in
                                Button { acentoIdx = idx } label: {
                                    ZStack {
                                        Circle().fill(c).frame(width: 34, height: 34)
                                        if idx == acentoIdx {
                                            Circle()
                                                .stroke(Color(.systemBackground), lineWidth: 2.5)
                                                .frame(width: 26, height: 26)
                                            Image(systemName: "checkmark")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(minHeight: 60).padding(.horizontal, 18)
                }

                // Idioma y texto
                GrupoConf(titulo: L.t("IDIOMA Y TEXTO", "LANGUAGE & TEXT"),
                          nota: L.t("\"Automático\" usa el idioma del sistema: español si está en español, inglés en cualquier otro caso.",
                                    "\"Automatic\" uses the system language: Spanish if set to Spanish, English otherwise.")) {
                    FilaConf(label: L.t("Idioma", "Language"),
                             valor: L.t("Español", "Spanish"), chevron: true, accion: {})
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L.t("Tamaño de texto", "Text size")).font(.system(size: 16))
                            Spacer()
                            Text(nivelLabel[Int(nivelTexto)])
                                .font(.system(size: 15)).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Text("A").font(.system(size: 13)).foregroundStyle(.tertiary)
                            Slider(value: $nivelTexto, in: 0...4, step: 1).tint(Paleta.brand)
                            Text("A").font(.system(size: 21)).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 12)
                }

                // Sonido
                GrupoConf(titulo: L.t("SONIDO", "SOUND")) {
                    Toggle(isOn: $sonido) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.t("Sonido", "Sound")).font(.system(size: 16))
                            Text(L.t("Se reproduce un sonido distinto al registrar un ingreso, un gasto o al eliminar un movimiento.",
                                     "A different sound plays when recording income, an expense, or deleting a transaction."))
                                .font(.system(size: 13)).foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(Paleta.brand)
                    .padding(.horizontal, 18).padding(.vertical, 14)
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Zona sensible

private struct SeccionZona: View {
    @State private var ultimoRespaldo = L.t("Ninguno", "None")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .zona)

                // Advertencia + respaldar
                GrupoConf {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t("Antes de tocar nada", "Before doing anything"))
                            .font(.system(size: 17, weight: .bold))
                        Text(L.t("Un respaldo tarda unos segundos y es lo único que puede devolver lo que se pierda. Todavía no has hecho ninguno desde este aparato.",
                                 "A backup takes a few seconds and is the only thing that can restore lost data. You haven't made one from this device yet."))
                            .font(.system(size: 14.5)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 18)
                    Divider()
                    Button { ultimoRespaldo = L.t("Hoy 9:41", "Today 9:41") } label: {
                        Text(L.t("Respaldar ahora", "Backup now"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Paleta.brand)
                            .frame(maxWidth: .infinity).frame(minHeight: 54)
                    }
                    .buttonStyle(.plain)
                }

                // Respaldos
                GrupoConf(titulo: L.t("RESPALDOS", "BACKUPS"),
                          nota: L.t("El respaldo completo se puede guardar fuera del teléfono y sirve para restaurar en otro aparato.",
                                    "The full backup can be saved outside the device and used to restore on another device.")) {
                    FilaConf(label: L.t("Último respaldo", "Last backup"), valor: ultimoRespaldo)
                    Divider()
                    FilaConf(label: L.t("Exportar a un archivo", "Export to a file"),
                             chevron: true, accion: {})
                }

                // Mantenimiento
                GrupoConf(titulo: L.t("MANTENIMIENTO", "MAINTENANCE"),
                          nota: L.t("Lo que se borra queda marcado hasta que se compacta. No toca nada de lo que se ve.",
                                    "Deleted items are marked until compacted. Nothing visible is affected.")) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L.t("Compactar base de datos", "Compact database"))
                            .font(.system(size: 16))
                        Text(L.t("La base ya está compacta", "The database is already compact"))
                            .font(.system(size: 13.5)).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18).padding(.vertical, 14)
                }

                // Restaurar
                GrupoConf {
                    Button { } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L.t("Restaurar un respaldo", "Restore a backup"))
                                    .font(.system(size: 16)).foregroundStyle(.primary)
                                Text(L.t("Reemplaza todo lo capturado después de la fecha del respaldo.",
                                         "Replaces everything captured after the backup date."))
                                    .font(.system(size: 13.5)).foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }

                // Borrar datos
                GrupoConf {
                    Button(role: .destructive) { } label: {
                        HStack {
                            Text(L.t("Borrar datos de este iPad", "Erase data from this iPad"))
                                .font(.system(size: 16)).foregroundStyle(Paleta.negativo)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 50).padding(.horizontal, 18)
                    }
                    .buttonStyle(.plain)
                    Text(L.t("Borrar los datos locales no afecta el respaldo en iCloud ni lo que vean los demás usuarios de la iglesia.",
                             "Erasing local data doesn't affect the iCloud backup or what other church users see."))
                        .font(.system(size: 12.5)).foregroundStyle(.tertiary)
                        .padding(.horizontal, 18).padding(.bottom, 14)
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
    }
}
