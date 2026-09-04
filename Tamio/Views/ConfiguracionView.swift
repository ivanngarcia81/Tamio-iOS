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
        case .zona:         return L.t("Zona de riesgo", "Danger zone")
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
        case .preferencias: return Color(hex: 0xAF52DE)
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
                    .padding(.horizontal, Esp.hueco)
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
                    .padding(.horizontal, Esp.hueco)
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
        .padding(Esp.panel)
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
        .padding(.horizontal, Esp.pantalla)
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
        .padding(.horizontal, Esp.pantalla)
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
                        .frame(width: Esp.columnaMaestra)
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
            .padding(.horizontal, Esp.pantalla)
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
                        .padding(.horizontal, Esp.fila)
                        .frame(minHeight: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(seccion == .cuenta ? Paleta.brandFill : Color(.systemFill))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Esp.pantalla)
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

            // Zona de riesgo
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
                    Text(L.t("Zona de riesgo", "Danger zone"))
                        .font(.system(size: 15.5, weight: seccion == .zona ? .semibold : .medium))
                        .foregroundStyle(seccion == .zona ? Color(hex: 0xFF3B30) : .primary)
                    Spacer()
                }
                .padding(.horizontal, Esp.chip)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(seccion == .zona ? Color(hex: 0xFF3B30).opacity(0.10) : .clear)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Esp.pantalla)
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
                .padding(.horizontal, Esp.pantalla)
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
                    .padding(.horizontal, Esp.chip)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(seccion == s ? Paleta.brandFill : .clear)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Esp.pantalla)
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
                    .padding(.horizontal, Esp.fila)
                    .frame(minHeight: 44)
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Cuenta

private struct SeccionCuenta: View {
    /// Opcional a propósito: las previews de esta sección se montan sin la
    /// sesión en el entorno, y un `@Environment` no opcional las haría caer.
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    private let motor = MotorSincronizacion.compartido
    @State private var confirmarCierre = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .cuenta)

                // Perfil
                GrupoConf {
                    // Sin `Button`: era uno con la acción vacía y un chevron,
                    // o sea una tarjeta que prometía una pantalla de perfil
                    // que no existe.
                    let p = sesion?.perfil ?? SesionSupabase.Perfil()
                    HStack(spacing: 16) {
                        Text(p.iniciales)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Paleta.brand)
                            .frame(width: 66, height: 66)
                            .background(Paleta.brandFill, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.nombre.isEmpty ? L.t("Tu cuenta", "Your account") : p.nombre)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(p.correo)
                                .font(.system(size: 14.5))
                                .foregroundStyle(.secondary)
                            Text(AjustesRol.legible(p.rol))
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(Esp.tarjeta)
                }

                // Sync
                GrupoConf {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 17))
                            .foregroundStyle(motor.haFallado ? Paleta.negativo : Paleta.brand)
                        // Decía "Sincronizado" siempre, aunque no se hubiera
                        // sincronizado nunca. Ver `MotorSincronizacion`.
                        Text(motor.estadoLegible)
                            .font(.system(size: 14.5))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 50)
                    .padding(.horizontal, Esp.pantalla)
                }

                // Aplicación
                GrupoConf(titulo: L.t("APLICACIÓN", "APPLICATION")) {
                    FilaConf(label: L.t("Versión", "Version"), valor: VersionApp.completa)
                    Divider()
                    // Sin chevron ni acción: el chevron prometía dos
                    // pantallas que no existen y la fila se hundía al tocarla
                    // sin llevar a ningún sitio. En el teléfono ya eran texto.
                    FilaConf(label: L.t("Ayuda", "Help"),
                             valor: L.t("Próximamente", "Coming soon"),
                             valorColor: Color(.tertiaryLabel))
                    Divider()
                    FilaConf(label: L.t("Acerca de", "About"),
                             valor: L.t("Próximamente", "Coming soon"),
                             valorColor: Color(.tertiaryLabel))
                }

                // Cerrar sesión
                VStack(alignment: .leading, spacing: 8) {
                    Button { confirmarCierre = true } label: {
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
                    .disabled(sesion == nil)
                    .confirmationDialog(L.t("¿Cerrar sesión?", "Sign out?"),
                                        isPresented: $confirmarCierre,
                                        titleVisibility: .visible) {
                        Button(L.t("Cerrar sesión", "Sign out"), role: .destructive) {
                            Task { await sesion?.cerrarSesion() }
                        }
                        Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
                    }
                    Text(L.t("Cerrar sesión no borra nada del aparato: al volver a entrar, todo sigue donde estaba.",
                             "Signing out doesn't delete anything from the device."))
                        .font(.system(size: 12.5))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, Esp.hueco)
                }
            }
            .padding(Esp.panel)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
    }
}

// MARK: - Iglesia

private struct SeccionIglesia: View {
    /// Mismo origen que el iPhone y que los documentos. Antes esta pantalla
    /// tenía sus propios `@State` con "Iglesia Getsemaní" escrito dentro,
    /// mientras el teléfono decía "Iglesia Nueva Vida" y el PDF, otra cosa.
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    @State private var aperturaTexto = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .iglesia)

                // Logo
                GrupoConf {
                    // Ni botón ni "Añadir" en verde ni chevron: no hay
                    // selector de logo en ninguna parte. En el teléfono esta
                    // misma fila ya decía "Próximamente"; aquí prometía una
                    // pantalla con tres señales distintas a la vez.
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
                            Text(L.t("Próximamente", "Coming soon"))
                                .font(.system(size: 15.5))
                                .foregroundStyle(.tertiary)
                            // Las iniciales de la IGLESIA, que es de quien
                            // sería el logo. Iban escritas "IG" a mano, que
                            // resultaban ser las de la persona.
                            Text(cfg.config.iniciales)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .background(Paleta.brand,
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .frame(minHeight: 64)
                    .padding(.horizontal, Esp.pantalla)
                }

                // Información
                GrupoConf(titulo: L.t("INFORMACIÓN DE LA IGLESIA", "CHURCH INFORMATION")) {
                    FilaEditable(label: L.t("Nombre de la iglesia", "Church name"), texto: $cfg.config.nombre)
                    Divider()
                    FilaEditable(label: L.t("Ciudad (opcional)", "City (optional)"), texto: $cfg.config.ciudad)
                    Divider()
                    FilaEditable(label: L.t("Estado/Provincia (opcional)", "State/Province (optional)"), texto: $cfg.config.estado)
                    Divider()
                    FilaEditable(label: L.t("País (opcional)", "Country (optional)"), texto: $cfg.config.pais)
                    Divider()
                    FilaEditable(label: L.t("Código postal (opcional)", "ZIP (optional)"), texto: $cfg.config.codigoPostal)
                }

                // Fiscal
                GrupoConf(titulo: L.t("FISCAL Y CONTABLE", "FISCAL & ACCOUNTING")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L.t("EIN / identificación fiscal", "EIN / Tax ID"))
                            .font(.system(size: 13.5))
                            .foregroundStyle(.secondary)
                        TextField(L.t("p. ej. 12-3456789", "e.g. 12-3456789"), text: $cfg.config.idFiscal)
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, Esp.pantalla)
                    .padding(.vertical, 12)
                    Divider()
                    // Era una fila con chevron y acción VACÍA que decía
                    // "MXN — Peso mexicano" pasara lo que pasara: ni enseñaba
                    // la moneda configurada ni dejaba cambiarla.
                    HStack {
                        Text(L.t("Moneda", "Currency"))
                            .font(.system(size: 16))
                        Spacer()
                        Picker("", selection: $cfg.config.moneda) {
                            ForEach(Catalogos.monedas) { m in
                                Text(m.etiqueta).tag(m.codigo)
                            }
                        }
                        .labelsHidden()
                    }
                    .padding(.horizontal, Esp.pantalla)
                    .padding(.vertical, 12)
                    Divider()
                    // El iPad no tenía este campo: el teléfono ofrecía un saldo
                    // de apertura y aquí no existía, así que las dos pantallas
                    // de la misma configuración no coincidían.
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L.t("Saldo de apertura", "Opening balance"))
                            .font(.system(size: 13.5))
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $aperturaTexto)
                            .font(.system(size: 16))
                            .onSubmit { fijarApertura() }
                    }
                    .padding(.horizontal, Esp.pantalla)
                    .padding(.vertical, 12)
                }

                // Se dice para qué NO sirve todavía: "saldo en caja" en Tamio
                // es el efectivo sin depositar, y sumarle una apertura
                // falsearía justo la cifra que dice cuánto dinero hay delante.
                Text(L.t("El saldo de apertura es el dinero que la tesorería ya tenía antes del primer movimiento registrado. No se suma al saldo en caja, que es el efectivo todavía sin depositar.",
                         "Opening balance is money the treasury already had before the first recorded transaction. It is not added to cash on hand, which is money not yet deposited."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Esp.hueco)
            }
            .padding(Esp.panel)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
        .task { await cfg.cargar() }
        .onAppear { aperturaTexto = textoApertura }
        .onDisappear {
            fijarApertura()
            Task { await cfg.guardarYa() }
        }
    }

    private var textoApertura: String {
        cfg.config.saldoInicial == 0 ? "" : Money.fmt(cfg.config.saldoInicial)
    }

    /// Lo tecleado se convierte a centavos y se vuelve a escribir formateado,
    /// así que en pantalla queda exactamente lo que se guardó. Si no se
    /// entiende, se deja lo anterior: un cero silencioso en una cifra de dinero
    /// es peor que no aceptar el texto.
    private func fijarApertura() {
        let limpio = aperturaTexto.trimmingCharacters(in: .whitespaces)
        if limpio.isEmpty {
            cfg.config.saldoInicial = 0
        } else if let centavos = Money.desdeTexto(limpio) {
            cfg.config.saldoInicial = centavos
        }
        aperturaTexto = textoApertura
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
                        Text(ConfiguracionIglesiaViewModel.compartido.config.nombre)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Paleta.brand)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Divider()
                    }
                    .padding(.horizontal, Esp.tarjeta)
                    .padding(.vertical, 20)
                }
                Text(L.t("Así se ve el membrete de los PDF con lo que hay escrito abajo.",
                         "This is how the PDF letterhead looks with what's written below."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Esp.hueco)
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
                        .padding(.horizontal, Esp.pantalla)
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
                    .padding(.horizontal, Esp.pantalla)
                }
            }
            .padding(Esp.panel)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
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
                        .padding(.horizontal, Esp.pantalla).padding(.vertical, 11)
                        Divider()
                        FilaConf(label: L.t("Teléfono (opcional)", "Phone (optional)"),
                                 valor: L.t("Número de teléfono", "Phone number"),
                                 valorColor: Color(.tertiaryLabel))
                        Divider()
                        // Firma
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.firma).font(.system(size: 15.5))
                                // Gris y no ámbar: el ámbar avisaba de algo
                                // que hay que resolver, y no hay forma de
                                // resolverlo todavía.
                                Text(L.t("Sin cargar", "Not uploaded"))
                                    .font(.system(size: 13)).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            // Era un botón ámbar con borde punteado —el gesto
                            // visual de "falta esto, tócame"— y la acción
                            // vacía. No hay captura de firma en la app.
                            Text(L.t("Próximamente", "Coming soon"))
                                .font(.system(size: 15)).foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 64)
                        .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)
                    }
                }
            }
            .padding(Esp.panel)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
    }
}

// MARK: - Acceso

private struct SeccionAcceso: View {
    /// Singleton observable: leer sus propiedades dentro de `body` basta para
    /// que la pantalla se refresque cuando la sincronización avanza. Antes
    /// esta sección tenía tres `@State` propios —"Sincronizado" fijo y dos
    /// contadores a cero— que no miraban el motor: enseñaba un estado
    /// inventado mientras la sincronización de verdad podía estar fallando.
    private let motor = MotorSincronizacion.compartido

    /// Los permisos son de la iglesia y viven donde vive la iglesia. Aquí
    /// había UN `@State` —y solo uno de los dos permisos, además— que no salía
    /// de la pantalla: ni al servidor, ni al teléfono, ni al arranque siguiente.
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    @State private var guardandoPermiso = false
    @State private var errorPermiso: String?
    @State private var invEmail = ""
    @State private var invNom = ""
    @State private var invRol: SesionSupabase.Perfil.Rol = .tesorero
    @State private var invitando = false
    @State private var avisoInvitacion: String?

    private var permisos: Permisos {
        Permisos(rol: sesion?.perfil.rol ?? .administrador, iglesia: cfg.config)
    }

    private var puedeInvitar: Bool {
        permisos.administraPermisos && !invitando && invEmail.contains("@")
    }

    /// Qué verá quien reciba la invitación, según el rol elegido. La nota decía
    /// siempre "Verá Tesorería" aunque se invitara a Secretaría.
    private var rolExplicado: String {
        switch invRol {
        case .tesorero:
            return L.t("Verá Tesorería: ingresos, gastos, depósitos y reportes.",
                       "They'll see Treasury: income, expenses, deposits, and reports.")
        case .secretaria:
            return L.t("Verá Secretaría: padrón, actas, servicios y cartas.",
                       "They'll see Secretary: roster, minutes, services, and letters.")
        case .administrador:
            return L.t("Verá todo, y podrá invitar a otros y cambiar los permisos.",
                       "They'll see everything, and can invite others and change permissions.")
        }
    }

    private func invitar() async {
        invitando = true
        avisoInvitacion = nil
        do {
            let r = try await Invitaciones.invitar(correo: invEmail, nombre: invNom, rol: invRol)
            avisoInvitacion = r.mensaje
            invEmail = ""
            invNom = ""
        } catch {
            avisoInvitacion = error.localizedDescription
        }
        invitando = false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .acceso)

                // Personas. La lista de quién tiene acceso no se puede
                // enseñar: la política de `perfiles` deja a cada cuenta leer
                // SOLO la suya. Los tres campos de abajo eran además texto
                // fijo —"tesorero@iglesia.org" no era un marcador, era una
                // fila estática— sobre un botón con la acción vacía.
                GrupoConf(titulo: L.t("PERSONAS", "PEOPLE"),
                          nota: L.t("Por ahora solo se ve tu propia cuenta: el servidor no deja que un aparato lea los perfiles de los demás. Invitar sí funciona, aquí abajo.",
                                    "For now only your own account is visible: the server doesn't let a device read other people's profiles. Inviting does work, below.")) {
                    let p = sesion?.perfil ?? SesionSupabase.Perfil()
                    HStack(spacing: 12) {
                        Text(p.iniciales)
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Paleta.brand, in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.nombre.isEmpty ? L.t("Tu cuenta", "Your account") : p.nombre)
                                .font(.system(size: 16))
                            Text(AjustesRol.corto(p.rol))
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(L.t("Tú", "You")).font(.system(size: 14)).foregroundStyle(.tertiary)
                    }
                    .frame(minHeight: 54).padding(.horizontal, Esp.pantalla)
                }

                // Invitar
                GrupoConf(titulo: L.t("INVITAR A ALGUIEN", "INVITE SOMEONE"),
                          nota: avisoInvitacion
                            ?? (permisos.administraPermisos
                                ? rolExplicado
                                : L.t("Solo el administrador de la iglesia puede invitar.",
                                      "Only the church administrator can invite people."))) {
                    FilaEditable(label: L.t("Correo electrónico", "Email"), texto: $invEmail)
                    Divider()
                    FilaEditable(label: L.t("Nombre (opcional)", "Name (optional)"), texto: $invNom)
                    Divider()
                    HStack {
                        Text(L.t("Rol", "Role")).font(.system(size: 15.5))
                        Spacer()
                        // Los TRES roles de acceso que acepta el servidor. La
                        // fila decía "Tesorero" fijo y no dejaba cambiarlo.
                        Picker("", selection: $invRol) {
                            ForEach([SesionSupabase.Perfil.Rol.tesorero, .secretaria, .administrador],
                                    id: \.self) { Text(AjustesRol.corto($0)).tag($0) }
                        }
                        .labelsHidden()
                    }
                    .frame(minHeight: 50).padding(.horizontal, Esp.pantalla)
                    Divider()
                    Button { Task { await invitar() } } label: {
                        HStack(spacing: 8) {
                            Text(invitando
                                 ? L.t("Enviando…", "Sending…")
                                 : L.t("Enviar invitación", "Send invitation"))
                                .font(.system(size: 16))
                                .foregroundStyle(puedeInvitar ? Paleta.brand : .secondary)
                            if invitando { ProgressView() }
                        }
                        .frame(maxWidth: .infinity).frame(minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .disabled(!puedeInvitar)
                }

                // Sincronización
                GrupoConf(titulo: L.t("SINCRONIZACIÓN", "SYNC"),
                          nota: L.t("Se sincroniza sola al abrir, al guardar y al reconectar. Aquí puedes forzarla a mano.",
                                    "Syncs automatically on open, save, and reconnect. Tap to force a manual sync.")) {
                    FilaConf(label: L.t("Estado", "Status"), valor: motor.estadoLegible)
                    Divider()
                    // "Sin subir" y no "último cambio": lo que le importa a
                    // quien mira esto es si algo suyo se quedó en el aparato,
                    // no cuántas filas viajaron la última vez.
                    FilaConf(label: L.t("Sin subir", "Not uploaded"),
                             valor: motor.pendientesLegible)
                    Divider()
                    Button {
                        Task { await motor.sincronizar() }
                    } label: {
                        Text(L.t("Sincronizar ahora", "Sync now"))
                            .font(.system(size: 16))
                            .foregroundStyle(motor.puedeSincronizar ? Paleta.brand : .secondary)
                            .frame(maxWidth: .infinity).frame(minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .disabled(!motor.puedeSincronizar)
                }

                // Plan
                GrupoConf(titulo: L.t("TU PLAN", "YOUR PLAN"),
                          nota: L.t("El plan lo administra el servidor; aquí solo se consulta. Para cambios, contacta a soporte.",
                                    "The plan is managed server-side; read-only here. For changes, contact support.")) {
                    FilaConf(label: L.t("Plan", "Plan"), valor: cfg.config.planLegible)
                    Divider()
                    FilaConf(label: L.t("Suscripción", "Subscription"),
                             valor: cfg.config.suscripcionLegible)
                }

                // Permisos. Los DOS: faltaba el del borrado, que es el que
                // de verdad quita algo.
                GrupoConf(titulo: L.t("PERMISOS DEL ROL TESORERÍA", "TREASURY ROLE PERMISSIONS"),
                          nota: errorPermiso
                            ?? (permisos.administraPermisos
                                ? L.t("Son de la iglesia, no de la persona: valen para quien ocupe el puesto. Los guarda el servidor.",
                                      "These are church-level settings, not per-person. Stored on the server.")
                                : L.t("Solo el administrador de la iglesia puede cambiarlos.",
                                      "Only the church administrator can change these."))) {
                    permisoF(L.t("Ver el padrón de Secretaría", "View Secretary roster"),
                             L.t("Le abre Membresía cuando entra con rol Tesorería.",
                                 "Opens Membership when accessing with Treasury role."),
                             valor: cfg.config.tesoreroVePadron) { nuevo in
                        await cfg.fijarPermisos(vePadron: nuevo,
                                                puedeEliminar: cfg.config.tesoreroPuedeEliminar)
                    }
                    Divider()
                    permisoF(L.t("Eliminar movimientos", "Delete transactions"),
                             L.t("Apagado, el botón Eliminar desaparece de Ingresos y Gastos.",
                                 "When off, the Delete button disappears from Income and Expenses."),
                             valor: cfg.config.tesoreroPuedeEliminar) { nuevo in
                        await cfg.fijarPermisos(vePadron: cfg.config.tesoreroVePadron,
                                                puedeEliminar: nuevo)
                    }
                }
            }
            .padding(Esp.panel)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
        // El contador solo se recalculaba al terminar una sincronización, así
        // que al abrir Ajustes después de capturar sin señal decía cero.
        .task { await motor.recontarPendientes() }
        .task { await cfg.cargar() }
    }

    /// Un permiso. El interruptor enseña lo guardado y no se mueve hasta que
    /// el servidor acepta. Ver la nota del teléfono.
    private func permisoF(_ titulo: String, _ nota: String, valor: Bool,
                          cambiar: @escaping (Bool) async -> String?) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titulo).font(.system(size: 16))
                Text(nota).font(.system(size: 13)).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { valor }, set: { nuevo in
                guardandoPermiso = true
                errorPermiso = nil
                Task {
                    errorPermiso = await cambiar(nuevo)
                    guardandoPermiso = false
                }
            }))
            .labelsHidden()
            .tint(Paleta.brand)
            .disabled(guardandoPermiso || !permisos.administraPermisos)
        }
        .padding(.horizontal, Esp.pantalla).padding(.vertical, 14)
    }
}

// MARK: - Categorías

/// **Las mismas categorías que en el teléfono**, y por el mismo motivo: eran
/// dos listas literales distintas —quince filas aquí, quince allí, con nombres
/// y conteos que no coincidían entre sí ni con lo capturado— y el "+" de abajo
/// era un `Button { }` vacío.
private struct SeccionCategorias: View {
    @State private var vm = CategoriasViewModel.compartido
    @State private var tipo: TipoMovimiento = .ingreso
    @State private var creando = false
    @State private var nombreNuevo = ""

    private var filas: [CategoriasViewModel.FilaCategoria] { vm.filas(tipo) }

    private var tituloTab: String {
        tipo == .ingreso ? L.t("Ingresos", "Income") : L.t("Gastos", "Expenses")
    }
    private var labelNueva: String {
        tipo == .ingreso
            ? L.t("Nueva categoría de ingreso", "New income category")
            : L.t("Nueva categoría de egreso", "New expense category")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .categorias)

                // Segmented
                HStack(spacing: 3) {
                    ForEach([TipoMovimiento.ingreso, .gasto], id: \.self) { t in
                        let sel = tipo == t
                        Button { tipo = t } label: {
                            Text(t == .ingreso ? L.t("Ingresos", "Income") : L.t("Gastos", "Expenses"))
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
                // 3 pt y no un valor de la escala: es el filete que separa las
                // píldoras del borde del contenedor que las agrupa, como el de
                // un segmentado del sistema. No es un rol de espaciado.
                .padding(3)
                .background(Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Lista
                GrupoConf(titulo: tituloTab,
                          nota: L.t("Las categorías integradas no se pueden eliminar. Las personalizadas aparecen en formularios, filtros y PDFs igual que las demás; al borrar una, los movimientos que ya la usan la conservan.",
                                    "Built-in categories can't be deleted. Custom ones appear in forms, filters, and PDFs just like the rest; deleting one keeps it on transactions that already use it.")) {
                    ForEach(Array(filas.enumerated()), id: \.element.id) { idx, f in
                        HStack(spacing: 13) {
                            // El punto de una integrada es el mismo que se ve
                            // en Ingresos y Gastos. Ver la nota del teléfono.
                            Circle()
                                .fill(f.deFabrica
                                      ? Paleta.categoria(f.clave)
                                      : (Color(hexTexto: f.colorHex ?? "") ?? Paleta.pizarra))
                                .frame(width: 12, height: 12)
                                .opacity(f.huerfana ? 0.35 : 1)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(f.nombre).font(.system(size: 16)).lineLimit(1)
                                if f.huerfana {
                                    Text(L.t("Ya no está en el catálogo", "No longer in the catalog"))
                                        .font(.system(size: 12)).foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Text(f.movimientos == 1
                                 ? L.t("1 movimiento", "1 transaction")
                                 : L.t("\(f.movimientos) movimientos", "\(f.movimientos) transactions"))
                                .font(.system(size: 15)).foregroundStyle(.secondary)
                            if let c = f.custom {
                                Button(role: .destructive) {
                                    Task { await vm.eliminar(c) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Paleta.negativo)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(minHeight: 50)
                        .padding(.horizontal, Esp.pantalla)
                        if idx < filas.count - 1 { Divider() }
                    }
                    Divider()
                    Button { nombreNuevo = ""; creando = true } label: {
                        HStack(spacing: 12) {
                            Text("+").font(.system(size: 16)).foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Paleta.brand, in: Circle())
                            Text(labelNueva).font(.system(size: 16)).foregroundStyle(.primary)
                            Spacer()
                        }
                        .frame(minHeight: 52).padding(.horizontal, Esp.pantalla)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Esp.panel)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
        .task { await vm.cargar() }
        .alert(L.t("Nueva categoría", "New category"), isPresented: $creando) {
            TextField(L.t("Nombre", "Name"), text: $nombreNuevo)
            Button(L.t("Crear", "Create")) {
                Task { await vm.crear(nombre: nombreNuevo, tipo: tipo) }
            }
            .disabled(nombreNuevo.trimmingCharacters(in: .whitespaces).isEmpty)
            Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
        } message: {
            Text(vm.existe(nombreNuevo.trimmingCharacters(in: .whitespacesAndNewlines), tipo: tipo)
                 ? L.t("Ya hay una categoría con ese nombre.", "A category with that name already exists.")
                 : L.t("Saldrá en los formularios de alta, en los filtros y en los reportes.",
                       "It will appear in entry forms, filters, and reports."))
        }
    }
}

// MARK: - Preferencias

/// **Las mismas tres preferencias que en el teléfono**, y por el mismo motivo:
/// eran cuatro `@State` que no salían de la pantalla. Aquí además el idioma era
/// una fila con chevron y acción VACÍA que decía "Español" pasara lo que pasara.
private struct SeccionPreferencias: View {
    @State private var prefs = PreferenciasApp.compartidas

    private var tamanos: [PreferenciasApp.Tamano] { PreferenciasApp.Tamano.allCases }

    /// El deslizador trabaja con el índice del tamaño elegido. Se lee y se
    /// escribe sobre la preferencia, no sobre un `@State` paralelo: eran dos
    /// verdades para el mismo ajuste.
    private var nivel: Binding<Double> {
        Binding(
            get: { Double(tamanos.firstIndex(of: prefs.tamano) ?? 2) },
            set: { prefs.tamano = tamanos[min(max(Int($0), 0), tamanos.count - 1)] }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .preferencias)

                // Apariencia. El selector de color de acento se retira: la ley
                // de color de `Paleta` reserva el verde para lo seleccionado y
                // las cifras, así que "tiñe botones y enlaces" prometía algo que
                // el diseño de Tamio no quiere hacer.
                GrupoConf(titulo: L.t("APARIENCIA", "APPEARANCE"),
                          nota: L.t("\"Automático\" sigue el modo del sistema.",
                                    "\"Automatic\" follows the system mode.")) {
                    let temas = PreferenciasApp.Tema.allCases
                    ForEach(Array(temas.enumerated()), id: \.element) { idx, t in
                        Button { prefs.tema = t } label: {
                            HStack {
                                Text(t.etiqueta).font(.system(size: 16)).foregroundStyle(.primary)
                                Spacer()
                                if prefs.tema == t {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Paleta.brand)
                                }
                            }
                            .frame(minHeight: 52).padding(.horizontal, Esp.pantalla)
                        }
                        .buttonStyle(.plain)
                        if idx < temas.count - 1 { Divider() }
                    }
                }

                // Idioma y texto
                GrupoConf(titulo: L.t("IDIOMA Y TEXTO", "LANGUAGE & TEXT"),
                          nota: L.t("\"Automático\" usa el idioma del sistema: español si está en español, inglés en cualquier otro caso. \"Normal\" respeta el tamaño de letra de los ajustes del aparato; los demás lo sustituyen.",
                                    "\"Automatic\" uses the system language: Spanish if set to Spanish, English otherwise. \"Normal\" respects the device text size; the others override it.")) {
                    HStack {
                        Text(L.t("Idioma", "Language")).font(.system(size: 16))
                        Spacer()
                        Picker("", selection: $prefs.idioma) {
                            ForEach(PreferenciasApp.Idioma.allCases, id: \.self) {
                                Text($0.etiqueta).tag($0)
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(minHeight: 52).padding(.horizontal, Esp.pantalla)
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L.t("Tamaño de texto", "Text size")).font(.system(size: 16))
                            Spacer()
                            Text(prefs.tamano.etiqueta)
                                .font(.system(size: 15)).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Text("A").font(.system(size: 13)).foregroundStyle(.tertiary)
                            Slider(value: nivel, in: 0...Double(tamanos.count - 1), step: 1)
                                .tint(Paleta.brand)
                            Text("A").font(.system(size: 21)).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, Esp.pantalla).padding(.vertical, 12)
                    // El propio control no crece con la preferencia: si lo
                    // hiciera, elegir "Muy grande" desbordaría la fila justo en
                    // el mando que sirve para volver atrás.
                    .dynamicTypeSize(.medium)
                }
            }
            .padding(Esp.panel)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
    }
}

// MARK: - Zona de riesgo

/// **La zona de riesgo del iPad, con el respaldo funcionando.** Ver la del
/// teléfono: es el mismo trabajo y las mismas decisiones.
private struct SeccionZona: View {
    @State private var trabajando = false
    @State private var paquete: URL?
    @State private var csvMovimientos: URL?
    @State private var csvAportantes: URL?
    @State private var error: String?
    @State private var ultimo = Respaldo.ultimoLegible

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .zona)

                // Advertencia + respaldar
                GrupoConf(nota: error) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t("Antes de tocar nada", "Before doing anything"))
                            .font(.system(size: 17, weight: .bold))
                        Text(Respaldo.ultimo == nil
                             ? L.t("Un respaldo tarda unos segundos y es lo único que puede devolver lo que se pierda. Todavía no has hecho ninguno desde este aparato.",
                                   "A backup takes a few seconds and is the only thing that can restore lost data. You haven't made one from this device yet.")
                             : L.t("Un respaldo tarda unos segundos y es lo único que puede devolver lo que se pierda.",
                                   "A backup takes a few seconds and is the only thing that can restore lost data."))
                            .font(.system(size: 14.5)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Esp.pantalla).padding(.vertical, 18)
                    Divider()
                    Button { Task { await respaldar() } } label: {
                        HStack(spacing: 8) {
                            Text(trabajando
                                 ? L.t("Preparando…", "Preparing…")
                                 : L.t("Respaldar ahora", "Backup now"))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(trabajando ? .secondary : Paleta.brand)
                            if trabajando { ProgressView() }
                        }
                        .frame(maxWidth: .infinity).frame(minHeight: 54)
                    }
                    .buttonStyle(.plain)
                    .disabled(trabajando)
                }

                // Respaldos
                GrupoConf(titulo: L.t("RESPALDOS", "BACKUPS"),
                          nota: L.t("El respaldo lleva la base entera y los recibos del banco, y se guarda donde tú elijas: Archivos, iCloud o cualquier app. Los CSV son para abrirlos en una hoja de cálculo.",
                                    "The backup includes the whole database and bank receipts, and is saved wherever you choose: Files, iCloud, or any app. The CSVs are for opening in a spreadsheet.")) {
                    // "Preparado" y no "guardado": el sistema no le dice a la
                    // app si quien compartió llegó a elegir dónde ponerlo.
                    FilaConf(label: L.t("Último respaldo preparado", "Last backup prepared"),
                             valor: ultimo)
                    Divider()
                    FilaConf(label: L.t("Exportar movimientos (CSV)", "Export transactions (CSV)"),
                             valorColor: Paleta.brand, chevron: true,
                             accion: { Task { await exportar(.movimientos) } })
                    Divider()
                    FilaConf(label: L.t("Exportar aportantes (CSV)", "Export contributors (CSV)"),
                             valorColor: Paleta.brand, chevron: true,
                             accion: { Task { await exportar(.aportantes) } })
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
                    .padding(.horizontal, Esp.pantalla).padding(.vertical, 14)
                }

                // Restaurar
                GrupoConf {
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
                        Text(L.t("Próximamente", "Coming soon"))
                            .font(.system(size: 15)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, Esp.pantalla).padding(.vertical, 14)
                }

                // Borrar datos
                GrupoConf {
                    Button(role: .destructive) { } label: {
                        HStack {
                            Text(L.t("Borrar datos de este iPad", "Erase data from this iPad"))
                                .font(.system(size: 16)).foregroundStyle(Paleta.negativo)
                            Spacer()
                        }
                        .frame(minHeight: 50).padding(.horizontal, Esp.pantalla)
                    }
                    .buttonStyle(.plain)
                    .disabled(true).opacity(0.4)
                    Text(L.t("Se enciende cuando exista la restauración: hoy no habría a dónde volver. Borra solo la copia de este aparato; lo que ya se sincronizó sigue en el servidor de la iglesia.",
                             "Enabled once restore exists: today there would be nothing to go back to. It erases only this device's copy; anything already synced stays on the church server."))
                        .font(.system(size: 12.5)).foregroundStyle(.tertiary)
                        .padding(.horizontal, Esp.pantalla).padding(.bottom, 14)
                }
            }
            .padding(Esp.panel)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
        .sheet(item: $paquete) { CompartirArchivo(url: $0) }
        .sheet(item: $csvMovimientos) { CompartirArchivo(url: $0) }
        .sheet(item: $csvAportantes) { CompartirArchivo(url: $0) }
    }

    private enum Exportacion { case movimientos, aportantes }

    private func respaldar() async {
        trabajando = true
        error = nil
        do {
            let url = try await Respaldo.crear()
            Respaldo.anotarHecho()
            ultimo = Respaldo.ultimoLegible
            paquete = url
        } catch {
            self.error = error.localizedDescription
        }
        trabajando = false
    }

    private func exportar(_ que: Exportacion) async {
        trabajando = true
        error = nil
        switch que {
        case .movimientos:
            let repo = repositorioMovimientos()
            let todos = ((try? await repo.lista(tipo: .ingreso)) ?? [])
                + ((try? await repo.lista(tipo: .gasto)) ?? [])
            if todos.isEmpty {
                error = L.t("No hay movimientos que exportar.", "There are no transactions to export.")
            } else {
                csvMovimientos = ExportadorMovimientos.csv(todos)
            }
        case .aportantes:
            // `.todos`: un respaldo sin las bajas no es el padrón, es una foto
            // de los activos de hoy.
            let lista = (try? await repositorioMiembros().lista(filtro: .todos)) ?? []
            if lista.isEmpty {
                error = L.t("No hay aportantes que exportar.", "There are no contributors to export.")
            } else {
                csvAportantes = ExportadorAportantes.aportantes(lista)
            }
        }
        trabajando = false
    }
}
