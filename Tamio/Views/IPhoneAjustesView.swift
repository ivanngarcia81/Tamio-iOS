import SwiftUI

// MARK: - Rutas de navegación

private enum AjustesRuta: Hashable {
    case cuenta, iglesia, institucion, tesorero, acceso, categorias, preferencias, zona
}

// MARK: - Vista principal

struct IPhoneAjustesView: View {
    /// Los datos de la iglesia ya no son `@State` de esta pantalla: vienen del
    /// origen único que comparten iPhone, iPad y los documentos. Antes cada
    /// pantalla tenía los suyos y no coincidían — el teléfono decía "Iglesia
    /// Nueva Vida" y el iPad "Iglesia Getsemaní".
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    @State private var cfgApertura = ""
    @State private var invEmail    = ""
    @State private var invNom      = ""
    @State private var invRol      = "Tesorero"
    @State private var permPadron  = false
    @State private var permBorrar  = true
    @State private var cfgTema     = "Claro"
    @State private var cfgAcento   = "verde"
    @State private var cfgIdioma   = "Español"
    @State private var cfgTamano   = "Normal"
    @State private var cfgSonido   = true
    @State private var cfgSonidoSet = "Suave"

    var body: some View {
        List {
            Section {
                NavigationLink(value: AjustesRuta.cuenta) { perfil }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                filaNav(L.t("Iglesia", "Church"),
                        val: cfg.config.nombre.isEmpty
                            ? L.t("Sin configurar", "Not set") : cfg.config.nombre,
                        icono: "building.2.fill", icoBg: Color(hex: 0x34C759), ruta: .iglesia)
                filaNav(L.t("Institución", "Institution"),
                        icono: "doc.richtext.fill", icoBg: Color(hex: 0x5856D6), ruta: .institucion)
                filaNav(L.t("Tesorero y pastor", "Treasurer & pastor"),
                        icono: "waveform", icoBg: Color(hex: 0x32ADE6), ruta: .tesorero)
                filaNav(L.t("Acceso y áreas", "Access & areas"),
                        icono: "key.fill", icoBg: Color(hex: 0x007AFF), ruta: .acceso)
            } header: {
                Text(L.t("Iglesia", "Church")).textCase(nil)
            } footer: {
                Text(L.t("Define quién entra a Tesorería y quién a Secretaría.",
                         "Defines who can access Treasury and who accesses Secretary."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                filaNav(L.t("Categorías", "Categories"),
                        icono: "tag.fill", icoBg: Color(hex: 0xFF9500), ruta: .categorias)
                filaNav(L.t("Preferencias", "Preferences"),
                        icono: "macwindow", icoBg: Color(hex: 0xAF52DE), ruta: .preferencias)
            } header: {
                Text(L.t("General", "General")).textCase(nil)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                NavigationLink(value: AjustesRuta.zona) {
                    Text(L.t("Zona de riesgo", "Danger zone")).foregroundStyle(Paleta.negativo)
                }
            } footer: {
                Text(L.t("Respaldos, restauración y borrado de datos. Los cambios aquí no se pueden deshacer.",
                         "Backups, restoration, and data deletion. Changes here cannot be undone."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Ajustes", "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: AjustesRuta.self) { ruta in destino(ruta) }
        .safeAreaInset(edge: .bottom) {
            Text("Tamio 1.3.5").font(.caption2).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity).padding(.bottom, 8)
        }
        .task { await cfg.cargar() }
        .onDisappear { Task { await cfg.guardarYa() } }
    }

    // MARK: - Fila perfil (compacta, índice)

    private var perfil: some View {
        HStack(spacing: 14) {
            Text("IG")
                .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Paleta.brand, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("Iván García").font(.headline)
                Text(L.t("Cuenta · ig07644@gmail.com", "Account · ig07644@gmail.com"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Fila con icono de color

    private func filaNav(_ titulo: String, val: String = "",
                         icono: String, icoBg: Color, ruta: AjustesRuta) -> some View {
        NavigationLink(value: ruta) {
            HStack(spacing: 14) {
                Image(systemName: icono)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(icoBg, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(titulo).font(.body)
                if !val.isEmpty {
                    Spacer()
                    Text(val).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }

    // MARK: - Destinos

    @ViewBuilder
    private func destino(_ ruta: AjustesRuta) -> some View {
        switch ruta {
        case .cuenta:
            AjustesCuentaView()
        case .iglesia:
            AjustesIglesiaView(nombre: $cfg.config.nombre, ciudad: $cfg.config.ciudad,
                               estado: $cfg.config.estado, pais: $cfg.config.pais,
                               cp: $cfg.config.codigoPostal,
                               ein: $cfg.config.idFiscal, moneda: $cfg.config.moneda,
                               apertura: $cfgApertura)
        case .institucion:
            AjustesInstitucionView(nombreIglesia: cfg.config.nombre,
                                   dir: $cfg.config.direccion, estado2: $cfg.config.ciudad,
                                   tel: $cfg.config.telefono, correo: $cfg.config.correo,
                                   pie: $cfg.config.pieInstitucional,
                                   sec: $cfg.config.secretarioNombre,
                                   cargo: $cfg.config.secretarioCargo)
        case .tesorero:
            AjustesTesorerosView(tes: $cfg.config.tesoreroNombre,
                                  tesCargo: $cfg.config.tesoreroCargo,
                                  pastor: $cfg.config.pastorNombre,
                                  pasCargo: $cfg.config.pastorCargo,
                                  firmas: $cfg.config.imprimirFirmas)
        case .acceso:
            AjustesAccesoView(invEmail: $invEmail, invNom: $invNom, invRol: $invRol,
                               permPadron: $permPadron, permBorrar: $permBorrar)
        case .categorias:
            AjustesCategoriasView()
        case .preferencias:
            AjustesPreferenciasView(tema: $cfgTema, acento: $cfgAcento,
                                     idioma: $cfgIdioma, tamano: $cfgTamano,
                                     sonido: $cfgSonido, sonidoSet: $cfgSonidoSet)
        case .zona:
            AjustesZonaView()
        }
    }
}

// MARK: - Cuenta

/// Lo que la pantalla cuenta de la sincronización. Que el número de cambios
/// sin subir esté a la vista es lo que evita que alguien dé por guardado en el
/// servidor algo que solo está en su teléfono.
private struct AjustesSyncTexto {
    static func estado(_ motor: MotorSincronizacion) -> String {
        switch motor.estado {
        case .sincronizando: return L.t("Sincronizando…", "Syncing…")
        case .fallo(let detalle): return detalle
        case .reposo:
            guard let fecha = motor.ultimaSincronizacion else {
                return L.t("Sin sincronizar todavía", "Not synced yet")
            }
            let f = DateFormatter()
            f.locale = L.locale
            f.dateStyle = .short
            f.timeStyle = .short
            return f.string(from: fecha)
        }
    }
}

private struct AjustesCuentaView: View {
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    @State private var confirmarCierre = false

    var body: some View {
        List {
            // Cabecera de perfil completa (fiel al handoff)
            Section {
                HStack(spacing: 14) {
                    Text("IG")
                        .font(.title2.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Paleta.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Iván García").font(.title3.weight(.semibold))
                        Text("ig07644@gmail.com").font(.subheadline).foregroundStyle(.secondary)
                        Text(L.t("Administrador · Tesorería y Secretaría",
                                 "Admin · Treasury & Secretary"))
                            .font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Circle().fill(Paleta.brand).frame(width: 7, height: 7)
                            Text(L.t("Sincronizado", "Synced"))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                HStack {
                    Text(L.t("Versión", "Version")).font(.subheadline)
                    Spacer()
                    Text("1.3.5").font(.subheadline).foregroundStyle(.secondary)
                }
                HStack {
                    Text(L.t("Ayuda", "Help")).font(.subheadline)
                    Spacer()
                }
                HStack {
                    Text(L.t("Acerca de", "About")).font(.subheadline)
                    Spacer()
                }
            } header: {
                Text(L.t("Aplicación", "Application")).textCase(nil)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                Button(role: .destructive) { confirmarCierre = true } label: {
                    Text(L.t("Cerrar sesión", "Sign out")).foregroundStyle(Paleta.negativo)
                        .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
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
            } footer: {
                Text(L.t("Cerrar sesión no borra nada del aparato: al volver a entrar, todo sigue donde estaba.",
                         "Signing out doesn't erase anything: when you sign back in, everything will be there."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Cuenta", "Account"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Iglesia

private struct AjustesIglesiaView: View {
    @Binding var nombre: String
    @Binding var ciudad: String
    @Binding var estado: String
    @Binding var pais: String
    @Binding var cp: String
    @Binding var ein: String
    @Binding var moneda: String
    @Binding var apertura: String

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Logo").font(.subheadline)
                    Spacer()
                    Text(L.t("Próximamente", "Coming soon")).font(.subheadline).foregroundStyle(.tertiary)
                }
            } footer: {
                Text(L.t("Sale en cartas y reportes.", "Appears on letters and reports."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                campoF(L.t("Nombre de la iglesia", "Church name"), $nombre, "p. ej. Iglesia Nueva Vida")
                campoF(L.t("Ciudad (opcional)", "City (optional)"), $ciudad, "p. ej. Monterrey")
                campoF(L.t("Estado/Provincia (opcional)", "State/Province (optional)"), $estado, "p. ej. Nuevo León")
                campoF(L.t("País (opcional)", "Country (optional)"), $pais, "p. ej. México")
                campoF(L.t("Código postal (opcional)", "ZIP code (optional)"), $cp, "p. ej. 64000")
            } header: {
                Text(L.t("Información de la iglesia", "Church information")).textCase(nil)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                campoF(L.t("EIN / identificación fiscal", "EIN / tax ID"), $ein, "p. ej. 12-3456789")
                HStack {
                    Text(L.t("Moneda", "Currency")).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $moneda) {
                        ForEach(["USD $", "MXN $", "EUR €"], id: \.self) { Text($0) }
                    }.labelsHidden()
                }
                campoF(L.t("Saldo de apertura", "Opening balance"), $apertura, "0.00")
            } header: {
                Text(L.t("Fiscal y contable", "Fiscal & accounting")).textCase(nil)
            } footer: {
                Text(L.t("La identificación fiscal es opcional y solo se imprime si está llena. El saldo de apertura es el dinero que la tesorería ya tenía antes del primer movimiento registrado.",
                         "The tax ID is optional and only prints if filled. Opening balance is money the treasury already had before the first recorded transaction."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Iglesia", "Church"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func campoF(_ label: String, _ bind: Binding<String>, _ hint: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: 160, alignment: .leading)
            TextField(hint, text: bind).font(.subheadline).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Institución

private struct AjustesInstitucionView: View {
    let nombreIglesia: String
    @Binding var dir: String
    @Binding var estado2: String
    @Binding var tel: String
    @Binding var correo: String
    @Binding var pie: String
    @Binding var sec: String
    @Binding var cargo: String

    var body: some View {
        List {
            Section {
                Text(nombreIglesia.isEmpty
                     ? ConfiguracionIglesiaViewModel.compartido.config.nombre
                     : nombreIglesia)
                    .font(.subheadline).foregroundStyle(.secondary)
            } footer: {
                Text(L.t("Así se ve el membrete de los PDF con lo que hay escrito abajo.",
                         "This is how the PDF letterhead looks with the data below."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                campoF(L.t("Dirección de la iglesia", "Church address"), $dir, "p. ej. Av. Constitución 1420")
                campoF(L.t("Estado / provincia", "State / province"), $estado2, "p. ej. Nuevo León")
                campoF(L.t("Teléfono", "Phone"), $tel, "p. ej. 81 8340 1122")
                campoF(L.t("Correo institucional", "Institutional email"), $correo, "p. ej. contacto@iglesia.org")
                campoF(L.t("Pie institucional (opcional)", "Footer (optional)"), $pie,
                       L.t("p. ej. lema o registro legal", "e.g. motto or legal reg."))
                campoF(L.t("Nombre de la secretaria", "Secretary name"), $sec, "p. ej. Lucía Márquez")
                campoF(L.t("Cargo", "Title"), $cargo, "p. ej. Secretaria de actas")
            } header: {
                Text(L.t("Datos del membrete", "Letterhead data")).textCase(nil)
            } footer: {
                Text(L.t("Lo que dejes vacío no se imprime; el membrete se ajusta sin dejar renglones en blanco.",
                         "Empty fields are not printed; the letterhead adjusts without blank lines."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                HStack {
                    Text(L.t("Vista previa del PDF", "PDF preview")).foregroundStyle(.secondary).font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right.square").foregroundStyle(.tertiary).font(.subheadline)
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Institución", "Institution"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func campoF(_ label: String, _ bind: Binding<String>, _ hint: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: 150, alignment: .leading)
            TextField(hint, text: bind).font(.subheadline).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Tesorero y pastor

private struct AjustesTesorerosView: View {
    @Binding var tes: String
    @Binding var tesCargo: String
    @Binding var pastor: String
    @Binding var pasCargo: String
    @Binding var firmas: Bool

    var body: some View {
        List {
            Section {
                campoF(L.t("Nombre del tesorero", "Treasurer name"), $tes, "p. ej. Iván García")
                pickerF(L.t("Cargo", "Title"), $tesCargo, Catalogos.Cargos.tesoreria)
                HStack {
                    Text(L.t("Firma", "Signature")).font(.subheadline)
                    Spacer()
                    Text(L.t("Próximamente", "Coming soon")).font(.subheadline).foregroundStyle(.tertiary)
                }
            } header: {
                Text(L.t("Tesorería", "Treasury")).textCase(nil)
            } footer: {
                Text(L.t("La firma se imprime en los reportes de tesorería y en las constancias.",
                         "The signature prints on treasury reports and contribution receipts."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                campoF(L.t("Nombre del pastor", "Pastor name"), $pastor, "p. ej. Samuel Ríos")
                pickerF(L.t("Cargo", "Title"), $pasCargo, Catalogos.Cargos.pastoral)
                HStack {
                    Text(L.t("Firma", "Signature")).font(.subheadline)
                    Spacer()
                    Text(L.t("Próximamente", "Coming soon")).font(.subheadline).foregroundStyle(.tertiary)
                }
            } header: {
                Text(L.t("Pastor", "Pastor")).textCase(nil)
            } footer: {
                Text(L.t("Firma las cartas de traslado, las constancias de miembro y las actas.",
                         "Signs transfer letters, membership certificates, and meeting minutes."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                Toggle(isOn: $firmas) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("Imprimir firmas en los PDF", "Print signatures on PDFs")).font(.subheadline)
                        Text(L.t("Si está apagado, los documentos salen con la línea en blanco para firmar a mano.",
                                 "If off, documents print with a blank signature line to sign by hand."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tint(Paleta.brand)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Tesorero y pastor", "Treasurer & pastor"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func campoF(_ label: String, _ bind: Binding<String>, _ hint: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: 160, alignment: .leading)
            TextField(hint, text: bind).font(.subheadline).multilineTextAlignment(.trailing)
        }
    }

    private func pickerF(_ label: String, _ bind: Binding<String>, _ opts: [String]) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            // `conValorVigente`: un cargo guardado en el otro idioma no está
            // entre las opciones y el Picker saldría en blanco, que es el
            // mismo fallo que Catalogos documenta para las categorías.
            Picker("", selection: bind) {
                ForEach(Catalogos.conValorVigente(opts, bind.wrappedValue), id: \.self) { Text($0) }
            }
            .labelsHidden()
        }
    }
}

// MARK: - Acceso y áreas

private struct AjustesAccesoView: View {
    /// Singleton observable: leer sus propiedades dentro de `body` basta para
    /// que la pantalla se refresque cuando la sincronización avanza.
    private let motor = MotorSincronizacion.compartido

    private var estadoSync: String { AjustesSyncTexto.estado(motor) }

    @Binding var invEmail: String
    @Binding var invNom: String
    @Binding var invRol: String
    @Binding var permPadron: Bool
    @Binding var permBorrar: Bool

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.tertiary)
                    Text(L.t("Añadir persona", "Add person")).font(.subheadline).foregroundStyle(.tertiary)
                }
            } header: {
                Text(L.t("Personas", "People")).textCase(nil)
            } footer: {
                Text(L.t("Toca una persona para cambiar su rol. El rol decide en qué áreas entra.",
                         "Tap a person to change their role. The role determines which areas they can access."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                campoF(L.t("Correo electrónico", "Email"), $invEmail, "tesorero@iglesia.org")
                campoF(L.t("Nombre", "Name"), $invNom, L.t("Opcional", "Optional"))
                pickerF(L.t("Rol", "Role"), $invRol, Catalogos.Cargos.roles)
                Button { } label: {
                    Text(L.t("Enviar invitación", "Send invitation")).font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(true)
            } header: {
                Text(L.t("Invitar a alguien", "Invite someone")).textCase(nil)
            } footer: {
                Text(L.t("Verá Tesorería: ingresos, gastos, depósitos y reportes.",
                         "They'll see Treasury: income, expenses, deposits, and reports."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                valorF(L.t("Estado", "Status"), estadoSync)
                valorF(L.t("Sin subir", "Not uploaded"),
                       "\(motor.pendientes) " + L.t("cambios", "changes"))
                Button { Task { await motor.sincronizar() } } label: {
                    Text(L.t("Sincronizar ahora", "Sync now")).font(.subheadline).foregroundStyle(Paleta.brand)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(motor.estado == .sincronizando)
            } header: {
                Text(L.t("Sincronización", "Sync")).textCase(nil)
            } footer: {
                Text(L.t("Se sincroniza sola al abrir, al guardar y al reconectar. Aquí puedes forzarla a mano.",
                         "Syncs automatically on open, save, and reconnect. Tap to force a manual sync."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                valorF(L.t("Plan", "Plan"), L.t("Completo", "Full"))
                valorF(L.t("Suscripción", "Subscription"), L.t("Cortesía", "Courtesy"))
            } header: {
                Text(L.t("Tu plan", "Your plan")).textCase(nil)
            } footer: {
                Text(L.t("El plan lo administra el servidor; para cambios de plan o cortesías contacta soporte.",
                         "The plan is managed server-side; for plan changes or courtesy licenses contact support."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                Toggle(isOn: $permPadron) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("Ver el padrón de Secretaría", "View Secretary roster")).font(.subheadline)
                        Text(L.t("Abre Membresía: domicilios, bautismos y familias.",
                                 "Opens Membership: addresses, baptisms, and families."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.tint(Paleta.brand)

                Toggle(isOn: $permBorrar) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("Eliminar movimientos", "Delete transactions")).font(.subheadline)
                        Text(L.t("Apagado, el botón Eliminar desaparece de Ingresos y Gastos.",
                                 "When off, the Delete button disappears from Income and Expenses."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.tint(Paleta.brand)
            } header: {
                Text(L.t("Permisos del rol Tesorería", "Treasury role permissions")).textCase(nil)
            } footer: {
                Text(L.t("Son de la iglesia, no de la persona: valen para quien ocupe el puesto. Los guarda el servidor.",
                         "These are church-level settings, not per-person. Stored on the server."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Acceso y áreas", "Access & areas"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func campoF(_ label: String, _ bind: Binding<String>, _ hint: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: 130, alignment: .leading)
            TextField(hint, text: bind).font(.subheadline).multilineTextAlignment(.trailing)
        }
    }

    private func pickerF(_ label: String, _ bind: Binding<String>, _ opts: [String]) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            // `conValorVigente`: un cargo guardado en el otro idioma no está
            // entre las opciones y el Picker saldría en blanco, que es el
            // mismo fallo que Catalogos documenta para las categorías.
            Picker("", selection: bind) {
                ForEach(Catalogos.conValorVigente(opts, bind.wrappedValue), id: \.self) { Text($0) }
            }
            .labelsHidden()
        }
    }

    private func valorF(_ label: String, _ val: String) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(val).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Categorías

private struct AjustesCategoriasView: View {
    @State private var segmento = "Ingresos"

    private let catsIng: [(String, Color, Int)] = [
        ("Ofrenda",  Color(hex: 0x2F9E44), 4),
        ("Diezmo",   Color(hex: 0x7C3AED), 9),
        ("Donación", Color(hex: 0x0D7D8A), 3),
        ("Otros",    Color(hex: 0x5F6070), 0),
    ]
    private let catsGas: [(String, Color, Int)] = [
        ("Compensación", Color(hex: 0x9D174D), 0),
        ("Suministros",  Color(hex: 0x1D4ED8), 0),
        ("Varios",       Color(hex: 0x5F6070), 0),
        ("Limpieza",     Color(hex: 0x0F766E), 0),
        ("Utilidades",   Color(hex: 0xB45309), 1),
        ("Mantenimiento",Color(hex: 0x4F46E5), 0),
        ("Alimentos",    Color(hex: 0xB03A10), 3),
        ("Misiones",     Color(hex: 0x0369A1), 0),
        ("Ayudas",       Color(hex: 0xA21CAF), 0),
        ("Tecnología",   Color(hex: 0x9333EA), 0),
        ("Transporte",   Color(hex: 0x4D7C0F), 0),
    ]

    private var cats: [(String, Color, Int)] { segmento == "Ingresos" ? catsIng : catsGas }

    var body: some View {
        List {
            Section {
                Picker("", selection: $segmento) {
                    Text(L.t("Ingresos", "Income")).tag("Ingresos")
                    Text(L.t("Gastos", "Expenses")).tag("Gastos")
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                ForEach(cats, id: \.0) { c in
                    HStack(spacing: 12) {
                        Circle().fill(c.1).frame(width: 12, height: 12)
                        Text(c.0).font(.subheadline)
                        Spacer()
                        Text(c.2 == 1
                             ? L.t("1 movimiento", "1 transaction")
                             : L.t("\(c.2) movimientos", "\(c.2) transactions"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Paleta.brand)
                    Text(segmento == "Ingresos"
                         ? L.t("Nueva categoría de ingreso", "New income category")
                         : L.t("Nueva categoría de egreso", "New expense category"))
                        .font(.subheadline).foregroundStyle(Paleta.brand)
                }
                .contentShape(Rectangle()).onTapGesture { }
            } header: {
                Text(segmento == "Ingresos" ? L.t("Ingresos", "Income") : L.t("Gastos", "Expenses"))
                    .textCase(nil)
            } footer: {
                Text(L.t("Las categorías integradas no se pueden eliminar. Las personalizadas aparecen en formularios, filtros y reportes igual que las demás.",
                         "Built-in categories cannot be deleted. Custom ones appear in forms, filters, and reports just like the built-ins."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Categorías", "Categories"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preferencias

private struct AjustesPreferenciasView: View {
    @Binding var tema: String
    @Binding var acento: String
    @Binding var idioma: String
    @Binding var tamano: String
    @Binding var sonido: Bool
    @Binding var sonidoSet: String

    private let acentos: [(String, Color)] = [
        ("verde",   Color(hex: 0x047857)),
        ("azul",    Color(hex: 0x0A6CFF)),
        ("indigo",  Color(hex: 0x4F46E5)),
        ("teal",    Color(hex: 0x0D7D8A)),
        ("ciruela", Color(hex: 0x9D174D)),
    ]
    private let tamanos = ["Pequeño", "Compacto", "Normal", "Grande", "Muy grande"]

    var body: some View {
        List {
            Section {
                ForEach(["Claro", "Oscuro", "Automático"], id: \.self) { t in
                    HStack {
                        Text(L.t(t, t == "Claro" ? "Light" : t == "Oscuro" ? "Dark" : "Automatic"))
                            .font(.subheadline)
                        Spacer()
                        if tema == t {
                            Image(systemName: "checkmark").foregroundStyle(Paleta.brand).fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle()).onTapGesture { tema = t }
                }

                HStack {
                    Text(L.t("Color de acento", "Accent color")).font(.subheadline)
                    Spacer()
                    HStack(spacing: 10) {
                        ForEach(acentos, id: \.0) { a in
                            Button { acento = a.0 } label: {
                                ZStack {
                                    Circle().fill(a.1).frame(width: 28, height: 28)
                                    if acento == a.0 {
                                        Image(systemName: "checkmark")
                                            .font(.caption2.weight(.bold)).foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(L.t("Apariencia", "Appearance")).textCase(nil)
            } footer: {
                Text(L.t("\"Automático\" sigue el modo del sistema. El acento tiñe botones y enlaces.",
                         "\"Automatic\" follows the system mode. The accent tints buttons and links."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                HStack {
                    Text(L.t("Idioma", "Language")).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $idioma) {
                        ForEach(["Español", "English", "Automático"], id: \.self) { Text($0) }
                    }.labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("Tamaño de texto", "Text size")).font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        ForEach(tamanos, id: \.self) { t in
                            Button { tamano = t } label: {
                                let act = tamano == t
                                Text(t)
                                    .font(.caption2.weight(act ? .semibold : .regular))
                                    .foregroundStyle(act ? .white : .primary)
                                    .padding(.horizontal, Esp.hueco).padding(.vertical, 5)
                                    .background(act ? Paleta.brand : Color(.tertiarySystemFill), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(L.t("Idioma y texto", "Language & text")).textCase(nil)
            } footer: {
                Text(L.t("\"Automático\" usa el idioma del sistema operativo.",
                         "\"Automatic\" uses the operating system language."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                Toggle(isOn: $sonido) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("Sonido", "Sound")).font(.subheadline)
                        Text(L.t("Suena al registrar un ingreso, gasto o al eliminar.",
                                 "Plays on income entry, expense entry, or deletion."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.tint(Paleta.brand)

                HStack {
                    Text(L.t("Juego de sonidos", "Sound set")).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $sonidoSet) {
                        ForEach(["Suave", "Clásico", "Marimba"], id: \.self) { Text($0) }
                    }.labelsHidden()
                }
            } header: {
                Text(L.t("Sonido", "Sound")).textCase(nil)
            } footer: {
                Text(L.t("Con el sonido apagado, el juego se queda a la vista pero no suena.",
                         "With sound off, the sound set is still shown but won't play."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Preferencias", "Preferences"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Zona de riesgo

private struct AjustesZonaView: View {
    @State private var confirmarBorrar = false
    @State private var confirmarReinicio = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.t("Antes de tocar nada", "Before touching anything"))
                        .font(.subheadline.weight(.semibold))
                    Text(L.t("Un respaldo tarda unos segundos y es lo único que puede devolver lo que se pierda. Todavía no has hecho ninguno desde este aparato.",
                             "A backup takes seconds and is the only way to recover lost data. You haven't made one from this device yet."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Button { } label: {
                    Text(L.t("Respaldar ahora", "Backup now")).font(.subheadline).foregroundStyle(Paleta.brand)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(true).opacity(0.4)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                HStack {
                    Text(L.t("Último respaldo", "Last backup")).font(.subheadline)
                    Spacer()
                    Text(L.t("Ninguno", "None")).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack {
                    Text(L.t("Exportar a un archivo", "Export to a file")).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
            } header: {
                Text(L.t("Respaldos", "Backups")).textCase(nil)
            } footer: {
                Text(L.t("El respaldo completo se puede guardar fuera del teléfono y sirve para restaurar en otro aparato.",
                         "The full backup can be saved off-device and used to restore on another device."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("Compactar base de datos", "Compact database")).font(.subheadline.weight(.medium))
                    Text(L.t("La base ya está compacta.", "The database is already compact."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text(L.t("Mantenimiento", "Maintenance")).textCase(nil)
            } footer: {
                Text(L.t("Lo que se borra queda marcado hasta que se compacta. No toca nada de lo que se ve.",
                         "Deleted items remain marked until compacted. Does not affect visible data."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("Restaurar un respaldo", "Restore a backup")).font(.subheadline.weight(.medium))
                    Text(L.t("Reemplaza todo lo capturado después de la fecha del respaldo.",
                             "Replaces everything captured after the backup date."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("Borrar todos los registros", "Delete all records"))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Paleta.negativo)
                    Text(L.t("Se van los movimientos, los miembros y las actividades. El borrado se propaga a los demás aparatos. La configuración se conserva.",
                             "Removes transactions, members, and activities. Deletion propagates to other devices. Configuration is preserved."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Button(role: .destructive) { confirmarBorrar = true } label: {
                    Text(L.t("Continuar…", "Continue…")).foregroundStyle(Paleta.negativo).font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(true).opacity(0.4)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("Reinicio de fábrica", "Factory reset"))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Paleta.negativo)
                    Text(L.t("Se va todo: registros y configuración. La app vuelve como recién instalada.",
                             "Erases everything: records and configuration. The app returns to its initial state."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Button(role: .destructive) { confirmarReinicio = true } label: {
                    Text(L.t("Continuar…", "Continue…")).foregroundStyle(Paleta.negativo).font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(true).opacity(0.4)
            } footer: {
                Text(L.t("Solo un administrador puede borrar, y hay que escribir el nombre de la iglesia para confirmar.",
                         "Only an administrator can delete, and the church name must be typed to confirm."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Zona de riesgo", "Danger zone"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Text("Compilación del 2026-08-29 18:09 UTC")
                .font(.caption2).foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity).padding(.bottom, 8)
        }
        .confirmationDialog(L.t("Borrar todos los registros", "Delete all records"),
                            isPresented: $confirmarBorrar, titleVisibility: .visible) {
            Button(role: .destructive) { } label: { Text(L.t("Sí, borrar todo", "Yes, delete all")) }
            Button(role: .cancel) { } label: { Text(L.t("Cancelar", "Cancel")) }
        } message: {
            Text(L.t("Esta acción no se puede deshacer.", "This action cannot be undone."))
        }
        .confirmationDialog(L.t("Reinicio de fábrica", "Factory reset"),
                            isPresented: $confirmarReinicio, titleVisibility: .visible) {
            Button(role: .destructive) { } label: { Text(L.t("Sí, reiniciar", "Yes, reset")) }
            Button(role: .cancel) { } label: { Text(L.t("Cancelar", "Cancel")) }
        } message: {
            Text(L.t("Esta acción no se puede deshacer.", "This action cannot be undone."))
        }
    }
}
