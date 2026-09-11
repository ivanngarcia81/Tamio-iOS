import SwiftUI

// MARK: - Secciones

/// Las secciones viven en `SeccionAjustes`, compartidas con el teléfono. Aquí
/// había una copia con sus propios iconos y colores, y por eso ninguna fila
/// coincidía entre las dos plataformas.
private typealias SeccionConfig = SeccionAjustes

// MARK: - Helpers de layout
//
// **Los tamaños de esta pantalla escalan con Dynamic Type.** Estaban escritos
// como `Font.system(size:)`, que es un tamaño FIJO: setenta y ocho, y medido
// con la app corriendo en AX1 daban exactamente el mismo alto que en tamaño
// normal —el título "Settings", las filas, las tarjetas y hasta "Sign out"—.
// La sidebar de al lado sí crecía, así que la pantalla se leía a dos escalas.
//
// `Font.escalada` (en `AccesoView.swift`) es el mismo tamaño pasado por
// `UIFontMetrics`: a tamaño de fábrica no mueve ni un píxel, y a partir de ahí
// crece. El `relativeTo` dice con qué escala, que no es la misma para un
// rótulo de 12 pt que para un titular de 27.

private struct GrupoConf<C: View>: View {
    var titulo: String = ""
    var nota: String? = nil
    @ViewBuilder let contenido: C

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !titulo.isEmpty {
                Text(titulo)
                    .font(.escalada(12, weight: .bold, relativeTo: .caption1))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Esp.hueco)
            }
            VStack(spacing: 0) {
                contenido
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: Esp.radioTarjeta, style: .continuous))
            if let nota {
                Text(nota)
                    .font(.escalada(12.5, relativeTo: .caption1))
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
                .fill(seccion.color)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: seccion.icono)
                        .font(.escalada(26, weight: .medium, relativeTo: .title1))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 8) {
                Text(seccion.titulo)
                    .font(.escalada(26, weight: .bold, relativeTo: .title1))
                Text(seccion.descripcion)
                    .font(.escalada(15, relativeTo: .subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Esp.panel)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: Esp.radioTarjeta, style: .continuous)
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
                .font(.escalada(15.5, relativeTo: .subheadline))
                .foregroundStyle(Color(.label))
            Spacer()
            if let v = valor {
                Text(v).font(.escalada(15.5, relativeTo: .subheadline)).foregroundStyle(valorColor)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: Esp.altoFila)
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
                .font(.escalada(15.5, relativeTo: .subheadline))
                .foregroundStyle(.secondary)
                .layoutPriority(1)
            TextField("", text: $texto)
                .font(.escalada(15.5, relativeTo: .subheadline))
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: Esp.altoFila)
        .padding(.horizontal, Esp.pantalla)
    }
}

// MARK: - Raíz

struct ConfiguracionView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    @State private var seccion: SeccionConfig = .cuenta

    /// Quién ve qué sección. La misma pregunta que hace el teléfono y la misma
    /// respuesta: las ocho filas se pintaban aquí para todo el mundo.
    private var permisos: Permisos {
        Permisos(rol: sesion?.perfil.rol ?? .administrador, iglesia: cfg.config)
    }

    /// Las secciones de un grupo que este rol puede ver.
    private func visibles(_ items: [SeccionConfig]) -> [SeccionConfig] {
        items.filter { permisos.veAjuste($0) }
    }

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
                    .font(.escalada(27, weight: .bold, relativeTo: .title1))
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
                            // Del enum, como el resto: aquí iban el gris y el
                            // "person" escritos otra vez, y ni el color ni el
                            // símbolo coincidían con los de la tarjeta grande
                            // de la misma sección.
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(SeccionConfig.cuenta.color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: SeccionConfig.cuenta.icono)
                                        .font(.escalada(15, weight: .medium, relativeTo: .subheadline))
                                        .foregroundStyle(.white)
                                )
                            Text(L.t("Cuenta", "Account"))
                                .font(.escalada(16, relativeTo: .body))
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
                    .accessibilityAddTraits(seccion == .cuenta ? .isSelected : [])
                    .padding(.horizontal, Esp.pantalla)
                    .padding(.bottom, 20)

                    grupoSidebar(titulo: L.t("IGLESIA", "CHURCH"),
                                 items: [.iglesia, .institucion, .tesorero, .acceso])
                        .padding(.bottom, 20)

                    grupoSidebar(titulo: L.t("GENERAL", "GENERAL"),
                                 items: visibles([.categorias, .preferencias]))
                }
                .padding(.bottom, 12)
            }

            if permisos.veAjuste(.zona) {
                Divider()

                // Zona de riesgo
                Button { seccion = .zona } label: {
                    HStack(spacing: 11) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SeccionConfig.zona.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: SeccionConfig.zona.icono)
                                    .font(.escalada(12, weight: .medium, relativeTo: .caption1))
                                    .foregroundStyle(.white)
                            )
                        Text(L.t("Zona de riesgo", "Danger zone"))
                            .font(.escalada(15.5, weight: seccion == .zona ? .semibold : .medium, relativeTo: .subheadline))
                            .foregroundStyle(seccion == .zona ? SeccionConfig.zona.color : .primary)
                        Spacer()
                    }
                    .padding(.horizontal, Esp.chip)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(seccion == .zona ? SeccionConfig.zona.color.opacity(0.10) : .clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(seccion == .zona ? .isSelected : [])
                .padding(.horizontal, Esp.pantalla)
                .padding(.vertical, 10)
            }
        }
    }

    private func grupoSidebar(titulo: String, items: [SeccionConfig]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo)
                .font(.escalada(11.5, weight: .bold, relativeTo: .caption2))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, Esp.pantalla)
                .padding(.bottom, 1)
            ForEach(items) { s in
                Button { seccion = s } label: {
                    HStack(spacing: 11) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(s.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: s.icono)
                                    .font(.escalada(13, weight: .medium, relativeTo: .footnote))
                                    .foregroundStyle(.white)
                            )
                        Text(s.titulo)
                            .font(.escalada(15.5, weight: seccion == s ? .semibold : .medium, relativeTo: .subheadline))
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
                // Ver `Sidebar`: la sección abierta se dice, no solo se pinta.
                .accessibilityAddTraits(seccion == s ? .isSelected : [])
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
                ForEach(visibles(SeccionConfig.allCases)) { s in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(s.color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: s.icono)
                                    .font(.escalada(14, weight: .medium, relativeTo: .subheadline))
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
    @State private var bloqueo = BloqueoBiometrico.compartido
    @State private var confirmarCierre = false

    /// Se pregunta al construir y no dentro del `body`: `canEvaluatePolicy`
    /// toca el sistema de seguridad y el `body` se reevalúa muchas veces.
    private let biometria = BloqueoBiometrico.disponible()

    private var pieSeguridad: String {
        if let motivo = biometria.motivo { return motivo }
        return L.t("Si \(BloqueoBiometrico.nombreBiometria) no reconoce la cara, se puede abrir con el código del aparato: nadie se queda fuera de su propia contabilidad.",
                   "If \(BloqueoBiometrico.nombreBiometria) doesn't recognize you, the device passcode also opens it: nobody gets locked out of their own books.")
    }

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
                            .font(.escalada(22, weight: .bold, relativeTo: .title2))
                            .foregroundStyle(Paleta.brand)
                            .frame(width: 66, height: 66)
                            .background(Paleta.brandFill, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.nombre.isEmpty ? L.t("Tu cuenta", "Your account") : p.nombre)
                                .font(.escalada(20, weight: .bold, relativeTo: .title3))
                                .foregroundStyle(.primary)
                            Text(p.correo)
                                .font(.escalada(14.5, relativeTo: .subheadline))
                                .foregroundStyle(.secondary)
                            Text(AjustesRol.legible(p.rol))
                                .font(.escalada(14, relativeTo: .subheadline))
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
                            .font(.escalada(17, relativeTo: .body))
                            .foregroundStyle(motor.haFallado ? Paleta.negativo : Paleta.brand)
                        // Decía "Sincronizado" siempre, aunque no se hubiera
                        // sincronizado nunca. Ver `MotorSincronizacion`.
                        Text(motor.estadoLegible)
                            .font(.escalada(14.5, relativeTo: .subheadline))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: Esp.altoFila)
                    .padding(.horizontal, Esp.pantalla)
                }

                // Aplicación
                GrupoConf(titulo: L.t("APLICACIÓN", "APPLICATION")) {
                    // "Ayuda" y "Acerca de" estaban aquí, en "Próximamente"
                    // desde siempre. Se quitaron el 7-sep-2026: ver el
                    // comentario del teléfono, que es donde se explica.
                    FilaConf(label: L.t("Versión", "Version"), valor: VersionApp.completa)
                }

                // Seguridad. El candado de ESTE aparato, que no es lo mismo
                // que "Acceso y áreas": aquello decide quién entra al servidor
                // de la iglesia, esto quién abre esta app en este iPad.
                GrupoConf(titulo: L.t("SEGURIDAD", "SECURITY"), nota: pieSeguridad) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.t("Pedir \(BloqueoBiometrico.nombreBiometria) al abrir",
                                     "Require \(BloqueoBiometrico.nombreBiometria) to open"))
                                .font(.escalada(16, relativeTo: .body))
                            Text(L.t("También tapa las cuentas en el conmutador de apps.",
                                     "Also hides the accounts in the app switcher."))
                                .font(.escalada(13, relativeTo: .footnote)).foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle("", isOn: $bloqueo.activo)
                            .labelsHidden().tint(Paleta.brand)
                            .disabled(!biometria.puede)
                    }
                    .padding(.horizontal, Esp.pantalla).padding(.vertical, 14)
                }

                // Cerrar sesión
                VStack(alignment: .leading, spacing: 8) {
                    Button { confirmarCierre = true } label: {
                        Text(L.t("Cerrar sesión", "Sign out"))
                            .font(.escalada(16.5, relativeTo: .body))
                            .foregroundStyle(Paleta.negativo)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: Esp.altoBoton)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: Esp.radioTarjeta, style: .continuous)
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
                        .font(.escalada(12.5, relativeTo: .caption1))
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
                GrupoConf(nota: L.t("El logo se guarda para toda la iglesia: sale en los documentos que genere cualquier aparato. Las firmas, en cambio, se quedan en el aparato donde se dibujan.",
                                    "The logo is saved for the whole church: it appears on documents generated from any device. Signatures, on the other hand, stay on the device where they're drawn.")) {
                    SelectorLogo(enLista: false)
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
                            .font(.escalada(13.5, relativeTo: .footnote))
                            .foregroundStyle(.secondary)
                        TextField(L.t("p. ej. 12-3456789", "e.g. 12-3456789"), text: $cfg.config.idFiscal)
                            .font(.escalada(16, relativeTo: .body))
                    }
                    .padding(.horizontal, Esp.pantalla)
                    .padding(.vertical, 12)
                    Divider()
                    // Era una fila con chevron y acción VACÍA que decía
                    // "MXN — Peso mexicano" pasara lo que pasara: ni enseñaba
                    // la moneda configurada ni dejaba cambiarla.
                    HStack {
                        Text(L.t("Moneda", "Currency"))
                            .font(.escalada(16, relativeTo: .body))
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
                            .font(.escalada(13.5, relativeTo: .footnote))
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $aperturaTexto)
                            .font(.escalada(16, relativeTo: .body))
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
                    .font(.escalada(12.5, relativeTo: .caption1))
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
     L.t("p. ej. contacto@iglesia.org", "e.g. info@church.org")),
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
                            .font(.escalada(17, weight: .bold, relativeTo: .body))
                            .foregroundStyle(Paleta.brand)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Divider()
                    }
                    .padding(.horizontal, Esp.tarjeta)
                    .padding(.vertical, 20)
                }
                Text(L.t("Así se ve el membrete de los PDF con lo que hay escrito abajo.",
                         "This is how the PDF letterhead looks with what's written below."))
                    .font(.escalada(12.5, relativeTo: .caption1))
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
                                .font(.escalada(13.5, relativeTo: .footnote))
                                .foregroundStyle(.secondary)
                            Text(item.1)
                                .font(.escalada(16, relativeTo: .body))
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
                                    .font(.escalada(20, relativeTo: .title3))
                                    .foregroundStyle(.white)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("Vista previa del PDF", "PDF preview"))
                                .font(.escalada(16.5, weight: .bold, relativeTo: .body))
                                .foregroundStyle(.primary)
                            Text(L.t("Así se verá el encabezado de tus reportes",
                                     "This is how your report headers will look"))
                                .font(.escalada(13.5, relativeTo: .footnote))
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

/// **Tesorero y pastor, ahora editables.**
///
/// La sección entera era texto FIJO: ni el nombre ni el cargo ni el correo ni
/// el teléfono se podían tocar. Parecían campos —etiqueta arriba, valor gris
/// debajo, como los de la sección de al lado, que sí lo son— y no lo eran, así
/// que el iPad enseñaba una configuración que solo se podía cambiar desde el
/// teléfono. El correo y el teléfono además no tenían dónde guardarse: sus
/// columnas se crearon el 2026-09-04.
private struct SeccionTesorero: View {
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    @State private var firmas = FirmasLocales.compartidas
    @State private var firmando: FirmasLocales.Firmante?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroCard(seccion: .tesorero)

                persona(titulo: L.t("INFORMACIÓN DEL TESORERO", "TREASURER INFORMATION"),
                        firmante: .tesorero,
                        cargos: Catalogos.Cargos.tesoreria,
                        nombre: $cfg.config.tesoreroNombre,
                        cargo: cargoB($cfg.config.tesoreroCargo, .tesorero),
                        correo: $cfg.config.tesoreroCorreo,
                        telefono: $cfg.config.tesoreroTelefono)

                persona(titulo: L.t("INFORMACIÓN DEL PASTOR", "PASTOR INFORMATION"),
                        firmante: .pastor,
                        cargos: Catalogos.Cargos.pastoral,
                        nombre: $cfg.config.pastorNombre,
                        cargo: cargoB($cfg.config.pastorCargo, .pastor),
                        correo: $cfg.config.pastorCorreo,
                        telefono: $cfg.config.pastorTelefono)

                GrupoConf {
                    Toggle(isOn: $cfg.config.imprimirFirmas) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L.t("Imprimir firmas en los PDF", "Print signatures on PDFs"))
                                .font(.escalada(16, relativeTo: .body))
                            // Decía que apagado salen "con la línea en blanco".
                            // Es al revés: apagado, el bloque desaparece entero.
                            Text(L.t("Apagado, el bloque de firmas no se imprime: ni la línea, ni el nombre, ni el cargo.",
                                     "When off, the signature block isn't printed at all: no line, no name, no title."))
                                .font(.escalada(13, relativeTo: .footnote)).foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(Paleta.brand)
                    .padding(.horizontal, Esp.pantalla).padding(.vertical, 14)
                }
            }
            .padding(Esp.panel)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
        .task { await cfg.cargar() }
        .onDisappear { Task { await cfg.guardarYa() } }
        .sheet(item: $firmando) { HojaFirma(firmante: $0) }
    }

    /// Igual que en el teléfono: la omisión se ENSEÑA traducida y solo se
    /// escribe si alguien elige. Ver `Catalogos.Cargos.omision`.
    private func cargoB(_ b: Binding<String>, _ p: Catalogos.Cargos.Puesto) -> Binding<String> {
        Binding(get: { Catalogos.Cargos.cargo(b.wrappedValue, o: p) },
                set: { b.wrappedValue = $0 })
    }

    private func persona(titulo: String, firmante f: FirmasLocales.Firmante, cargos: [String],
                         nombre: Binding<String>, cargo: Binding<String>,
                         correo: Binding<String>, telefono: Binding<String>) -> some View {
        // La nota ya no habla de PNG con fondo transparente: prometía una
        // subida de imagen que no existe en ninguna parte de la app.
        GrupoConf(titulo: titulo,
                  nota: L.t("El correo y el teléfono son los de la persona, no los de la iglesia: esos van en Institución, que es lo que sale en el membrete.",
                            "Email and phone here belong to the person, not the church: those go in Institution, which is what prints on the letterhead.")) {
            FilaEditable(label: L.t("Nombre completo", "Full name"), texto: nombre)
            Divider()
            HStack {
                Text(L.t("Cargo", "Title")).font(.escalada(15.5, relativeTo: .subheadline)).foregroundStyle(.secondary)
                Spacer()
                // `conValorVigente`: un cargo guardado en el otro idioma no
                // está entre las opciones y el Picker saldría en blanco.
                Picker("", selection: cargo) {
                    ForEach(Catalogos.conValorVigente(cargos, cargo.wrappedValue), id: \.self) {
                        Text($0)
                    }
                }
                .labelsHidden()
            }
            .frame(minHeight: Esp.altoFila).padding(.horizontal, Esp.pantalla)
            Divider()
            FilaEditable(label: L.t("Correo (opcional)", "Email (optional)"), texto: correo)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Divider()
            FilaEditable(label: L.t("Teléfono (opcional)", "Phone (optional)"), texto: telefono)
                .textContentType(.telephoneNumber)
            Divider()
            Button { firmando = f } label: {
                HStack(spacing: 12) {
                    Text(f.titulo).font(.escalada(15.5, relativeTo: .subheadline)).foregroundStyle(.primary)
                    Spacer()
                    if let imagen = firmas.imagen(f) {
                        // La firma de verdad y no un "Guardada": lo que hay que
                        // poder comprobar de un vistazo es que es la suya y que
                        // no salió torcida, no que exista un archivo.
                        Image(uiImage: imagen)
                            .resizable().scaledToFit()
                            .frame(maxWidth: 160, maxHeight: 40)
                            .accessibilityLabel(f.titulo)
                        Button(role: .destructive) { firmas.borrar(f) } label: {
                            Image(systemName: "trash").font(.escalada(14, relativeTo: .subheadline))
                                .foregroundStyle(Paleta.negativo)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(L.t("Firmar", "Sign"))
                            .font(.escalada(15, relativeTo: .subheadline)).foregroundStyle(Paleta.brand)
                    }
                }
                .frame(minHeight: 64)
                .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
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

    /// La fila de invitar, con botón o sin él. Ver el cuerpo.
    @ViewBuilder
    private var filaInvitar: some View {
        HStack(spacing: 8) {
            Text(invitando
                 ? L.t("Enviando…", "Sending…")
                 : L.t("Enviar invitación", "Send invitation"))
                .font(.escalada(16, relativeTo: .body))
                // **Un solo `foregroundStyle` con la condición dentro.** Con
                // dos encadenados —el verde y `apagadoLegible`— gana uno u
                // otro según el orden y no se puede razonar de memoria:
                // medido en pantalla, las dos combinaciones dejaban el rótulo
                // verde. Así el color apagado es el mismo `.primary` rebajado
                // que §4 dejó medido, y además dice lo que es: gris, no una
                // acción.
                .foregroundStyle(puedeInvitar
                                 ? AnyShapeStyle(Paleta.brand)
                                 : AnyShapeStyle(.primary.opacity(0.7)))
            if invitando { ProgressView() }
        }
        .frame(maxWidth: .infinity).frame(minHeight: Esp.altoBoton)
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
                            .font(.escalada(14, weight: .bold, relativeTo: .subheadline)).foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Paleta.brand, in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.nombre.isEmpty ? L.t("Tu cuenta", "Your account") : p.nombre)
                                .font(.escalada(16, relativeTo: .body))
                            Text(AjustesRol.corto(p.rol))
                                .font(.escalada(13, relativeTo: .footnote)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(L.t("Tú", "You")).font(.escalada(14, relativeTo: .subheadline)).foregroundStyle(.tertiary)
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
                        Text(L.t("Rol", "Role")).font(.escalada(15.5, relativeTo: .subheadline))
                        Spacer()
                        // Los TRES roles de acceso que acepta el servidor. La
                        // fila decía "Tesorero" fijo y no dejaba cambiarlo.
                        Picker("", selection: $invRol) {
                            ForEach([SesionSupabase.Perfil.Rol.tesorero, .secretaria, .administrador],
                                    id: \.self) { Text(AjustesRol.corto($0)).tag($0) }
                        }
                        .labelsHidden()
                    }
                    .frame(minHeight: Esp.altoFila).padding(.horizontal, Esp.pantalla)
                    Divider()
                    // **Sin correo escrito no hay botón, hay una frase.**
                    //
                    // Iba siempre en `Button` con `.disabled`, y ese estado se
                    // medía en **1.74:1** en claro y 2.48:1 en oscuro —el
                    // mínimo de un texto normal es 4.5:1—: el rótulo se
                    // borraba. El gris estaba puesto dos veces, el de
                    // `.secondary` y el que el sistema añade al apagar.
                    //
                    // Y no se arregla con color: medido, `apagadoLegible` deja
                    // 2.14:1 y darle la vuelta al orden de los
                    // `foregroundStyle` 1.67:1, porque `.disabled` sobre un
                    // botón `.plain` atenúa por encima de lo que pinte la
                    // etiqueta. Es la misma trampa que §4 tiene medida en
                    // `.borderedProminent`.
                    //
                    // Así que se hace lo que ya decidió `RevisarView` con "0
                    // de N listos": cuando no puede hacer nada, no se dibuja
                    // como botón. Sin `disabled` que atenúe, el texto se lee, y
                    // deja de prometer lo que no cumple.
                    if puedeInvitar {
                        Button { Task { await invitar() } } label: { filaInvitar }
                            .buttonStyle(.plain)
                    } else {
                        filaInvitar
                    }
                }

                // Plan
                GrupoConf(titulo: L.t("TU PLAN", "YOUR PLAN"),
                          // Sin destino, por lo mismo que en el teléfono:
                          // 3.1.3(f) prohíbe las llamadas a comprar fuera.
                          nota: L.t("Aquí el plan solo se consulta: no se puede cambiar desde la app.",
                                    "The plan is read-only here: it can't be changed from the app.")) {
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
                Text(titulo).font(.escalada(16, relativeTo: .body))
                Text(nota).font(.escalada(13, relativeTo: .footnote)).foregroundStyle(.tertiary)
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
                                .font(.escalada(15, weight: sel ? .semibold : .medium, relativeTo: .subheadline))
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
                                      ? Paleta.categoria(f.clave, nombre: f.nombre)
                                      : (Color(hexTexto: f.colorHex ?? "") ?? Paleta.pizarra))
                                .frame(width: 12, height: 12)
                                .opacity(f.huerfana ? 0.35 : 1)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(f.nombre).font(.escalada(16, relativeTo: .body)).lineLimit(1)
                                if f.huerfana {
                                    Text(L.t("Ya no está en el catálogo", "No longer in the catalog"))
                                        .font(.escalada(12, relativeTo: .caption1)).foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Text(f.movimientos == 1
                                 ? L.t("1 movimiento", "1 transaction")
                                 : L.t("\(f.movimientos) movimientos", "\(f.movimientos) transactions"))
                                .font(.escalada(15, relativeTo: .subheadline)).foregroundStyle(.secondary)
                            if let c = f.custom {
                                Button(role: .destructive) {
                                    Task { await vm.eliminar(c) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.escalada(14, relativeTo: .subheadline))
                                        .foregroundStyle(Paleta.negativo)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(minHeight: Esp.altoFila)
                        .padding(.horizontal, Esp.pantalla)
                        if idx < filas.count - 1 { Divider() }
                    }
                    Divider()
                    Button { nombreNuevo = ""; creando = true } label: {
                        HStack(spacing: 12) {
                            Text("+").font(.escalada(16, relativeTo: .body)).foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Paleta.brand, in: Circle())
                            Text(labelNueva).font(.escalada(16, relativeTo: .body)).foregroundStyle(.primary)
                            Spacer()
                        }
                        .frame(minHeight: Esp.altoFila).padding(.horizontal, Esp.pantalla)
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
                                Text(t.etiqueta).font(.escalada(16, relativeTo: .body)).foregroundStyle(.primary)
                                Spacer()
                                if prefs.tema == t {
                                    Image(systemName: "checkmark")
                                        .font(.escalada(15, weight: .semibold, relativeTo: .subheadline))
                                        .foregroundStyle(Paleta.brand)
                                }
                            }
                            .frame(minHeight: Esp.altoFila).padding(.horizontal, Esp.pantalla)
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
                        Text(L.t("Idioma", "Language")).font(.escalada(16, relativeTo: .body))
                        Spacer()
                        Picker("", selection: $prefs.idioma) {
                            ForEach(PreferenciasApp.Idioma.allCases, id: \.self) {
                                Text($0.etiqueta).tag($0)
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(minHeight: Esp.altoFila).padding(.horizontal, Esp.pantalla)
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L.t("Tamaño de texto", "Text size")).font(.escalada(16, relativeTo: .body))
                            Spacer()
                            Text(prefs.tamano.etiqueta)
                                .font(.escalada(15, relativeTo: .subheadline)).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Text("A").font(.escalada(13, relativeTo: .footnote)).foregroundStyle(.tertiary)
                            Slider(value: nivel, in: 0...Double(tamanos.count - 1), step: 1)
                                .tint(Paleta.brand)
                            Text("A").font(.escalada(21, relativeTo: .title3)).foregroundStyle(.tertiary)
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

    /// El mismo texto que la de teléfono, palabra por palabra: son la misma
    /// avería contada a la misma persona, y dos redacciones distintas del
    /// mismo problema es lo que hace que una de las dos envejezca mal.
    static func explicacion(de que: BaseLocal.Caida.Que) -> String {
        switch que {
        case .enMemoria:
            return L.t("La base de datos de este aparato no se pudo abrir, así que nada de lo que captures aquí se está guardando. Cierra la app y vuelve a abrirla; si el aviso sigue, reinstálala y restaura tu último respaldo.",
                       "This device's database couldn't be opened, so nothing you record here is being saved. Close the app and reopen it; if the warning persists, reinstall it and restore your latest backup.")
        case .seEmpezoDeCero(let apartadoEn):
            return L.t("La base de datos de este aparato estaba dañada y se empezó una limpia. La app vuelve a guardar; lo que ya se había sincronizado baja solo, y lo que no, se recupera restaurando tu último respaldo. La dañada se guardó como \(apartadoEn).",
                       "This device's database was damaged and a clean one was started. The app is saving again; anything already synced comes back on its own, and the rest is recovered by restoring your latest backup. The damaged one was kept as \(apartadoEn).")
        }
    }

    @State private var trabajando = false
    @State private var paquete: URL?
    @State private var csvMovimientos: URL?
    @State private var csvAportantes: URL?
    @State private var error: String?
    @State private var ultimo = Respaldo.ultimoLegible
    @State private var eligiendoRespaldo = false
    @State private var confirmarReinicio = false
    @State private var confirmarPurgar = false
    @State private var porRestaurar: (url: URL, manifiesto: Respaldo.Manifiesto)?
    @State private var hecho: String?
    @State private var estadoBase: Compactacion.Estado?
    private let motor = MotorSincronizacion.compartido
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?

    /// La fila de sincronizar, con botón o sin él. Ver el cuerpo.
    private var filaSincronizar: some View {
        Text(L.t("Sincronizar ahora", "Sync now"))
            .font(.escalada(16, relativeTo: .body))
            // Un solo `foregroundStyle`, como `filaInvitar`.
            .foregroundStyle(motor.puedeSincronizar
                             ? AnyShapeStyle(Paleta.brand)
                             : AnyShapeStyle(.primary.opacity(0.7)))
            .frame(maxWidth: .infinity).frame(minHeight: Esp.altoBoton)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // **La sincronización va aquí y no en Acceso y áreas.** Estaba
                // entre los permisos y las invitaciones, que no tienen nada que
                // ver: lo que responde es "¿mis datos están en algún sitio
                // además de este aparato?", que es la pregunta de los respaldos.
                //
                // Va la PRIMERA, y no junto a los borrados, porque es lo único
                // de esta pantalla que se hace a diario y no rompe nada.
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
                    // Sin nada que sincronizar no hay botón, hay una frase.
                    if motor.puedeSincronizar {
                        Button {
                            Task { await motor.sincronizar(reintentarLoAtascado: true) }
                        } label: { filaSincronizar }
                        .buttonStyle(.plain)
                    } else {
                        filaSincronizar
                    }
                }

                HeroCard(seccion: .zona)

                // Advertencia + respaldar
                GrupoConf(nota: error) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t("Antes de tocar nada", "Before doing anything"))
                            .font(.escalada(17, weight: .bold, relativeTo: .body))
                        Text(Respaldo.ultimo == nil
                             ? L.t("Un respaldo tarda unos segundos y es lo único que puede devolver lo que se pierda. Todavía no has hecho ninguno desde este aparato.",
                                   "A backup takes a few seconds and is the only thing that can restore lost data. You haven't made one from this device yet.")
                             : L.t("Un respaldo tarda unos segundos y es lo único que puede devolver lo que se pierda.",
                                   "A backup takes a few seconds and is the only thing that can restore lost data."))
                            .font(.escalada(14.5, relativeTo: .subheadline)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Esp.pantalla).padding(.vertical, 18)
                    Divider()
                    Button { Task { await respaldar() } } label: {
                        HStack(spacing: 8) {
                            Text(trabajando
                                 ? L.t("Preparando…", "Preparing…")
                                 : L.t("Respaldar ahora", "Backup now"))
                                .font(.escalada(17, weight: .semibold, relativeTo: .body))
                                .foregroundStyle(trabajando ? .secondary : Paleta.brand)
                            if trabajando { ProgressView() }
                        }
                        .frame(maxWidth: .infinity).frame(minHeight: Esp.altoBoton)
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
                          nota: L.t("Lo que se borra queda marcado y sigue ocupando sitio: es lo que permite que la baja se propague a los demás aparatos. Al liberar espacio se va de verdad lo que lleve más de \(Compactacion.diasParaPurgar) días borrado y ya haya subido. Los apuntes del Registro nunca se tocan.",
                                    "Deleted items stay marked and keep taking space: that's what lets the deletion propagate to other devices. Freeing space permanently removes what has been deleted for more than \(Compactacion.diasParaPurgar) days and has already been uploaded. Log entries are never touched.")) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L.t("Espacio en este aparato", "Storage on this device"))
                            .font(.escalada(16, relativeTo: .body))
                        // **«Midiendo…» no puede quedarse puesto para
                        // siempre.** `Compactacion.medir()` devuelve `nil` en
                        // dos casos que no se parecen: aún no ha terminado, o
                        // la base no se pudo abrir y no hay nada que medir.
                        // La del teléfono ya lo distinguía
                        // (`IPhoneAjustesView:1540`); esta no, y se quedaba
                        // midiendo indefinidamente con la base caída.
                        if let caida = BaseLocal.caida {
                            // Rojo solo cuando NADA se guarda; la base
                            // empezada de cero sí guarda, así que es aviso.
                            let enMemoria: Bool = { if case .enMemoria = caida.que { return true }; return false }()
                            Text(Self.explicacion(de: caida.que))
                                .font(.escalada(13.5, relativeTo: .footnote))
                                .foregroundStyle(enMemoria ? Paleta.negativo : Paleta.aviso)
                                .fixedSize(horizontal: false, vertical: true)
                            // El error tal cual, para quien pueda hacer algo
                            // con él. No se traduce: es lo que dijo SQLite.
                            Text(caida.motivo)
                                .font(.escalada(11.5, relativeTo: .caption2).monospaced())
                                .foregroundStyle(.tertiary).textSelection(.enabled)
                        } else {
                            Text(estadoBase?.resumen ?? L.t("Midiendo…", "Measuring…"))
                                .font(.escalada(13.5, relativeTo: .footnote)).foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let e = estadoBase, e.filasPurgables > 0 {
                            Button { confirmarPurgar = true } label: {
                                Text(L.t("Liberar espacio", "Free up space"))
                                    .font(.escalada(15, relativeTo: .subheadline)).foregroundStyle(Paleta.brand)
                            }
                            .buttonStyle(.plain)
                            .disabled(trabajando)
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Esp.pantalla).padding(.vertical, 14)
                }

                // Restaurar
                GrupoConf {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L.t("Restaurar un respaldo", "Restore a backup"))
                                .font(.escalada(16, relativeTo: .body)).foregroundStyle(.primary)
                            Text(L.t("Reemplaza todo lo capturado después de la fecha del respaldo.",
                                     "Replaces everything captured after the backup date."))
                                .font(.escalada(13.5, relativeTo: .footnote)).foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button { eligiendoRespaldo = true } label: {
                            Text(L.t("Elegir un archivo…", "Choose a file…"))
                                .font(.escalada(15, relativeTo: .subheadline)).foregroundStyle(Paleta.brand)
                        }
                        .buttonStyle(.plain)
                        .disabled(trabajando)
                    }
                    .padding(.horizontal, Esp.pantalla).padding(.vertical, 14)
                }

                // Borrar datos
                GrupoConf {
                    Button(role: .destructive) { confirmarReinicio = true } label: {
                        HStack {
                            Text(L.t("Borrar datos de este iPad", "Erase data from this iPad"))
                                .font(.escalada(16, relativeTo: .body)).foregroundStyle(Paleta.negativo)
                            Spacer()
                        }
                        .frame(minHeight: Esp.altoFila).padding(.horizontal, Esp.pantalla)
                    }
                    .buttonStyle(.plain)
                    .disabled(trabajando)
                    Text(L.t("Borra solo la copia de este aparato; lo que ya se sincronizó sigue en el servidor de la iglesia y vuelve a bajar en cuanto alguien entre.",
                             "It erases only this device's copy; anything already synced stays on the church server and comes back down as soon as someone signs in."))
                        .font(.escalada(12.5, relativeTo: .caption1)).foregroundStyle(.tertiary)
                        .padding(.horizontal, Esp.pantalla).padding(.bottom, 14)
                }
            }
            .padding(Esp.panel)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
        .task { estadoBase = await Compactacion.medir() }
        .sheet(item: $paquete) { CompartirArchivo(url: $0) }
        .sheet(item: $csvMovimientos) { CompartirArchivo(url: $0) }
        .sheet(item: $csvAportantes) { CompartirArchivo(url: $0) }
        .fileImporter(isPresented: $eligiendoRespaldo,
                      allowedContentTypes: [.zip]) { resultado in
            guard case .success(let url) = resultado else { return }
            Task { await inspeccionar(url) }
        }
        .alert(L.t("Restaurar este respaldo", "Restore this backup"),
               isPresented: .init(get: { porRestaurar != nil },
                                  set: { if !$0 { porRestaurar = nil } })) {
            Button(L.t("Cancelar", "Cancel"), role: .cancel) { porRestaurar = nil }
            Button(L.t("Restaurar", "Restore"), role: .destructive) {
                if let p = porRestaurar { Task { await restaurar(p.url) } }
            }
        } message: {
            if let m = porRestaurar?.manifiesto { Text(ResumenRespaldo.frase(m)) }
        }
        .alert(L.t("Liberar espacio", "Free up space"), isPresented: $confirmarPurgar) {
            Button(L.t("Cancelar", "Cancel"), role: .cancel) {}
            Button(L.t("Liberar", "Free up"), role: .destructive) {
                Task { await purgar() }
            }
        } message: {
            Text(L.t("Se van de verdad \(estadoBase?.filasPurgables ?? 0) registros que llevan más de \(Compactacion.diasParaPurgar) días borrados y ya subieron. No se pueden recuperar ni desde otro aparato.",
                     "\(estadoBase?.filasPurgables ?? 0) records deleted for more than \(Compactacion.diasParaPurgar) days and already uploaded will be permanently removed. They can't be recovered, not even from another device."))
        }
        .alert(L.t("Borrar datos de este iPad", "Erase data from this iPad"),
               isPresented: $confirmarReinicio) {
            Button(L.t("Cancelar", "Cancel"), role: .cancel) {}
            Button(L.t("Borrar", "Erase"), role: .destructive) {
                Task { await reiniciar() }
            }
        } message: {
            Text(L.t("Este aparato queda como recién instalado y se cierra la sesión. Lo que está en el servidor NO se borra.",
                     "This device is left as newly installed and the session is closed. What's on the server is NOT deleted."))
        }
        .alert(L.t("Listo", "Done"), isPresented: .init(get: { hecho != nil },
                                                        set: { if !$0 { hecho = nil } })) {
            Button("OK", role: .cancel) { hecho = nil }
        } message: {
            if let hecho { Text(hecho) }
        }
    }

    private func inspeccionar(_ url: URL) async {
        trabajando = true; error = nil
        do { porRestaurar = (url, try await Respaldo.inspeccionar(url)) }
        catch { self.error = error.localizedDescription }
        trabajando = false
    }

    private func restaurar(_ url: URL) async {
        porRestaurar = nil
        trabajando = true; error = nil
        do {
            let m = try await Respaldo.restaurar(url)
            hecho = L.t("Restaurado el respaldo de \(m.iglesia).",
                        "Restored the backup from \(m.iglesia).")
        } catch { self.error = error.localizedDescription }
        trabajando = false
        estadoBase = await Compactacion.medir()
    }

    private func purgar() async {
        trabajando = true; error = nil
        do {
            let r = try await Compactacion.purgar()
            hecho = r.bytesLiberados > 0
                ? L.t("Se fueron \(r.filas) registros y se liberaron \(Compactacion.legible(r.bytesLiberados)).",
                      "\(r.filas) records removed, \(Compactacion.legible(r.bytesLiberados)) freed.")
                : L.t("Se fueron \(r.filas) registros. El archivo no encogió: SQLite reutilizará ese hueco.",
                      "\(r.filas) records removed. The file didn't shrink: SQLite will reuse that space.")
        } catch { self.error = error.localizedDescription }
        trabajando = false
        estadoBase = await Compactacion.medir()
    }

    private func reiniciar() async {
        trabajando = true; error = nil
        do {
            try await BorradoMasivo.reinicioDeFabrica()
            await sesion?.cerrarSesion()
        } catch { self.error = error.localizedDescription }
        trabajando = false
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
