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
            AjustesAccesoView(invEmail: $invEmail, invNom: $invNom, invRol: $invRol)
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
                    // Guardaba la etiqueta ("USD $") en el campo del código,
                    // así que lo que se salvaba no era una moneda. Ahora las
                    // opciones son el catálogo y lo que se guarda es el código.
                    Picker("", selection: $moneda) {
                        ForEach(Catalogos.monedas) { m in
                            Text("\(m.codigo) \(m.simbolo)").tag(m.codigo)
                        }
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

    @Binding var invEmail: String
    @Binding var invNom: String
    @Binding var invRol: String

    /// Los permisos son de la iglesia y viven donde vive la iglesia. Eran dos
    /// `@State` de la pantalla: se movían, se veían moverse, y no salían de
    /// ahí — ni al servidor, ni al iPad, ni al arranque siguiente.
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    @State private var guardandoPermiso = false
    @State private var errorPermiso: String?

    private var permisos: Permisos {
        Permisos(rol: sesion?.perfil.rol ?? .administrador, iglesia: cfg.config)
    }

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
                valorF(L.t("Estado", "Status"), motor.estadoLegible)
                valorF(L.t("Sin subir", "Not uploaded"), motor.pendientesLegible)
                Button { Task { await motor.sincronizar() } } label: {
                    Text(L.t("Sincronizar ahora", "Sync now")).font(.subheadline)
                        .foregroundStyle(motor.puedeSincronizar ? Paleta.brand : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(!motor.puedeSincronizar)
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
                permisoF(L.t("Ver el padrón de Secretaría", "View Secretary roster"),
                         L.t("Abre Membresía: domicilios, bautismos y familias.",
                             "Opens Membership: addresses, baptisms, and families."),
                         valor: cfg.config.tesoreroVePadron) { nuevo in
                    await cfg.fijarPermisos(vePadron: nuevo,
                                            puedeEliminar: cfg.config.tesoreroPuedeEliminar)
                }

                permisoF(L.t("Eliminar movimientos", "Delete transactions"),
                         L.t("Apagado, el botón Eliminar desaparece de Ingresos y Gastos.",
                             "When off, the Delete button disappears from Income and Expenses."),
                         valor: cfg.config.tesoreroPuedeEliminar) { nuevo in
                    await cfg.fijarPermisos(vePadron: cfg.config.tesoreroVePadron,
                                            puedeEliminar: nuevo)
                }
            } header: {
                Text(L.t("Permisos del rol Tesorería", "Treasury role permissions")).textCase(nil)
            } footer: {
                if let errorPermiso {
                    Text(errorPermiso).foregroundStyle(Paleta.negativo)
                } else if permisos.administraPermisos {
                    Text(L.t("Son de la iglesia, no de la persona: valen para quien ocupe el puesto. Los guarda el servidor.",
                             "These are church-level settings, not per-person. Stored on the server."))
                } else {
                    // El RPC solo acepta al administrador. Decirlo aquí evita
                    // que alguien mueva un interruptor y vea cómo se vuelve.
                    Text(L.t("Solo el administrador de la iglesia puede cambiarlos.",
                             "Only the church administrator can change these."))
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Acceso y áreas", "Access & areas"))
        .navigationBarTitleDisplayMode(.inline)
        // El contador solo se recalculaba al terminar una sincronización, así
        // que al abrir Ajustes después de capturar sin señal decía cero.
        .task { await motor.recontarPendientes() }
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

    /// Un permiso. **El interruptor no es la fuente**: enseña lo que hay
    /// guardado, y el cambio se pide al servidor. Mientras el servidor decide,
    /// el interruptor no se mueve; si lo rechaza, tampoco. Un permiso que se
    /// pinta encendido y luego se cae solo es peor que uno lento.
    private func permisoF(_ titulo: String, _ nota: String, valor: Bool,
                          cambiar: @escaping (Bool) async -> String?) -> some View {
        Toggle(isOn: Binding(get: { valor }, set: { nuevo in
            guardandoPermiso = true
            errorPermiso = nil
            Task {
                errorPermiso = await cambiar(nuevo)
                guardandoPermiso = false
            }
        })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.subheadline)
                Text(nota).font(.caption).foregroundStyle(.secondary)
            }
        }
        .tint(Paleta.brand)
        .disabled(guardandoPermiso || !permisos.administraPermisos)
    }
}

// MARK: - Categorías

/// **Las categorías de la iglesia, no una lista escrita en la vista.**
///
/// Era un array literal de quince filas con el número de movimientos puesto a
/// mano —"Diezmo: 9", "Ofrenda: 4"— que no salía de ningún sitio: ni coincidía
/// con lo que había capturado la iglesia, ni con la lista del iPad, ni con el
/// catálogo que de verdad ofrecen los formularios de alta. Y el "+" de abajo
/// tenía un `onTapGesture { }` vacío, así que crear una categoría no era ni
/// siquiera posible.
///
/// Ahora las integradas salen de `Catalogos`, las propias de la tabla que ya
/// existía en Supabase, y la cuenta se calcula sobre los movimientos.
private struct AjustesCategoriasView: View {
    @State private var vm = CategoriasViewModel.compartido
    @State private var tipo: TipoMovimiento = .ingreso
    @State private var creando = false
    @State private var nombreNuevo = ""
    @State private var renombrando: CategoriaCustom?
    @State private var nombreEditado = ""

    private var filas: [CategoriasViewModel.FilaCategoria] { vm.filas(tipo) }

    var body: some View {
        List {
            Section {
                Picker("", selection: $tipo) {
                    Text(L.t("Ingresos", "Income")).tag(TipoMovimiento.ingreso)
                    Text(L.t("Gastos", "Expenses")).tag(TipoMovimiento.gasto)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                ForEach(filas) { f in
                    fila(f)
                }
                Button { nombreNuevo = ""; creando = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Paleta.brand)
                        Text(tipo == .ingreso
                             ? L.t("Nueva categoría de ingreso", "New income category")
                             : L.t("Nueva categoría de egreso", "New expense category"))
                            .font(.subheadline).foregroundStyle(Paleta.brand)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text(tipo == .ingreso ? L.t("Ingresos", "Income") : L.t("Gastos", "Expenses"))
                    .textCase(nil)
            } footer: {
                Text(L.t("Las categorías integradas no se pueden eliminar. Las personalizadas aparecen en formularios, filtros y reportes igual que las demás; al borrar una, los movimientos que ya la usan la conservan.",
                         "Built-in categories cannot be deleted. Custom ones appear in forms, filters, and reports just like the built-ins; deleting one keeps it on transactions that already use it."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.t("Categorías", "Categories"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.cargar() }
        .alert(L.t("Nueva categoría", "New category"), isPresented: $creando) {
            TextField(L.t("Nombre", "Name"), text: $nombreNuevo)
            Button(L.t("Crear", "Create")) {
                Task { await vm.crear(nombre: nombreNuevo, tipo: tipo) }
            }
            .disabled(nombreNuevo.trimmingCharacters(in: .whitespaces).isEmpty)
            Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
        } message: {
            Text(avisoNombre(nombreNuevo)
                 ?? L.t("Saldrá en los formularios de alta, en los filtros y en los reportes.",
                        "It will appear in entry forms, filters, and reports."))
        }
        .alert(L.t("Cambiar el nombre", "Rename"),
               isPresented: Binding(get: { renombrando != nil },
                                    set: { if !$0 { renombrando = nil } })) {
            TextField(L.t("Nombre", "Name"), text: $nombreEditado)
            Button(L.t("Guardar", "Save")) {
                if let c = renombrando {
                    Task { await vm.renombrar(c, a: nombreEditado) }
                }
            }
            Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
        } message: {
            // Renombrar NO reescribe los movimientos ya capturados: guardan la
            // etiqueta, no un puntero. Decirlo aquí evita que alguien crea que
            // corrige una errata en toda la contabilidad.
            Text(L.t("Los movimientos ya capturados conservan el nombre anterior.",
                     "Transactions already recorded keep the previous name."))
        }
    }

    @ViewBuilder
    private func fila(_ f: CategoriasViewModel.FilaCategoria) -> some View {
        HStack(spacing: 12) {
            // El punto de una integrada es el MISMO que se ve en Ingresos y
            // Gastos, o sea gris para casi todas: la ley de color de Paleta no
            // reparte acentos entre veintitrés categorías. Antes esta lista
            // pintaba un arcoíris propio que no se correspondía con nada de lo
            // que la app enseña en ninguna otra pantalla.
            Circle()
                .fill(f.deFabrica
                      ? Paleta.categoria(f.clave)
                      : (Color(hexTexto: f.colorHex ?? "") ?? Paleta.pizarra))
                .frame(width: 12, height: 12)
                .opacity(f.huerfana ? 0.35 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(f.nombre).font(.subheadline)
                if f.huerfana {
                    Text(L.t("Ya no está en el catálogo", "No longer in the catalog"))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(f.movimientos == 1
                 ? L.t("1 movimiento", "1 transaction")
                 : L.t("\(f.movimientos) movimientos", "\(f.movimientos) transactions"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            if let c = f.custom {
                Button(role: .destructive) {
                    Task { await vm.eliminar(c) }
                } label: {
                    Label(L.t("Eliminar", "Delete"), systemImage: "trash")
                }
                Button {
                    nombreEditado = c.nombre
                    renombrando = c
                } label: {
                    Label(L.t("Renombrar", "Rename"), systemImage: "pencil")
                }
                .tint(Paleta.brand)
            }
        }
    }

    /// Lo que impide crearla, si algo lo impide. Sale en el propio diálogo en
    /// vez de dejar que el botón "Crear" no haga nada, que es lo que pasaba
    /// antes con cualquier nombre repetido.
    private func avisoNombre(_ nombre: String) -> String? {
        let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return nil }
        return vm.existe(limpio, tipo: tipo)
            ? L.t("Ya hay una categoría con ese nombre.", "A category with that name already exists.")
            : nil
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
