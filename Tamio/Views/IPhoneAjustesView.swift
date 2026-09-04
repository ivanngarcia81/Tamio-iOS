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
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    @State private var invEmail    = ""
    @State private var invNom      = ""

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
                // La versión va aquí, al pie de la última sección, y no
                // flotando sobre la lista con `safeAreaInset`. Con el borde
                // suave de iOS 26 el contenido corre por debajo de la barra de
                // pestañas, así que ese texto acababa impreso encima de la
                // fila de Preferencias.
                VStack(alignment: .leading, spacing: 10) {
                    Text(L.t("Respaldos, restauración y borrado de datos. Los cambios aquí no se pueden deshacer.",
                             "Backups, restoration, and data deletion. Changes here cannot be undone."))
                    Text(VersionApp.pie)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .navigationTitle(L.t("Ajustes", "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: AjustesRuta.self) { ruta in destino(ruta) }
        .task { await cfg.cargar() }
        .onDisappear { Task { await cfg.guardarYa() } }
    }

    // MARK: - Fila perfil (compacta, índice)

    /// Quien ha entrado, del perfil de la sesión. Iban su nombre, su correo y
    /// sus iniciales escritos a mano aquí, en la pantalla de Cuenta, en la del
    /// iPad y en el pie de la sidebar: cuatro copias del mismo dato para una
    /// app en la que cada iglesia tiene sus propios usuarios.
    private var perfil: some View {
        let p = sesion?.perfil ?? SesionSupabase.Perfil()
        return HStack(spacing: 14) {
            Text(p.iniciales)
                .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Paleta.brand, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(p.nombre.isEmpty ? L.t("Tu cuenta", "Your account") : p.nombre)
                    .font(.headline)
                Text(L.t("Cuenta · \(p.correo)", "Account · \(p.correo)"))
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
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
                               apertura: $cfg.config.saldoInicial)
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
            AjustesAccesoView(invEmail: $invEmail, invNom: $invNom)
        case .categorias:
            AjustesCategoriasView()
        case .preferencias:
            AjustesPreferenciasView()
        case .zona:
            AjustesZonaView()
        }
    }
}

// MARK: - Cuenta

/// El rol, en el idioma de la app. `perfiles.rol` guarda `tesorero`,
/// `secretaria` o `administrador`, que son claves y no texto para leer.
enum AjustesRol {
    /// Solo el nombre del rol, para listas y selectores.
    static func corto(_ rol: SesionSupabase.Perfil.Rol) -> String {
        switch rol {
        case .tesorero:      return L.t("Tesorero", "Treasurer")
        case .secretaria:    return L.t("Secretaría", "Secretary")
        case .administrador: return L.t("Administrador", "Administrator")
        }
    }

    static func legible(_ rol: SesionSupabase.Perfil.Rol) -> String {
        switch rol {
        case .tesorero:      return L.t("Tesorero · Tesorería", "Treasurer · Treasury")
        case .secretaria:    return L.t("Secretaría", "Secretary")
        case .administrador: return L.t("Administrador · Tesorería y Secretaría",
                                        "Administrator · Treasury & Secretary")
        }
    }
}

private struct AjustesCuentaView: View {
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    private let motor = MotorSincronizacion.compartido
    @State private var confirmarCierre = false

    var body: some View {
        List {
            // Cabecera de perfil completa (fiel al handoff)
            Section {
                let p = sesion?.perfil ?? SesionSupabase.Perfil()
                HStack(spacing: 14) {
                    Text(p.iniciales)
                        .font(.title2.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Paleta.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.nombre.isEmpty ? L.t("Tu cuenta", "Your account") : p.nombre)
                            .font(.title3.weight(.semibold))
                        Text(p.correo).font(.subheadline).foregroundStyle(.secondary)
                        // El rol de verdad, no "Administrador" escrito a mano:
                        // a un tesorero le decía que era administrador.
                        Text(AjustesRol.legible(p.rol))
                            .font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            // El punto verde decía "Sincronizado" siempre, en
                            // la misma pantalla donde ahora el estado se lee
                            // del motor. Ver `MotorSincronizacion`.
                            Circle()
                                .fill(motor.haFallado ? Paleta.negativo : Paleta.brand)
                                .frame(width: 7, height: 7)
                            Text(motor.estadoLegible)
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
                    Text(VersionApp.completa).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack {
                    Text(L.t("Ayuda", "Help")).font(.subheadline)
                    Spacer()
                    Text(L.t("Próximamente", "Coming soon"))
                        .font(.subheadline).foregroundStyle(.tertiary)
                }
                HStack {
                    Text(L.t("Acerca de", "About")).font(.subheadline)
                    Spacer()
                    Text(L.t("Próximamente", "Coming soon"))
                        .font(.subheadline).foregroundStyle(.tertiary)
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
        .scrollEdgeEffectStyle(.soft, for: .all)
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
    /// En centavos, como todo el dinero de la app. Era un `String` suelto que
    /// no salía de la pantalla: se tecleaba "5000", se veía escrito, y al salir
    /// se perdía. Y como texto libre, "cinco mil" era un valor válido.
    @Binding var apertura: Centavos
    @State private var aperturaTexto = ""

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
                HStack {
                    Text(L.t("Saldo de apertura", "Opening balance"))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: 160, alignment: .leading)
                    TextField("0.00", text: $aperturaTexto)
                        .font(.subheadline).multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        // Al salir del campo: lo tecleado se convierte a
                        // centavos y se vuelve a escribir ya formateado, así
                        // que lo que queda en pantalla es exactamente lo que
                        // se guardó. Si no se entiende, se deja lo anterior en
                        // vez de guardar cero — un cero silencioso en una cifra
                        // de dinero es peor que no aceptar el texto.
                        .onSubmit { fijarApertura() }
                }
            } header: {
                Text(L.t("Fiscal y contable", "Fiscal & accounting")).textCase(nil)
            } footer: {
                // Se dice para qué NO sirve todavía. "Saldo en caja" en Tamio
                // es el efectivo sin depositar, y el saldo de apertura no es
                // efectivo de ofrenda esperando ir al banco: entra en el
                // acumulado del estado financiero, que aún no existe.
                Text(L.t("La identificación fiscal es opcional y solo se imprime si está llena. El saldo de apertura es el dinero que la tesorería ya tenía antes del primer movimiento registrado; se guarda y se sincroniza, y entrará en el acumulado del estado financiero. No se suma al saldo en caja, que es el efectivo todavía sin depositar.",
                         "The tax ID is optional and only prints if filled. Opening balance is money the treasury already had before the first recorded transaction; it's saved and synced, and will feed the cumulative financial statement. It is not added to cash on hand, which is money not yet deposited."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .navigationTitle(L.t("Iglesia", "Church"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { aperturaTexto = apertura == 0 ? "" : Money.fmt(apertura) }
        .onDisappear { fijarApertura() }
    }

    private func fijarApertura() {
        let limpio = aperturaTexto.trimmingCharacters(in: .whitespaces)
        if limpio.isEmpty {
            apertura = 0
        } else if let centavos = Money.desdeTexto(limpio) {
            apertura = centavos
        }
        aperturaTexto = apertura == 0 ? "" : Money.fmt(apertura)
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
                // La flecha de "abrir fuera" prometía un visor que no existe.
                HStack {
                    Text(L.t("Vista previa del PDF", "PDF preview")).font(.subheadline)
                    Spacer()
                    Text(L.t("Próximamente", "Coming soon"))
                        .font(.subheadline).foregroundStyle(.tertiary)
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .scrollEdgeEffectStyle(.soft, for: .all)
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
        .scrollEdgeEffectStyle(.soft, for: .all)
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
    /// El rol de la invitación es un `Rol`, no una cadena.
    ///
    /// Era texto salido de `Catalogos.Cargos.roles`, que ofrece cuatro
    /// opciones —incluida "Pastor"— cuando la función de invitar solo acepta
    /// tres: tesorero, secretaria y administrador. Invitar a alguien como
    /// Pastor habría sido un error del servidor. Y como el catálogo devuelve la
    /// etiqueta TRADUCIDA, con la app en inglés se habría mandado "Treasurer",
    /// que tampoco es ninguno de los tres.
    @State private var invRol: SesionSupabase.Perfil.Rol = .tesorero
    @State private var invitando = false
    @State private var avisoInvitacion: String?
    @State private var invitacionOK = false

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
            // La lista de quién tiene acceso NO se puede enseñar todavía, y
            // no es un descuido: la política de `perfiles` en Supabase deja a
            // cada cuenta leer SOLO la suya. Enseñar una lista de una persona
            // —tú— bajo el título "Personas" sería peor que decirlo.
            Section {
                filaYo
            } header: {
                Text(L.t("Personas", "People")).textCase(nil)
            } footer: {
                Text(L.t("Por ahora solo se ve tu propia cuenta: el servidor no deja que un aparato lea los perfiles de los demás. Invitar sí funciona, aquí abajo.",
                         "For now only your own account is visible: the server doesn't let a device read other people's profiles. Inviting does work, below."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                campoF(L.t("Correo electrónico", "Email"), $invEmail, "tesorero@iglesia.org")
                campoF(L.t("Nombre", "Name"), $invNom, L.t("Opcional", "Optional"))
                HStack {
                    Text(L.t("Rol", "Role")).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $invRol) {
                        ForEach([SesionSupabase.Perfil.Rol.tesorero, .secretaria, .administrador],
                                id: \.self) { Text(AjustesRol.corto($0)).tag($0) }
                    }
                    .labelsHidden()
                }
                Button { Task { await invitar() } } label: {
                    HStack {
                        Text(invitando
                             ? L.t("Enviando…", "Sending…")
                             : L.t("Enviar invitación", "Send invitation"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(puedeInvitar ? Paleta.brand : Color(.tertiaryLabel))
                        Spacer()
                        if invitando { ProgressView() }
                    }
                }
                .disabled(!puedeInvitar)
            } header: {
                Text(L.t("Invitar a alguien", "Invite someone")).textCase(nil)
            } footer: {
                if let avisoInvitacion {
                    Text(avisoInvitacion)
                        .foregroundStyle(invitacionOK ? Paleta.brand : Paleta.negativo)
                } else if !permisos.administraPermisos {
                    Text(L.t("Solo el administrador de la iglesia puede invitar.",
                             "Only the church administrator can invite people."))
                } else {
                    Text(rolExplicado)
                }
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
                valorF(L.t("Plan", "Plan"), cfg.config.planLegible)
                valorF(L.t("Suscripción", "Subscription"), cfg.config.suscripcionLegible)
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
        .scrollEdgeEffectStyle(.soft, for: .all)
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

    /// Tu propia cuenta. Es la única fila que el servidor deja leer.
    private var filaYo: some View {
        let p = sesion?.perfil ?? SesionSupabase.Perfil()
        return HStack(spacing: 12) {
            Text(p.iniciales)
                .font(.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Paleta.brand, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(p.nombre.isEmpty ? L.t("Tu cuenta", "Your account") : p.nombre)
                    .font(.subheadline)
                Text(AjustesRol.corto(p.rol)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(L.t("Tú", "You")).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var puedeInvitar: Bool {
        permisos.administraPermisos && !invitando
            && invEmail.trimmingCharacters(in: .whitespaces).contains("@")
    }

    /// Qué verá quien reciba la invitación, según el rol elegido. Decía siempre
    /// "Verá Tesorería" aunque se estuviera invitando a Secretaría.
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
            invitacionOK = true
            avisoInvitacion = r.mensaje
            // Los campos se vacían solo si salió bien: si falló, quien lo
            // escribió no tiene por qué volver a teclearlo.
            invEmail = ""
            invNom = ""
        } catch {
            invitacionOK = false
            avisoInvitacion = error.localizedDescription
        }
        invitando = false
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
        .scrollEdgeEffectStyle(.soft, for: .all)
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

/// **Preferencias que se aplican de verdad y sobreviven al cierre.**
///
/// Eran seis `@State` de esta pantalla: se movían, se veían moverse, y no
/// pasaba nada. El tema no cambiaba el tema, el idioma no cambiaba el idioma, y
/// al volver a abrir Ajustes todo estaba como al principio.
///
/// Quedan tres. El **color de acento** se va porque contradice la ley de color
/// de `Paleta` —el verde solo en lo seleccionado y en las cifras—, y los
/// **sonidos** porque no existe ninguno: un interruptor y tres "juegos de
/// sonidos" con nombres inventados prometían algo que no está en el código.
private struct AjustesPreferenciasView: View {
    @State private var prefs = PreferenciasApp.compartidas

    var body: some View {
        List {
            Section {
                ForEach(PreferenciasApp.Tema.allCases, id: \.self) { t in
                    HStack {
                        Text(t.etiqueta).font(.subheadline)
                        Spacer()
                        if prefs.tema == t {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Paleta.brand).fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { prefs.tema = t }
                }
            } header: {
                Text(L.t("Apariencia", "Appearance")).textCase(nil)
            } footer: {
                Text(L.t("\"Automático\" sigue el modo del sistema.",
                         "\"Automatic\" follows the system mode."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                HStack {
                    Text(L.t("Idioma", "Language")).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $prefs.idioma) {
                        ForEach(PreferenciasApp.Idioma.allCases, id: \.self) {
                            Text($0.etiqueta).tag($0)
                        }
                    }.labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("Tamaño de texto", "Text size")).font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        ForEach(PreferenciasApp.Tamano.allCases, id: \.self) { t in
                            Button { prefs.tamano = t } label: {
                                let act = prefs.tamano == t
                                Text(t.etiqueta)
                                    .font(.caption2.weight(act ? .semibold : .regular))
                                    .foregroundStyle(act ? .white : .primary)
                                    .padding(.horizontal, Esp.hueco).padding(.vertical, 5)
                                    .background(act ? Paleta.brand : Color(.tertiarySystemFill),
                                                in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    // El tamaño de las píldoras NO sigue a la preferencia: si
                    // lo hiciera, elegir "Muy grande" desbordaría la fila justo
                    // en el control que sirve para volver atrás.
                    .dynamicTypeSize(.medium)
                }
                .padding(.vertical, 4)
            } header: {
                Text(L.t("Idioma y texto", "Language & text")).textCase(nil)
            } footer: {
                Text(L.t("\"Automático\" usa el idioma del sistema operativo. \"Normal\" respeta el tamaño de letra que tengas puesto en los ajustes del teléfono; los demás lo sustituyen.",
                         "\"Automatic\" uses the operating system language. \"Normal\" respects the text size set on your device; the others override it."))
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .navigationTitle(L.t("Preferencias", "Preferences"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Zona de riesgo

/// **La zona de riesgo, con el respaldo funcionando.**
///
/// "Respaldar ahora" estaba apagado y "Último respaldo" decía "Ninguno" para
/// siempre, los dos justo debajo de un texto que asegura que un respaldo es lo
/// único que puede devolver lo que se pierda.
private struct AjustesZonaView: View {
    @State private var confirmarBorrar = false
    @State private var confirmarReinicio = false
    @State private var trabajando = false
    @State private var paquete: URL?
    @State private var csvMovimientos: URL?
    @State private var csvAportantes: URL?
    @State private var error: String?
    /// Se lee al aparecer y se refresca al terminar: `Respaldo.ultimo` vive en
    /// `UserDefaults` y no es observable.
    @State private var ultimo = Respaldo.ultimoLegible

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.t("Antes de tocar nada", "Before touching anything"))
                        .font(.subheadline.weight(.semibold))
                    Text(avisoPrevio)
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Button {
                    Task { await respaldar() }
                } label: {
                    HStack {
                        Text(trabajando
                             ? L.t("Preparando…", "Preparing…")
                             : L.t("Respaldar ahora", "Backup now"))
                            .font(.subheadline).foregroundStyle(Paleta.brand)
                        Spacer()
                        if trabajando { ProgressView() }
                    }
                }
                .disabled(trabajando)
            } footer: {
                if let error {
                    Text(error).foregroundStyle(Paleta.negativo)
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                HStack {
                    // "Preparado" y no "guardado": la app arma el paquete y lo
                    // ofrece, pero el sistema no le dice si quien compartió
                    // llegó a elegir dónde ponerlo o cerró la hoja.
                    Text(L.t("Último respaldo preparado", "Last backup prepared")).font(.subheadline)
                    Spacer()
                    Text(ultimo).font(.subheadline).foregroundStyle(.secondary)
                }
                Button { Task { await exportar(.movimientos) } } label: {
                    filaExportar(L.t("Exportar movimientos (CSV)", "Export transactions (CSV)"))
                }
                .disabled(trabajando)
                Button { Task { await exportar(.aportantes) } } label: {
                    filaExportar(L.t("Exportar aportantes (CSV)", "Export contributors (CSV)"))
                }
                .disabled(trabajando)
            } header: {
                Text(L.t("Respaldos", "Backups")).textCase(nil)
            } footer: {
                Text(L.t("El respaldo lleva la base entera y los recibos del banco, y se guarda donde tú elijas: Archivos, iCloud o cualquier app. Los CSV son para abrirlos en una hoja de cálculo.",
                         "The backup includes the whole database and bank receipts, and is saved wherever you choose: Files, iCloud, or any app. The CSVs are for opening in a spreadsheet."))
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
                    HStack {
                        Text(L.t("Restaurar un respaldo", "Restore a backup")).font(.subheadline.weight(.medium))
                        Spacer()
                        Text(L.t("Próximamente", "Coming soon"))
                            .font(.subheadline).foregroundStyle(.tertiary)
                    }
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
                VStack(alignment: .leading, spacing: 10) {
                    Text(L.t("Borrar y reiniciar se encienden cuando exista la restauración: hoy no habría a dónde volver.",
                             "Delete and reset will be enabled once restore exists: today there would be nothing to go back to."))
                    Text(VersionApp.pie)
                        .foregroundStyle(.quaternary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .navigationTitle(L.t("Zona de riesgo", "Danger zone"))
        .navigationBarTitleDisplayMode(.inline)
        // Una hoja por archivo: `ShareLink` necesita el item al construirse y
        // aquí no existe hasta que el trabajo termina.
        .sheet(item: $paquete) { CompartirArchivo(url: $0) }
        .sheet(item: $csvMovimientos) { CompartirArchivo(url: $0) }
        .sheet(item: $csvAportantes) { CompartirArchivo(url: $0) }
    }

    private var avisoPrevio: String {
        Respaldo.ultimo == nil
            ? L.t("Un respaldo tarda unos segundos y es lo único que puede devolver lo que se pierda. Todavía no has hecho ninguno desde este aparato.",
                  "A backup takes seconds and is the only way to recover lost data. You haven't made one from this device yet.")
            : L.t("Un respaldo tarda unos segundos y es lo único que puede devolver lo que se pierda.",
                  "A backup takes seconds and is the only way to recover lost data.")
    }

    private func filaExportar(_ titulo: String) -> some View {
        HStack {
            Text(titulo).font(.subheadline).foregroundStyle(Paleta.brand)
            Spacer()
            Image(systemName: "square.and.arrow.up")
                .font(.subheadline).foregroundStyle(Paleta.brand)
        }
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
            let ingresos = (try? await repo.lista(tipo: .ingreso)) ?? []
            let gastos = (try? await repo.lista(tipo: .gasto)) ?? []
            let todos = ingresos + gastos
            if todos.isEmpty {
                error = L.t("No hay movimientos que exportar.", "There are no transactions to export.")
            } else {
                csvMovimientos = ExportadorMovimientos.csv(todos)
            }
        case .aportantes:
            // `.todos`: un respaldo que se deja fuera las bajas no es un
            // respaldo del padrón, es una foto de los activos de hoy.
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
